import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';

class GatewayDisabledScreen extends ConsumerWidget {
  const GatewayDisabledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final conn = ref.read(connectionProvider.notifier);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.block, size: 26, color: p.textFaint),
            ),
            const SizedBox(height: 14),
            Text(s.t('gatewayDisabledTitle'),
                style: AppFonts.sans(size: 16, weight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(s.t('gatewayDisabledBody'),
                  textAlign: TextAlign.center,
                  style: AppFonts.sans(size: 13, height: 1.5, color: p.textDim)),
            ),
            const SizedBox(height: 16),
            GhostButton(p: p, label: s.t('backToDevices'), onPressed: conn.backToDevices),
          ],
        ),
      ),
    );
  }
}
