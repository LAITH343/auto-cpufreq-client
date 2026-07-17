import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  static const _chartChoices = ['15m', '30m', '1h', '3h'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: ref.read(settingsProvider).deviceName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final settingsCtrl = ref.read(settingsProvider.notifier);
    final snap = ref.watch(engineControllerProvider);
    final repo = ref.watch(engineRepositoryProvider);
    final connCtrl = ref.read(connectionProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(p, s.t('deviceSection'), _deviceCard(p, s, settings, settingsCtrl, connCtrl)),
              const SizedBox(height: 22),
              _section(p, s.t('appSection'), _appCard(p, s, settings, settingsCtrl)),
              const SizedBox(height: 22),
              if (snap != null)
                _section(p, s.t('about'), _aboutCard(p, s, snap, repo, connCtrl)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(Palette p, String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(p, label),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _deviceCard(Palette p, AppStrings s, SettingsState settings,
      SettingsController ctrl, ConnectionController conn) {
    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(p, s.t('deviceName')),
          AppTextField(p: p, controller: _nameCtrl, onChanged: ctrl.setDeviceName),
          const SizedBox(height: 14),
          _label(p, s.t('reconnectBehavior')),
          AppDropdown<String>(
            p: p,
            value: settings.reconnectBehavior,
            items: const ['auto', 'manual'],
            labelOf: (v) => v == 'auto' ? s.t('reconnectAuto') : s.t('reconnectManual'),
            onChanged: (v) => ctrl.setReconnectBehavior(v!),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: GhostButton(
              p: p,
              label: s.t('forgetDevice'),
              textColor: p.danger,
              borderColor: p.danger,
              onPressed: conn.forgetDevice,
            ),
          ),
        ],
      ),
    );
  }

  Widget _appCard(
      Palette p, AppStrings s, SettingsState settings, SettingsController ctrl) {
    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rowControl(
            p,
            s.t('theme'),
            SizedBox(
              width: 150,
              child: SegmentedControl<bool>(
                p: p,
                selected: settings.dark,
                onChanged: ctrl.setDark,
                options: [SegmentOption(true, s.t('dark')), SegmentOption(false, s.t('light'))],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _rowControl(
            p,
            s.t('accent'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: kAccentChoices.map((color) {
                final active = settings.effectiveAccent.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => ctrl.setAccent(color),
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(start: 8),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active ? p.text : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _rowControl(
            p,
            s.t('language'),
            SizedBox(
              width: 150,
              child: AppDropdown<String>(
                p: p,
                value: settings.lang,
                items: AppStrings.supported,
                labelOf: (v) => AppStrings.languageNames[v] ?? v,
                onChanged: (v) => ctrl.setLang(v!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _rowControl(
            p,
            s.t('tempUnit'),
            SizedBox(
              width: 120,
              child: SegmentedControl<String>(
                p: p,
                selected: settings.tempUnit,
                onChanged: ctrl.setTempUnit,
                options: const [SegmentOption('C', '°C'), SegmentOption('F', '°F')],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _rowControl(
            p,
            s.t('chartHistory'),
            SizedBox(
              width: 110,
              child: AppDropdown<String>(
                p: p,
                value: _chartChoices.contains(settings.chartHistory) ? settings.chartHistory : '30m',
                items: _chartChoices,
                onChanged: (v) => ctrl.setChartHistory(v!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: p.border),
          const SizedBox(height: 16),
          _toggleRow(
            p,
            s.t('notifyBatteryStop'),
            s.t('notifyBatteryStopHelp'),
            settings.notifyBatteryStop,
            (_) => ctrl.toggleNotifyBatteryStop(),
          ),
          const SizedBox(height: 16),
          _toggleRow(
            p,
            s.t('notifyTemp'),
            '${s.t('notifyTempHelp')} ${settings.tempLimit}°C',
            settings.notifyTemp,
            (_) => ctrl.toggleNotifyTemp(),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard(Palette p, AppStrings s, dynamic snap, dynamic repo,
      ConnectionController conn) {
    final update = snap.update as UpdateInfo;
    final engineVer = snap.engineVersion as String;
    // Hide the mismatch warning for dev builds that report 0.0.0 / no version.
    final mismatch = engineVer.isNotEmpty &&
        engineVer != '0.0.0' &&
        snap.appVersion != engineVer;
    final checking = update.check == UpdateCheck.checking;
    final available = update.check == UpdateCheck.available;

    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv(p, s.t('appVersion'), snap.appVersion as String),
          const SizedBox(height: 10),
          _kv(p, s.t('engineVersion'), snap.engineVersion as String),
          if (mismatch) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: p.warningSoft, borderRadius: BorderRadius.circular(6)),
              child: Text(s.t('versionMismatch'),
                  style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.warning)),
            ),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: p.border),
          const SizedBox(height: 12),
          if (available)
            _updateAvailableBanner(p, s, update.latest, conn)
          else
            Row(
              children: [
                Icon(Icons.check, size: 15, color: p.success),
                const SizedBox(width: 10),
                Text(s.t('upToDate'), style: AppFonts.sans(size: 12.5, color: p.textDim)),
              ],
            ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: GhostButton(
              p: p,
              label: checking ? s.t('checkingUpdates') : s.t('checkForUpdates'),
              onPressed: checking ? null : () => repo?.checkForUpdate(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _updateAvailableBanner(
      Palette p, AppStrings s, String latest, ConnectionController conn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: p.accentSoft,
        border: Border.all(color: p.accent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.t('updateAvailable')} · v$latest',
                    style: AppFonts.sans(size: 13, weight: FontWeight.w800, color: p.accent)),
                const SizedBox(height: 2),
                Text(s.t('updateReadyBody'), style: AppFonts.sans(size: 11.5, color: p.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PrimaryButton(
            p: p,
            label: s.t('viewUpdate'),
            onPressed: () => conn.goScreen(AppScreen.update),
          ),
        ],
      ),
    );
  }

  Widget _rowControl(Palette p, String label, Widget control) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppFonts.sans(size: 13.5, weight: FontWeight.w600, color: p.text)),
        ),
        control,
      ],
    );
  }

  Widget _toggleRow(Palette p, String title, String help, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppFonts.sans(size: 13.5, weight: FontWeight.w600, color: p.text)),
              const SizedBox(height: 2),
              Text(help, style: AppFonts.sans(size: 11.5, color: p.textDim)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AppSwitch(p: p, value: value, width: 38, height: 22, onChanged: onChanged),
      ],
    );
  }

  Widget _label(Palette p, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.textDim)),
      );

  Widget _kv(Palette p, String k, String v) => Row(
        children: [
          Expanded(child: Text(k, style: AppFonts.sans(size: 13, color: p.textDim))),
          Text(v, style: AppFonts.mono(size: 13, weight: FontWeight.w700, color: p.text)),
        ],
      );
}
