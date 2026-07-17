import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';

class BatteryScreen extends ConsumerWidget {
  const BatteryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final snap = ref.watch(engineControllerProvider);
    final repo = ref.watch(engineRepositoryProvider);
    final canWrite =
        ref.watch(connectionProvider.select((c) => c.permissions.canWrite('battery')));

    if (snap == null) return const SizedBox.shrink();
    final th = snap.batteryThreshold;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canWrite) ...[
                LockNote(p, s.t('batteryReadOnlyNote')),
                const SizedBox(height: 18),
              ],
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 480 ? 2 : 1;
                final gap = 12.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: snap.batteries.map((b) {
                    return SizedBox(
                      width: w,
                      child: AppCard(
                        p: p,
                        padding: const EdgeInsets.all(16),
                        radius: BorderRadius.circular(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(
                                  child: Text(b.name,
                                      style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.text)),
                                ),
                                Text(b.charging ? s.t('charging') : s.t('notCharging'),
                                    style: AppFonts.sans(
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: b.charging ? p.success : p.textDim)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('${b.level}%',
                                style: AppFonts.mono(size: 24, weight: FontWeight.w800, color: p.text)),
                            if (b.health.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('${s.t('health')}: ${b.health}',
                                  style: AppFonts.sans(size: 11.5, color: p.textDim)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 18),
              Opacity(
                opacity: canWrite ? 1 : 0.5,
                child: IgnorePointer(
                  ignoring: !canWrite,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _thresholdCard(p, s, th.start, th.stop, repo),
                      const SizedBox(height: 18),
                      _conservationCard(p, s, snap.conservationMode, repo),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thresholdCard(Palette p, AppStrings s, int start, int stop, dynamic repo) {
    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      radius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('chargeThreshold'),
              style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 4),
          Text(s.t('chargeThresholdHelp'), style: AppFonts.sans(size: 12.5, color: p.textDim)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(
                  text: '${s.t('start')}: ',
                  style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.textDim),
                  children: [
                    TextSpan(text: '$start%', style: AppFonts.mono(size: 12, color: p.text)),
                  ],
                )),
              ),
              Text.rich(TextSpan(
                text: '${s.t('stop')}: ',
                style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.textDim),
                children: [
                  TextSpan(text: '$stop%', style: AppFonts.mono(size: 12, color: p.text)),
                ],
              )),
            ],
          ),
          RangeSlider(
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: p.accent,
            inactiveColor: p.hover,
            values: RangeValues(start.toDouble(), stop.toDouble()),
            labels: RangeLabels('$start', '$stop'),
            onChanged: (v) => repo?.setBatteryThreshold(v.start.round(), v.end.round()),
          ),
        ],
      ),
    );
  }

  Widget _conservationCard(Palette p, AppStrings s, bool on, dynamic repo) {
    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      radius: BorderRadius.circular(10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('conservationMode'),
                    style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 2),
                Text(s.t('conservationModeHelp'), style: AppFonts.sans(size: 12, color: p.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          AppSwitch(p: p, value: on, onChanged: (v) => repo?.setConservationMode(v)),
        ],
      ),
    );
  }
}
