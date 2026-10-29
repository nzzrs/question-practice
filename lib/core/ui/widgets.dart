import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

export 'app_metrics.dart';
export 'app_scaffold.dart';
export 'app_sections.dart';
export 'app_success.dart';

Future<void> showSnack(
  BuildContext context,
  String message, {
  String? action,
  VoidCallback? onAction,
}) async {
  M3ESnackbar.show(
    context,
    message: message,
    actionLabel: action,
    onAction: onAction,
    showCloseButton: action == null,
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await M3EDialog.show<bool>(
    context,
    dialog: M3EDialog(
      title: title,
      content: Text(message),
      actions: [
        M3EButton.text(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        M3EButton.filled(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
