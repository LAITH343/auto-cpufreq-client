import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';

class UpdateScreen extends ConsumerWidget {
  const UpdateScreen({super.key});

  static const _notes = [
    'Live stats now stream over a single WebSocket with lower latency.',
    'Per-core temperatures respect the chosen temperature unit everywhere.',
    'Fixed a rare reconnect loop when the gateway restarted mid-session.',
    'Battery conservation-mode support for additional Lenovo models.',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final snap = ref.watch(engineControllerProvider);
    final repo = ref.watch(engineRepositoryProvider);
    final conn = ref.read(connectionProvider.notifier);
    if (snap == null) return const SizedBox.shrink();
    final u = snap.update;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => conn.goScreen(AppScreen.settings),
                child: Text('‹ ${s.t('backToSettings')}',
                    style: AppFonts.sans(size: 13, color: p.textDim)),
              ),
              const SizedBox(height: 18),
              if (u.check == UpdateCheck.available)
                _availableCard(p, s, snap, repo, conn)
              else
                _upToDateCard(p, s, snap, repo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upToDateCard(Palette p, AppStrings s, dynamic snap, dynamic repo) {
    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: p.successSoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.check, size: 26, color: p.success),
          ),
          const SizedBox(height: 12),
          Text(s.t('upToDate'), style: AppFonts.sans(size: 16, weight: FontWeight.w800, color: p.text)),
          const SizedBox(height: 6),
          Text('v${snap.appVersion}', style: AppFonts.mono(size: 12.5, color: p.textDim)),
          const SizedBox(height: 14),
          GhostButton(
            p: p,
            label: s.t('checkForUpdates'),
            onPressed: () => repo?.checkForUpdate(),
          ),
        ],
      ),
    );
  }

  Widget _availableCard(
      Palette p, AppStrings s, dynamic snap, dynamic repo, ConnectionController conn) {
    final u = snap.update as UpdateInfo;
    return AppCard(
      p: p,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.system_update_alt, size: 24, color: p.accent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('updateAvailable'),
                          style: AppFonts.sans(size: 16, weight: FontWeight.w800, color: p.text)),
                      const SizedBox(height: 2),
                      Text(s.t('updateReadyBody'), style: AppFonts.sans(size: 12.5, color: p.textDim)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                _versionCol(p, s.t('currentVersion'), 'v${snap.appVersion}', p.textDim),
                Icon(Icons.arrow_forward, size: 18, color: p.textFaint),
                _versionCol(p, s.t('newVersion'), 'v${u.latest}', p.accent),
                _versionCol(p, s.t('downloadSize'), '48.2 MB', p.text),
              ],
            ),
          ),
          Container(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('whatsNew').toUpperCase(), style: AppFonts.sectionLabel(p.textFaint)),
                const SizedBox(height: 12),
                ..._notes.map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 7),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(n,
                                style: AppFonts.sans(size: 13, height: 1.5, color: p.text)),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          Container(
            color: p.surface2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: _footer(p, s, u, repo, conn),
          ),
        ],
      ),
    );
  }

  Widget _footer(
      Palette p, AppStrings s, UpdateInfo u, dynamic repo, ConnectionController conn) {
    switch (u.phase) {
      case UpdatePhase.idle:
        return Row(
          children: [
            Expanded(
              child: Text('${s.t('channel')}: ${s.t('channelStable')} · ${s.t('releaseDate')} Jul 8, 2026',
                  style: AppFonts.mono(size: 11.5, color: p.textDim)),
            ),
            const SizedBox(width: 10),
            PrimaryButton(p: p, label: s.t('downloadInstall'), onPressed: () => repo?.startUpdateInstall()),
          ],
        );
      case UpdatePhase.downloading:
      case UpdatePhase.installing:
        final label = u.phase == UpdatePhase.downloading ? s.t('downloadingLabel') : s.t('installingLabel');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: AppFonts.sans(size: 12.5, weight: FontWeight.w700, color: p.text)),
                ),
                Text('${u.progress}%', style: AppFonts.mono(size: 12.5, weight: FontWeight.w700, color: p.accent)),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: u.progress / 100,
                minHeight: 6,
                backgroundColor: p.hover,
                valueColor: AlwaysStoppedAnimation(p.accent),
              ),
            ),
          ],
        );
      case UpdatePhase.done:
        return Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: p.successSoft, shape: BoxShape.circle),
              child: Icon(Icons.check, size: 16, color: p.success),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('updateComplete'),
                      style: AppFonts.sans(size: 13, weight: FontWeight.w700, color: p.text)),
                  Text(s.t('restartToFinish'), style: AppFonts.sans(size: 11.5, color: p.textDim)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            PrimaryButton(p: p, label: s.t('restartNow'), color: p.success, onPressed: conn.signOut),
          ],
        );
    }
  }

  Widget _versionCol(Palette p, String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppFonts.sectionLabel(p.textFaint).copyWith(fontSize: 10.5)),
          const SizedBox(height: 5),
          Text(value, style: AppFonts.mono(size: 16, weight: FontWeight.w800, color: valueColor)),
        ],
      ),
    );
  }
}
