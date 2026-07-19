import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cert_store.dart';
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
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _stay = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final lf = ref.watch(connectionProvider.select((c) => c.login));
    final ctrl = ref.read(connectionProvider.notifier);
    if (lf == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: ctrl.backToDevices,
                child: Text('‹ ${s.t('devices')}',
                    style: AppFonts.sans(size: 13, color: p.textDim)),
              ),
              const SizedBox(height: 14),
              Text(s.t('signIn'),
                  style: AppFonts.sans(size: 22, weight: FontWeight.w800, color: p.text)),
              const SizedBox(height: 4),
              Text(lf.hostLabel, style: AppFonts.mono(size: 13, color: p.textDim)),
              const SizedBox(height: 22),
              if (lf.checking) _checking(p, s),
              if (lf.showTofu) _tofuCard(p, s, lf, ctrl),
              if (lf.tofuDone) _form(p, s, lf, ctrl),
              if (lf.error != null && !lf.showTofu) ...[
                const SizedBox(height: 14),
                _errorNote(p, lf.error!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _checking(Palette p, AppStrings s) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
        ),
        const SizedBox(width: 12),
        Text(s.t('checkingServer'), style: AppFonts.sans(size: 13, color: p.textDim)),
      ],
    );
  }

  Widget _tofuCard(Palette p, AppStrings s, LoginFlow lf, ConnectionController ctrl) {
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
          if (lf.changed) ...[
            Text(s.t('certChangedWarn'),
                style: AppFonts.sans(size: 12.5, weight: FontWeight.w700, color: p.danger)),
            const SizedBox(height: 8),
          ],
          Text(s.t('fingerprintHelp'),
              style: AppFonts.sans(size: 12.5, color: p.textDim, height: 1.5)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\$ sudo auto-cpufreq gateway fingerprint',
                    style: AppFonts.mono(size: 11.5, color: p.textFaint)),
                const SizedBox(height: 4),
                SelectableText('SHA256: ${lf.fingerprint ?? ''}',
                    style: AppFonts.mono(size: 12, weight: FontWeight.w600, color: p.accent)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  p: p,
                  color: p.warning,
                  label: s.t('verifyContinue'),
                  onPressed: ctrl.confirmTofu,
                ),
              ),
              const SizedBox(width: 10),
              GhostButton(p: p, label: s.t('cancel'), onPressed: ctrl.backToDevices),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: _importCert,
              child: Text(s.t('chooseCert'),
                  style: AppFonts.sans(size: 12, weight: FontWeight.w700, color: p.accent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(Palette p, AppStrings s, LoginFlow lf, ConnectionController ctrl) {
    final canSubmit =
        _user.text.isNotEmpty && _pass.text.isNotEmpty && !lf.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(p, s.t('username')),
        AppTextField(p: p, controller: _user, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _label(p, s.t('password')),
        AppTextField(
            p: p, controller: _pass, obscure: true, onChanged: (_) => setState(() {})),
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
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _stay ? p.accent : p.border, width: 1.5),
                ),
                child: _stay ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
              ),
              const SizedBox(width: 8),
              Text(s.t('staySignedIn'), style: AppFonts.sans(size: 13, color: p.textDim)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          p: p,
          expand: true,
          label: lf.submitting ? s.t('connecting') : s.t('signIn'),
          onPressed: canSubmit ? () => ctrl.doLogin(_user.text, _pass.text, remember: _stay) : null,
        ),
      ],
    );
  }

  Future<void> _importCert() async {
    final s = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    PickedCert? picked;
    try {
      picked = await CertStore.pick();
    } on InvalidCertException {
      messenger.showSnackBar(SnackBar(content: Text(s.t('invalidCert'))));
      return;
    }
    if (picked == null || !mounted) return;
    final trusted = await _confirmFingerprint(picked.fingerprint);
    if (trusted != true || !mounted) return;
    final path = await CertStore.save(picked);
    if (!mounted) return;
    ref.read(connectionProvider.notifier).applyImportedCert(path);
    messenger.showSnackBar(SnackBar(content: Text(s.t('certSaved'))));
  }

  Future<bool?> _confirmFingerprint(String fingerprint) {
    final p = ref.read(paletteProvider);
    final s = ref.read(stringsProvider);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(s.t('trustTitle'),
            style: AppFonts.sans(size: 16, weight: FontWeight.w800, color: p.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('trustHelp'), style: AppFonts.sans(size: 12.5, color: p.textDim)),
            const SizedBox(height: 12),
            SelectableText(fingerprint,
                style: AppFonts.mono(size: 12, weight: FontWeight.w600, color: p.text)),
          ],
        ),
        actions: [
          GhostButton(
              p: p, label: s.t('cancel'), onPressed: () => Navigator.of(context).pop(false)),
          PrimaryButton(
              p: p, label: s.t('trust'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
  }

  Widget _label(Palette p, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppFonts.sans(size: 12, weight: FontWeight.w600, color: p.textDim)),
      );

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
