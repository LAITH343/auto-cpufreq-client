import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '8443');

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final conn = ref.read(connectionProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(p, s),
              const SizedBox(height: 28),
              _group(p, s.t('thisComputer'), [
                _deviceTile(p, s, ConnectionController.localDevice, conn, isLocal: true),
              ]),
              const SizedBox(height: 24),
              _group(p, s.t('savedDevices'),
                  ConnectionController.savedDevices.map((d) => _deviceTile(p, s, d, conn)).toList()),
              const SizedBox(height: 24),
              _group(
                  p,
                  s.t('discoveredLan'),
                  ConnectionController.discoveredDevices
                      .map((d) => _deviceTile(p, s, d, conn, discovered: true))
                      .toList()),
              const SizedBox(height: 24),
              _manualAdd(p, s, conn),
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

  Widget _group(Palette p, String label, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(p, label),
        const SizedBox(height: 10),
        ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)),
      ],
    );
  }

  Widget _deviceTile(Palette p, AppStrings s, Device d, ConnectionController conn,
      {bool isLocal = false, bool discovered = false}) {
    final online = d.online;
    return GestureDetector(
      onTap: () => conn.selectDevice(d),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: p.border,
            style: discovered ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: online ? p.success : p.textFaint,
                shape: BoxShape.circle,
                boxShadow: online
                    ? [BoxShadow(color: p.successSoft, blurRadius: 0, spreadRadius: 3)]
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isLocal ? s.t('thisComputerName') : d.name,
                      style: AppFonts.sans(size: 15, weight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 2),
                  Text(isLocal ? s.t('localEngineDetected') : d.hostLabel,
                      style: isLocal
                          ? AppFonts.sans(size: 12.5, color: p.textDim)
                          : AppFonts.mono(size: 12.5, color: p.textDim)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isLocal ? p.accentSoft : p.surface2,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(d.badge,
                  style: AppFonts.mono(
                      size: 11,
                      weight: FontWeight.w700,
                      color: isLocal ? p.accent : p.textDim)),
            ),
            const SizedBox(width: 10),
            if (discovered)
              Text(s.t('add'),
                  style: AppFonts.sans(size: 12.5, weight: FontWeight.w700, color: p.accent))
            else
              Icon(Icons.chevron_right, size: 20, color: p.textFaint),
          ],
        ),
      ),
    );
  }

  Widget _manualAdd(Palette p, AppStrings s, ConnectionController conn) {
    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('addDeviceManually'),
              style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AppTextField(p: p, controller: _hostCtrl, hint: s.t('hostPlaceholder'))),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: AppTextField(
                    p: p, controller: _portCtrl, hint: s.t('portPlaceholder'), keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 10),
              PrimaryButton(
                p: p,
                label: s.t('connect'),
                onPressed: () => conn.connectManual(_hostCtrl.text.trim(), _portCtrl.text.trim()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
