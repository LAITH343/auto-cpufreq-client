import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:nsd/nsd.dart';

import '../models/models.dart';

/// The DNS-SD service type the gateway advertises. `multicast_dns` needs the
/// fully-qualified `.local` form; the native `nsd` APIs take the bare type.
const String _serviceType = '_autocpufreq._tcp';
const String _serviceTypeLocal = '$_serviceType.local';

/// Builds a [Device] from a resolved [Service], or null if it lacks a usable
/// address/port. Prefers an IPv4 address, then the resolved hostname.
Device? _deviceFromService(Service s) {
  final port = s.port;
  if (port == null || port <= 0) return null;
  String? host;
  final addrs = s.addresses;
  if (addrs != null && addrs.isNotEmpty) {
    final v4 = addrs.firstWhere(
      (a) => a.type == InternetAddressType.IPv4,
      orElse: () => addrs.first,
    );
    host = v4.address;
  } else {
    host = s.host;
  }
  if (host == null || host.isEmpty) return null;
  final txt = s.txt ?? const <String, Uint8List?>{};
  final key = s.name ?? host;
  return Device(
    id: 'mdns:$key',
    name: _txtValue(txt, const ['name', 'device', 'dn']) ?? s.name ?? host,
    host: host,
    port: port,
    transport: Transport.https,
    online: true,
    secure: true,
  );
}

String? _txtValue(Map<String, Uint8List?> txt, List<String> keys) {
  for (final entry in txt.entries) {
    if (!keys.contains(entry.key.toLowerCase())) continue;
    final v = entry.value;
    if (v == null || v.isEmpty) continue;
    try {
      final s = utf8.decode(v).trim();
      if (s.isNotEmpty) return s;
    } catch (_) {}
  }
  return null;
}

/// Discovers auto-cpufreq gateways on the local network via the native service
/// discovery stack (Android NsdManager / Bonjour). Kept as a long-lived
/// [Discovery] because native discovery is expensive to start and stop.
class NsdDiscovery {
  static Stream<List<Device>> stream(Ref ref) {
    final controller = StreamController<List<Device>>();
    Discovery? discovery;

    void emit() {
      final d = discovery;
      if (d == null || controller.isClosed) return;
      final devices = <String, Device>{};
      for (final svc in d.services) {
        final dev = _deviceFromService(svc);
        if (dev != null) devices[dev.id] = dev;
      }
      controller.add(devices.values.toList());
    }

    startDiscovery(_serviceType, ipLookupType: IpLookupType.v4).then((d) {
      discovery = d;
      d.addListener(emit);
      emit();
    }).catchError((_) {
      if (!controller.isClosed) controller.add(const []);
    });

    ref.onDispose(() async {
      final d = discovery;
      discovery = null;
      if (d != null) {
        d.removeListener(emit);
        try {
          await stopDiscovery(d);
        } catch (_) {}
      }
      await controller.close();
    });

    return controller.stream;
  }
}

/// Pure-Dart mDNS discovery for platforms without native NSD support (Linux
/// desktop). Advertisement records are queried and resolved manually.
class MdnsDiscovery {
  static const String service = _serviceTypeLocal;

  /// Runs one discovery sweep, returning the gateways seen within [timeout].
  static Future<List<Device>> scan(
      {Duration timeout = const Duration(seconds: 3)}) async {
    final client = MDnsClient(
      rawDatagramSocketFactory: (dynamic host, int port,
              {bool reuseAddress = true, bool reusePort = true, int ttl = 1}) =>
          RawDatagramSocket.bind(host, port,
              reuseAddress: true, reusePort: false, ttl: ttl),
    );
    final devices = <String, Device>{};
    final deadline = DateTime.now().add(timeout);
    try {
      await client.start();
      final ptrs = await _collect(
        client.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(service)),
        timeout,
      );
      for (final ptr in ptrs) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        final budget = remaining < const Duration(seconds: 1)
            ? const Duration(milliseconds: 600)
            : const Duration(seconds: 1);

        final srvs = await _collect(
          client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName)),
          budget,
        );
        if (srvs.isEmpty) continue;
        final srv = srvs.first;

        final txts = await _collect(
          client.lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName)),
          budget,
        );
        final ips = await _collect(
          client.lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target)),
          budget,
        );

        final instance = _instanceName(ptr.domainName);
        final host = ips.isNotEmpty ? ips.first.address.address : srv.target;
        final name = _txtLine(txts, const ['name', 'device', 'dn']) ?? instance;
        devices[instance] = Device(
          id: 'mdns:$instance',
          name: name,
          host: host,
          port: srv.port,
          transport: Transport.https,
          online: true,
          secure: true,
        );
      }
    } catch (_) {
      // Multicast may be blocked (no permission / no network); treat as empty.
    } finally {
      client.stop();
    }
    return devices.values.toList();
  }

  /// Drains [stream] until it closes or [budget] elapses, whichever comes first.
  static Future<List<T>> _collect<T>(Stream<T> stream, Duration budget) {
    final out = <T>[];
    final completer = Completer<List<T>>();
    late final StreamSubscription<T> sub;
    final timer = Timer(budget, () {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.complete(out);
      }
    });
    sub = stream.listen(
      out.add,
      onDone: () {
        if (!completer.isCompleted) {
          timer.cancel();
          completer.complete(out);
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
    return completer.future;
  }

  static String _instanceName(String domain) {
    final marker = domain.indexOf('._autocpufreq');
    return marker > 0 ? domain.substring(0, marker) : domain;
  }

  static String? _txtLine(List<TxtResourceRecord> txts, List<String> keys) {
    for (final rec in txts) {
      for (final line in rec.text.split('\n')) {
        final eq = line.indexOf('=');
        if (eq <= 0) continue;
        final k = line.substring(0, eq).trim().toLowerCase();
        if (keys.contains(k)) {
          final v = line.substring(eq + 1).trim();
          if (v.isNotEmpty) return v;
        }
      }
    }
    return null;
  }
}

/// Continuously reports discovered gateways while the devices screen is shown.
/// Uses native NSD where available and falls back to pure-Dart mDNS on Linux.
final discoveredDevicesProvider =
    StreamProvider.autoDispose<List<Device>>((ref) async* {
  if (!Platform.isLinux) {
    yield* NsdDiscovery.stream(ref);
    return;
  }
  while (true) {
    yield await MdnsDiscovery.scan();
    await Future<void>.delayed(const Duration(seconds: 4));
  }
});
