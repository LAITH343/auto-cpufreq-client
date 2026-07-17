// Manual smoke check: connects to the live engine over the system D-Bus and
// prints a snapshot. Run with: dart run tool/dbus_smoke.dart
// ignore_for_file: avoid_print
import 'package:auto_cpufreq_client/data/dbus_engine_repository.dart';

Future<void> main() async {
  final repo = await DbusEngineRepository.connect();
  final s = repo.snapshot;
  print('model:   ${s.cpuModel}');
  print('cpu:     usage=${s.cpu.usage}% temp=${s.cpu.avgTemp} fan=${s.cpu.fanRpm} load=${s.cpu.load}');
  print('cores:   ${s.cores.length}  first=${s.cores.first.usage}% ${s.cores.first.freq}GHz ${s.cores.first.temp}C');
  print('override: gov=${s.governorOverride} turbo=${s.turboOverride}');
  print('freq:    ${s.freqLimits.min}-${s.freqLimits.max} MHz  govs=${s.availableGovernors}');
  print('power:   ${s.power.source} ${s.power.batteryPct}% ${s.power.watts}W thr=${s.batteryThreshold.start}-${s.batteryThreshold.stop}');
  final c = s.config['charger']!;
  print('config:  charger gov=${c.governor} turbo=${c.turboMode} freq=${c.minFreq}-${c.maxFreq} ignore=${c.ignoreList}');
  print('users:   ${s.users.map((u) => "${u.name}(${u.enabled})").toList()}');
  print('sessions:${s.sessions.length}  version=${s.engineVersion}');

  print('waiting for a StatsTick...');
  await repo.stream.first.timeout(const Duration(seconds: 8));
  print('tick ok. history length=${repo.snapshot.history.length}');
  repo.dispose();
}
