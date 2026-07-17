import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/engine_repository.dart';
import '../l10n/strings.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../util/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final snap = ref.watch(engineControllerProvider);
    final unit = ref.watch(settingsProvider.select((v) => v.tempUnit));
    final canWriteControls = ref.watch(
        connectionProvider.select((c) => c.permissions.canWrite('controls')));
    final repo = ref.watch(engineRepositoryProvider);

    if (snap == null) {
      return Center(child: CircularProgressIndicator(color: p.accent));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _kpiRow(p, s, snap, unit, constraints.maxWidth),
            const SizedBox(height: 14),
            _heroRow(context, ref, p, s, snap, unit, repo, canWriteControls, wide),
            const SizedBox(height: 14),
            _perCore(p, s, snap, unit),
          ],
        ),
      );
    });
  }

  // ---- KPI cards ----

  Widget _kpiRow(Palette p, AppStrings s, EngineSnapshot snap, String unit, double maxW) {
    final usage = snap.history.map((h) => h.u.toDouble()).toList();
    final temps = snap.history.map((h) => h.t.toDouble()).toList();
    final watts = snap.history.map((h) => h.w).toList();
    final busy = snap.cores.where((c) => c.usage > 55).length;

    final cards = [
      _KpiCard(
        p: p,
        label: s.t('cpuUsage'),
        value: '${snap.cpu.usage.round()}%',
        trend: _trend(usage),
        color: p.accent,
        values: usage,
        isBar: false,
      ),
      _KpiCard(
        p: p,
        label: s.t('cpuTemp'),
        value: Labels.temp(snap.cpu.avgTemp, unit),
        trend: _trend(temps),
        color: p.warning,
        values: temps,
        isBar: false,
      ),
      _KpiCard(
        p: p,
        label: s.t('lblPowerDraw'),
        value: '${snap.power.watts.toStringAsFixed(1)} W',
        trend: _trend(watts),
        color: p.success,
        values: watts,
        isBar: true,
      ),
      _KpiCard(
        p: p,
        label: s.t('coresBusy'),
        value: '$busy/${snap.cores.length}',
        trend: null,
        color: p.accent,
        values: snap.cores.map((c) => c.usage).toList(),
        isBar: true,
      ),
    ];

    final cols = maxW >= 760 ? 4 : 2;
    return _grid(cards, cols, 12);
  }

  _Trend? _trend(List<double> values) {
    if (values.length < 6) return null;
    final last = values.last;
    final prev = values[values.length - 6];
    if (prev == 0) return null;
    final pct = ((last - prev) / prev * 100);
    return _Trend(up: pct >= 0, pct: '${pct.abs().toStringAsFixed(0)}%');
  }

  // ---- hero + rails ----

  Widget _heroRow(BuildContext context, WidgetRef ref, Palette p, AppStrings s,
      EngineSnapshot snap, String unit, EngineRepository? repo, bool canWrite, bool wide) {
    final hero = _heroCard(context, ref, p, s, snap, unit, repo, canWrite);
    final rails = _rails(p, s, snap, unit);
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: hero),
            const SizedBox(width: 14),
            Expanded(flex: 2, child: rails),
          ],
        ),
      );
    }
    return Column(children: [hero, const SizedBox(height: 14), rails]);
  }

  Widget _heroCard(BuildContext context, WidgetRef ref, Palette p, AppStrings s,
      EngineSnapshot snap, String unit, EngineRepository? repo, bool canWrite) {
    final usageVals = snap.history.map((h) => h.u).toList();
    final avg = usageVals.isEmpty
        ? 0
        : (usageVals.reduce((a, b) => a + b) / usageVals.length).round();
    final peak = usageVals.isEmpty ? 0 : usageVals.reduce((a, b) => a > b ? a : b);
    final u = snap.cpu.usage.round();
    final usageColor = u > 80 ? p.danger : (u > 55 ? p.warning : p.accent);
    final tempColor = snap.cpu.avgTemp > 75 ? p.danger : p.text;

    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('$u%',
                  style: AppFonts.mono(size: 46, weight: FontWeight.w800, color: usageColor)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.t('cpuCard')} · ${s.t('cpuUsage')}',
                        style: AppFonts.sans(size: 13, weight: FontWeight.w700, color: p.text)),
                    const SizedBox(height: 3),
                    Text(snap.cpuModel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.mono(size: 11, color: p.textDim)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _miniStats(p, s, snap, unit, u, avg, peak, tempColor),
          const SizedBox(height: 16),
          _historyBlock(p, s, snap),
          if (canWrite) ...[
            const SizedBox(height: 14),
            _quickActions(ref, p, s, snap, repo),
          ],
        ],
      ),
    );
  }

  Widget _miniStats(Palette p, AppStrings s, EngineSnapshot snap, String unit, int now,
      int avg, int peak, Color tempColor) {
    Widget cell(String label, String value, Color color, {bool first = false}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            border: first ? null : Border(left: BorderSide(color: p.border)),
          ),
          child: Column(
            children: [
              Text(label.toUpperCase(), style: AppFonts.sectionLabel(p.textFaint).copyWith(fontSize: 9.5)),
              const SizedBox(height: 3),
              Text(value, style: AppFonts.mono(size: 16, weight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          cell(s.t('now'), '$now%', p.accent, first: true),
          cell(s.t('avg'), '$avg%', p.text),
          cell(s.t('peak'), '$peak%', p.text),
          cell(s.t('cpuTemp'), Labels.temp(snap.cpu.avgTemp, unit), tempColor),
        ],
      ),
    );
  }

  Widget _historyBlock(Palette p, AppStrings s, EngineSnapshot snap) {
    Widget legend(Color color, String label, {bool dashed = false}) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 15,
          height: dashed ? 0 : 3,
          decoration: dashed
              ? BoxDecoration(border: Border(top: BorderSide(color: color, width: 2, style: BorderStyle.solid)))
              : BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppFonts.sans(size: 11, color: p.textDim)),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel(p, s.t('cpuHistory'))),
            legend(p.accent, s.t('legUsage')),
            const SizedBox(width: 14),
            legend(p.warning, s.t('legTemp'), dashed: true),
          ],
        ),
        const SizedBox(height: 8),
        CpuHistoryChart(p: p, history: snap.history),
      ],
    );
  }

  Widget _quickActions(
      WidgetRef ref, Palette p, AppStrings s, EngineSnapshot snap, EngineRepository? repo) {
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(p, s.t('quickActions')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
                child: SegmentedControl<String>(
                  p: p,
                  selected: snap.governorOverride,
                  onChanged: (v) => repo?.setGovernorOverride(v),
                  options: [
                    SegmentOption('auto', Labels.governor(s, 'auto')),
                    SegmentOption('performance', Labels.governor(s, 'performance')),
                    SegmentOption('powersave', Labels.governor(s, 'powersave')),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => repo?.setTurboOverride(
                    snap.turboOverride == 'always' ? 'auto' : 'always'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration:
                      BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.t('turbo'),
                          style: AppFonts.sans(size: 12.5, weight: FontWeight.w700, color: p.text)),
                      const SizedBox(width: 10),
                      AppSwitch(
                        p: p,
                        value: snap.turboOverride == 'always',
                        width: 38,
                        height: 22,
                        onChanged: (v) => repo?.setTurboOverride(v ? 'always' : 'auto'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rails(Palette p, AppStrings s, EngineSnapshot snap, String unit) {
    final charging = snap.power.charging ? s.t('charging') : s.t('notCharging');
    final effGov = Labels.effectiveGovernor(snap);
    final reason = snap.governorOverride != 'auto'
        ? '${s.t('overridePrefix')}: ${Labels.governor(s, snap.governorOverride)}'
        : (snap.power.source == 'AC' ? s.t('onAC') : s.t('lblBattery'));
    final effTurbo = Labels.effectiveTurbo(snap);
    final turboVal = effTurbo == 'auto'
        ? s.t('govAuto')
        : (effTurbo == 'always' ? s.t('turboAlwaysOn') : s.t('turboDisabled'));

    Widget card(String title, List<Widget> rows) => AppCard(
          p: p,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(p, title),
              const SizedBox(height: 11),
              ...rows,
            ],
          ),
        );

    List<Widget> spaced(List<Widget> items) {
      final out = <Widget>[];
      for (var i = 0; i < items.length; i++) {
        if (i > 0) out.add(const SizedBox(height: 10));
        out.add(items[i]);
      }
      return out;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(s.t('cpuCard'), spaced([
          StatRow(p: p, label: s.t('cpuLoad'), value: snap.cpu.load),
          StatRow(p: p, label: s.t('cpuFan'), value: '${snap.cpu.fanRpm} RPM'),
        ])),
        const SizedBox(height: 14),
        card(s.t('secPower'), spaced([
          StatRow(p: p, label: s.t('lblPowerSource'), value: snap.power.source == 'AC' ? s.t('onAC') : s.t('lblBattery')),
          StatRow(p: p, label: s.t('lblBattery'), value: '${snap.power.batteryPct}% · $charging'),
          StatRow(p: p, label: s.t('lblPowerDraw'), value: '${snap.power.watts.toStringAsFixed(1)} W', valueColor: p.accent),
          StatRow(p: p, label: s.t('lblThresholds'), value: '${snap.batteryThreshold.start}–${snap.batteryThreshold.stop}%'),
        ])),
        const SizedBox(height: 14),
        card(s.t('secProfile'), spaced([
          StatRow(p: p, label: s.t('lblActiveProfile'), value: Labels.governor(s, effGov), mono: false),
          StatRow(p: p, label: s.t('lblWhy'), value: reason, mono: false),
          StatRow(p: p, label: s.t('lblGovernor'), value: Labels.governor(s, effGov), mono: false),
          StatRow(p: p, label: s.t('lblTurbo'), value: turboVal, mono: false),
          StatRow(p: p, label: s.t('lblEpp'), value: 'balance_performance', mono: false),
          StatRow(p: p, label: s.t('lblPlatformProfile'), value: 'Balanced', mono: false),
        ])),
      ],
    );
  }

  // ---- per-core ----

  Widget _perCore(Palette p, AppStrings s, EngineSnapshot snap, String unit) {
    final busy = snap.cores.where((c) => c.usage > 55).length;
    final cards = snap.cores.map((c) {
      final barColor = c.usage > 80 ? p.danger : (c.usage > 55 ? p.warning : p.accent);
      final tempColor = c.temp > 75 ? p.danger : p.textDim;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text('Core ${c.id}',
                      style: AppFonts.sans(size: 11.5, weight: FontWeight.w700, color: p.textDim)),
                ),
                Text('${c.usage.round()}%',
                    style: AppFonts.mono(size: 12.5, weight: FontWeight.w800, color: p.text)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: (c.usage / 100).clamp(0, 1),
                minHeight: 5,
                backgroundColor: p.hover,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text('${c.freq} GHz', style: AppFonts.mono(size: 11, color: p.textDim)),
                ),
                Text('${c.temp}°C', style: AppFonts.mono(size: 11, color: tempColor)),
              ],
            ),
          ],
        ),
      );
    }).toList();

    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(s.t('perCore'),
                    style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.text)),
              ),
              Text('$busy/${snap.cores.length} ${s.t('coresBusy')}',
                  style: AppFonts.mono(size: 11, color: p.textDim)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 720 ? 4 : (c.maxWidth >= 420 ? 3 : 2);
            return _grid(cards, cols, 8);
          }),
        ],
      ),
    );
  }
}

/// A simple fixed-column grid built from Wrap, so children size evenly.
Widget _grid(List<Widget> children, int cols, double gap) {
  return LayoutBuilder(builder: (context, c) {
    final width = (c.maxWidth - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: children
          .map((w) => SizedBox(width: width < 0 ? c.maxWidth : width, child: w))
          .toList(),
    );
  });
}

class _Trend {
  final bool up;
  final String pct;
  const _Trend({required this.up, required this.pct});
}

class _KpiCard extends StatelessWidget {
  final Palette p;
  final String label;
  final String value;
  final _Trend? trend;
  final Color color;
  final List<double> values;
  final bool isBar;

  const _KpiCard({
    required this.p,
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
    required this.values,
    required this.isBar,
  });

  @override
  Widget build(BuildContext context) {
    final trendColor = trend == null ? p.textFaint : (trend!.up ? p.success : p.danger);
    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    style: AppFonts.sectionLabel(p.textFaint).copyWith(fontSize: 9.5)),
              ),
              if (trend != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(trend!.up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      size: 16, color: trendColor),
                  Text(trend!.pct,
                      style: AppFonts.sans(size: 11, weight: FontWeight.w700, color: trendColor)),
                ]),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: AppFonts.mono(size: 26, weight: FontWeight.w800, color: p.text)),
          const SizedBox(height: 10),
          MiniSparkline(values: values, color: color, isBar: isBar),
        ],
      ),
    );
  }
}
