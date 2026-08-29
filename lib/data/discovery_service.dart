import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../models/models.dart';

/// Discovers auto-cpufreq gateways on the local network. The gateway advertises
/// `_autocpufreq._tcp` over mDNS with the device name and version in TXT
/// records. Uses the pure-Dart [MDnsClient] so it works on every desktop and
/// mobile platform (Linux, Windows, macOS, Android, iOS).
class MdnsDiscovery {
  static const String service = '_autocpufreq._tcp.local';
  static const MethodChannel _channel = MethodChannel('auto_cpufreq/mdns');

  /// Runs one discovery sweep, returning the gateways seen within [timeout].
  static Future<List<Device>> scan(
      {Duration timeout = const Duration(seconds: 3)}) async {
    // Android drops multicast without a held WifiManager.MulticastLock.
    await _acquireLock();
    // reusePort must be off: Android's socket bind rejects SO_REUSEPORT and
    // fails the whole query otherwise.
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
        final name = _txtValue(txts, const ['name', 'device', 'dn']) ?? instance;
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
      await _releaseLock();
    }
    return devices.values.toList();
  }

  static Future<void> _acquireLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('acquire');
    } catch (_) {}
  }

  static Future<void> _releaseLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('release');
    } catch (_) {}
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

  static String? _txtValue(List<TxtResourceRecord> txts, List<String> keys) {
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

/// Re-scans the LAN roughly every few seconds while the devices screen is shown,
/// emitting the current set of discovered gateways.
final discoveredDevicesProvider = StreamProvider.autoDispose<List<Device>>((ref) async* {
  while (true) {
    yield await MdnsDiscovery.scan();
    await Future<void>.delayed(const Duration(seconds: 4));
  }
});
