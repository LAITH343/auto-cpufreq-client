import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../util/format.dart';
import '../widgets/busy.dart';
import '../widgets/common.dart';

class ControlsScreen extends ConsumerWidget {
  const ControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final snap = ref.watch(engineControllerProvider);
    final repo = ref.watch(engineRepositoryProvider);
    final canWrite = ref.watch(
        connectionProvider.select((c) => c.permissions.canWrite('controls')));

    if (snap == null) return const SizedBox.shrink();

    final hasOverride = snap.governorOverride != 'auto' || snap.turboOverride != 'auto';

    Widget card(String title, String effectiveLabel, Widget selector) => AppCard(
          p: p,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          radius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.text)),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: '${s.t('currentlyInEffect')}: ',
                  style: AppFonts.sans(size: 12.5, color: p.textDim),
                  children: [
                    TextSpan(
                      text: effectiveLabel,
                      style: AppFonts.sans(size: 12.5, weight: FontWeight.w700, color: p.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Opacity(opacity: canWrite ? 1 : 0.5, child: selector),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasOverride) ...[
                _banner(p, p.warning, p.warningSoft, s.t('overrideBanner')),
                const SizedBox(height: 18),
              ],
              if (!canWrite) ...[
                LockNote(p, s.t('controlsReadOnlyNote')),
                const SizedBox(height: 18),
              ],
              card(
                s.t('governorOverride'),
                Labels.governor(s, Labels.effectiveGovernor(snap)),
                SegmentedControl<String>(
                  p: p,
                  selected: snap.governorOverride,
                  onChanged: canWrite && repo != null
                      ? (v) => runBusy(context, ref, () => repo.setGovernorOverride(v))
                      : null,
                  options: [
                    SegmentOption('auto', Labels.governor(s, 'auto')),
                    SegmentOption('performance', Labels.governor(s, 'performance')),
                    SegmentOption('powersave', Labels.governor(s, 'powersave')),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              card(
                s.t('turboOverride'),
                Labels.turbo(s, Labels.effectiveTurbo(snap)),
                SegmentedControl<String>(
                  p: p,
                  selected: snap.turboOverride,
                  onChanged: canWrite && repo != null
                      ? (v) => runBusy(context, ref, () => repo.setTurboOverride(v))
                      : null,
                  options: [
                    SegmentOption('auto', Labels.turbo(s, 'auto')),
                    SegmentOption('always', Labels.turbo(s, 'always')),
                    SegmentOption('never', Labels.turbo(s, 'never')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(Palette p, Color color, Color soft, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: soft,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: AppFonts.sans(size: 13, weight: FontWeight.w700, color: color)),
    );
  }
}
