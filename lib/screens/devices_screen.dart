import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/discovery_service.dart';
import '../data/saved_devices.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
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
    final saved = ref.watch(savedDevicesProvider);
    final discovered = ref.watch(discoveredDevicesProvider).valueOrNull ?? const [];

    // Don't list a discovered device that's already saved.
    final savedKeys = {for (final d in saved) '${d.host}:${d.port}'};
    final discoveredOnly =
        discovered.where((d) => !savedKeys.contains('${d.host}:${d.port}')).toList();

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
              if (saved.isNotEmpty) ...[
                const SizedBox(height: 28),
                SectionLabel(p, s.t('savedDevices')),
                const SizedBox(height: 10),
                for (final d in saved) ...[
                  _deviceTile(p, d, dashed: false, onTap: () => connCtrl.openLogin(d)),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 28),
              _discoveredHeader(p, s, ref),
              const SizedBox(height: 10),
              if (discoveredOnly.isEmpty)
                _discoveredEmpty(p, s)
              else
                for (final d in discoveredOnly) ...[
                  _deviceTile(p, d,
                      dashed: true,
                      trailing: Text(s.t('add'),
                          style: AppFonts.sans(
                              size: 12.5, weight: FontWeight.w700, color: p.accent)),
                      onTap: () => connCtrl.openLogin(d)),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 28),
              _ManualAdd(),
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

  Widget _discoveredHeader(Palette p, AppStrings s, WidgetRef ref) {
    final scanning = ref.watch(discoveredDevicesProvider).isLoading;
    return Row(
      children: [
        Expanded(child: SectionLabel(p, s.t('discoveredLan'))),
        if (scanning)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: p.textFaint),
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
            _statusDot(p, p.success, p.successSoft),
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
            _badge(p, 'D-Bus', p.accentSoft, p.accent),
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

  Widget _deviceTile(Palette p, Device d,
      {required bool dashed, required VoidCallback onTap, Widget? trailing}) {
    final color = d.online ? p.success : p.textFaint;
    final ring = d.online ? p.successSoft : p.surface2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: dashed ? null : Border.all(color: p.border),
        ),
        foregroundDecoration: dashed ? _DashedBorder(dashColor: p.border, dashRadius: 10) : null,
        child: Row(
          children: [
            _statusDot(p, color, ring),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.sans(size: 15, weight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 2),
                  Text(d.hostLabel,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.mono(size: 12.5, color: p.textDim)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _badge(p, d.badge, p.surface2, p.textDim),
            const SizedBox(width: 10),
            trailing ?? Icon(Icons.chevron_right, size: 20, color: p.textFaint),
          ],
        ),
      ),
    );
  }

  Widget _discoveredEmpty(Palette p, AppStrings s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      foregroundDecoration: _DashedBorder(dashColor: p.border, dashRadius: 10),
      child: Row(
        children: [
          Icon(Icons.wifi_find_outlined, size: 16, color: p.textFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s.t('noneDiscovered'),
                style: AppFonts.sans(size: 12.5, color: p.textDim)),
          ),
        ],
      ),
    );
  }

  Widget _statusDot(Palette p, Color color, Color ring) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: ring, blurRadius: 0, spreadRadius: 3)],
      ),
    );
  }

  Widget _badge(Palette p, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: AppFonts.mono(size: 11, weight: FontWeight.w700, color: fg)),
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

/// Compact host/port row that hands off to the sign-in flow.
class _ManualAdd extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ManualAdd> createState() => _ManualAddState();
}

class _ManualAddState extends ConsumerState<_ManualAdd> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '8443');

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  void _connect() {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 0;
    if (host.isEmpty || port <= 0) return;
    ref.read(connectionProvider.notifier).openManual(host, port);
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('addDeviceManually'),
              style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  p: p,
                  controller: _host,
                  hint: s.t('hostPlaceholder'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: AppTextField(
                  p: p,
                  controller: _port,
                  hint: s.t('portPlaceholder'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              PrimaryButton(
                p: p,
                label: s.t('connect'),
                onPressed: _host.text.trim().isEmpty ? null : _connect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Paints a dashed rounded border over a tile (discovered devices).
class _DashedBorder extends BoxDecoration {
  final Color dashColor;
  final double dashRadius;
  const _DashedBorder({required this.dashColor, required this.dashRadius});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedPainter(dashColor, dashRadius);
}

class _DashedPainter extends BoxPainter {
  final Color color;
  final double radius;
  _DashedPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final rect = offset & cfg.size!;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }
}
