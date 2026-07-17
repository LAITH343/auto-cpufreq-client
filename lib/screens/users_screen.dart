import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/connection_controller.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';
import '../widgets/common.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String? _selectedName;
  bool _creating = false;
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  static const _featureKeys = {
    'stats': 'featStats',
    'controls': 'featControls',
    'config': 'featConfig',
    'battery': 'featBattery',
    'bluetooth': 'featBluetooth',
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _toggleCode(String cur, String type) {
    if (type == 'r') return cur == 'none' ? 'r' : 'none';
    return cur == 'rw' ? 'r' : 'rw';
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final snap = ref.watch(engineControllerProvider);
    final repo = ref.watch(engineRepositoryProvider);
    if (snap == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.t('userList'),
                        style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.text)),
                  ),
                  PrimaryButton(
                    p: p,
                    label: '+ ${s.t('newUser')}',
                    onPressed: () => setState(() => _creating = true),
                  ),
                ],
              ),
              if (_creating) ...[
                const SizedBox(height: 16),
                _createForm(p, s, repo),
              ],
              const SizedBox(height: 22),
              ...snap.users.map((u) => _userRow(p, s, u, repo)),
              const SizedBox(height: 22),
              Text(s.t('activeSessions'),
                  style: AppFonts.sans(size: 13.5, weight: FontWeight.w700, color: p.text)),
              const SizedBox(height: 10),
              ...snap.sessions.map((ss) => _sessionRow(p, s, ss, repo)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createForm(Palette p, AppStrings s, dynamic repo) {
    return AppCard(
      p: p,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      radius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('newUser'), style: AppFonts.sans(size: 13, weight: FontWeight.w700, color: p.text)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(width: 200, child: AppTextField(p: p, controller: _nameCtrl, hint: s.t('username'))),
              SizedBox(width: 200, child: AppTextField(p: p, controller: _passCtrl, hint: s.t('password'), obscure: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              PrimaryButton(
                p: p,
                label: s.t('create'),
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  repo?.createUser(name, _passCtrl.text);
                  _nameCtrl.clear();
                  _passCtrl.clear();
                  setState(() => _creating = false);
                },
              ),
              const SizedBox(width: 10),
              GhostButton(
                p: p,
                label: s.t('cancel'),
                onPressed: () {
                  _nameCtrl.clear();
                  _passCtrl.clear();
                  setState(() => _creating = false);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _userRow(Palette p, AppStrings s, AppUser u, dynamic repo) {
    final selected = _selectedName == u.name;
    final allRw = kFeatures.every((f) => u.perms[f] == 'rw');
    final summary = !u.enabled
        ? s.t('disabled')
        : (allRw ? s.t('fullAccess') : s.t('customPermissions'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedName = selected ? null : u.name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: selected ? p.accent : p.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: u.enabled ? p.success : p.textFaint, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.name,
                            style: AppFonts.sans(size: 14, weight: FontWeight.w700, color: p.text)),
                        const SizedBox(height: 2),
                        Text(summary, style: AppFonts.sans(size: 11.5, color: p.textDim)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => repo?.setUserEnabled(u.name, !u.enabled),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: u.enabled ? p.successSoft : p.surface2,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(u.enabled ? s.t('enabled') : s.t('disabled'),
                          style: AppFonts.sans(
                              size: 11,
                              weight: FontWeight.w700,
                              color: u.enabled ? p.success : p.textDim)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _linkAction(p, s.t('resetPassword'), p.textDim, () => repo?.resetPassword(u.name)),
                  _linkAction(p, s.t('delete'), p.danger, () {
                    if (_selectedName == u.name) _selectedName = null;
                    repo?.deleteUser(u.name);
                  }),
                ],
              ),
            ),
          ),
          if (selected) _permMatrix(p, s, u, repo),
        ],
      ),
    );
  }

  Widget _linkAction(Palette p, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Text(label, style: AppFonts.sans(size: 11.5, weight: FontWeight.w600, color: color)),
      ),
    );
  }

  Widget _permMatrix(Palette p, AppStrings s, AppUser u, dynamic repo) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('permissionMatrix'),
              style: AppFonts.sans(size: 12, weight: FontWeight.w700, color: p.textDim)),
          const SizedBox(height: 10),
          ...kFeatures.map((f) {
            final val = u.perms[f] ?? 'none';
            final hasR = val == 'r' || val == 'rw';
            final hasW = val == 'rw';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.t(_featureKeys[f]!),
                        style: AppFonts.sans(size: 13, weight: FontWeight.w600, color: p.text)),
                  ),
                  _permBox(p, 'R', hasR, () => repo?.setUserPermission(u.name, f, _toggleCode(val, 'r'))),
                  const SizedBox(width: 12),
                  _permBox(p, 'W', hasW, () => repo?.setUserPermission(u.name, f, _toggleCode(val, 'w'))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _permBox(Palette p, String letter, bool on, VoidCallback onTap) {
    final color = on ? p.accent : p.textFaint;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: on ? p.accent : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 5),
          Text(letter, style: AppFonts.sans(size: 11.5, weight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _sessionRow(Palette p, AppStrings s, SessionInfo ss, dynamic repo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        p: p,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        radius: BorderRadius.circular(8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(
                    text: ss.username,
                    style: AppFonts.sans(size: 13, weight: FontWeight.w700, color: p.text),
                    children: [
                      TextSpan(
                          text: ' · ${ss.device}',
                          style: AppFonts.sans(size: 13, color: p.textDim)),
                    ],
                  )),
                  const SizedBox(height: 2),
                  Text('${ss.ip} · ${ss.since}',
                      style: AppFonts.mono(size: 11.5, color: p.textFaint)),
                ],
              ),
            ),
            GhostButton(
              p: p,
              label: s.t('revoke'),
              textColor: p.danger,
              onPressed: () => repo?.revokeSession(ss.id),
            ),
          ],
        ),
      ),
    );
  }
}
