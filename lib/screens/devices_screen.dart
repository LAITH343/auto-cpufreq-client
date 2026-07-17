import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final conn = ref.watch(connectionProvider);
    final connCtrl = ref.read(connectionProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(p, s),
              const SizedBox(height: 28),
              SectionLabel(p, s.t('thisComputer')),
              const SizedBox(height: 10),
              _localTile(p, s, conn, connCtrl),
              if (conn.error != null) ...[
                const SizedBox(height: 12),
                _errorNote(p, conn.error!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Palette p, AppStrings s) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('appName'),
                  style: AppFonts.sans(size: 22, weight: FontWeight.w800, color: p.text)),
              const SizedBox(height: 4),
              Text(s.t('chooseDevice'), style: AppFonts.sans(size: 13, color: p.textDim)),
            ],
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.grid_view_rounded, size: 20, color: p.accent),
        ),
      ],
    );
  }

  Widget _localTile(
      Palette p, AppStrings s, ConnectionState conn, ConnectionController connCtrl) {
    return GestureDetector(
      onTap: conn.connecting ? null : connCtrl.connectLocal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: p.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('thisComputerName'),
                      style: AppFonts.sans(size: 15, weight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 2),
                  Text(s.t('localEngineDetected'),
                      style: AppFonts.sans(size: 12.5, color: p.textDim)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration:
                  BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(100)),
              child: Text('D-Bus',
                  style: AppFonts.mono(size: 11, weight: FontWeight.w700, color: p.accent)),
            ),
            const SizedBox(width: 10),
            if (conn.connecting)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
              )
            else
              Icon(Icons.chevron_right, size: 20, color: p.textFaint),
          ],
        ),
      ),
    );
  }

  Widget _errorNote(Palette p, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: p.dangerSoft,
        border: Border.all(color: p.danger),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 15, color: p.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppFonts.sans(size: 12.5, weight: FontWeight.w600, color: p.danger)),
          ),
        ],
      ),
    );
  }
}
