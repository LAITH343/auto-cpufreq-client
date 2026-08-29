import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../theme/typography.dart';

/// Runs an engine action while showing a blocking progress overlay, so the UI
/// never appears frozen during the request round-trip. Dismisses on completion;
/// surfaces failures as a snackbar. Returns true on success.
Future<bool> runBusy(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  String? label,
}) async {
  final p = ref.read(paletteProvider);
  final s = ref.read(stringsProvider);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _BusyDialog(p: p, label: label ?? s.t('applying')),
  );

  var ok = false;
  String? error;
  try {
    await action();
    ok = true;
  } on ConfigValidationError catch (e) {
    error = e.message;
  } on PermissionDeniedError {
    error = s.t('permissionDenied');
  } on Object catch (e) {
    error = e.toString();
  } finally {
    if (navigator.canPop()) navigator.pop();
  }

  if (!ok && error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
  }
  return ok;
}

class _BusyDialog extends StatelessWidget {
  final Palette p;
  final String label;
  const _BusyDialog({required this.p, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
            ),
            const SizedBox(width: 14),
            Text(label, style: AppFonts.sans(size: 13.5, weight: FontWeight.w600, color: p.text)),
          ],
        ),
      ),
    );
  }
}
