import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _stay = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final conn = ref.watch(connectionProvider);
    final connCtrl = ref.read(connectionProvider.notifier);
    final host = conn.pendingDevice?.hostLabel ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: connCtrl.backToDevices,
                child: Text('‹ ${s.t('devices')}',
                    style: AppFonts.sans(size: 13, color: p.textDim)),
              ),
              const SizedBox(height: 14),
              Text(s.t('signIn'),
                  style: AppFonts.sans(size: 22, weight: FontWeight.w800, color: p.text)),
              const SizedBox(height: 4),
              Text(host, style: AppFonts.mono(size: 13, color: p.textDim)),
              const SizedBox(height: 22),
              if (conn.showTofu)
                _tofu(p, s, connCtrl)
              else
                _form(p, s, conn, connCtrl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tofu(Palette p, AppStrings s, ConnectionController conn) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.warningSoft,
        border: Border.all(color: p.warning),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('verifyFingerprint'),
              style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.warning)),
          const SizedBox(height: 6),
          Text(s.t('fingerprintHelp'),
              style: AppFonts.sans(size: 12.5, height: 1.5, color: p.textDim)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r'$ auto-cpufreq gateway fingerprint',
                    style: AppFonts.mono(size: 12.5, color: p.textFaint)),
                const SizedBox(height: 4),
                Text(ConnectionController.tofuFingerprint,
                    style: AppFonts.mono(size: 12.5, weight: FontWeight.w600, color: p.accent)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  p: p,
                  label: s.t('verifyContinue'),
                  color: p.warning,
                  onPressed: conn.confirmTofu,
                ),
              ),
              const SizedBox(width: 10),
              GhostButton(p: p, label: s.t('cancel'), onPressed: conn.backToDevices),
            ],
          ),
        ],
      ),
    );
  }

  Widget _form(Palette p, AppStrings s, ConnectionState conn, ConnectionController connCtrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.t('username'), style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.textDim)),
        const SizedBox(height: 6),
        AppTextField(p: p, controller: _userCtrl),
        const SizedBox(height: 12),
        Text(s.t('password'), style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.textDim)),
        const SizedBox(height: 6),
        AppTextField(p: p, controller: _passCtrl, obscure: true),
        const SizedBox(height: 12),
        // Demo affordance: a real login derives permissions from the server.
        // This lets the permission-scoped UI be exercised without a backend.
        Text(s.t('accountRole'), style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.textDim)),
        const SizedBox(height: 6),
        AppDropdown<ConnRole>(
          p: p,
          value: conn.role == ConnRole.owner ? ConnRole.admin : conn.role,
          items: const [ConnRole.admin, ConnRole.limited],
          labelOf: (r) => r == ConnRole.admin ? 'Admin · full access' : 'Limited · partial access',
          onChanged: (r) => connCtrl.setRole(r!),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _stay = !_stay),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _stay ? p.accent : Colors.transparent,
                  border: Border.all(color: _stay ? p.accent : p.textFaint, width: 1.5),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: _stay ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
              ),
              const SizedBox(width: 8),
              Text(s.t('staySignedIn'), style: AppFonts.sans(size: 13, color: p.textDim)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(p: p, label: s.t('signIn'), expand: true, onPressed: connCtrl.login),
        const SizedBox(height: 8),
        Center(
          child: Text(s.t('demoLoginHint'),
              style: AppFonts.sans(size: 11.5, color: p.textFaint)),
        ),
      ],
    );
  }
}
