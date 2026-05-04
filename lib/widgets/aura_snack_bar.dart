import 'dart:async';

import 'package:flutter/material.dart';

const Duration auraSnackBarDuration = Duration(seconds: 5);
const Duration auraBriefSnackBarDuration = Duration(seconds: 2);

int _snackBarGeneration = 0;

void showAuraSnackBar(
  BuildContext context, {
  required String message,
  SnackBarAction? action,
  Duration duration = auraSnackBarDuration,
  Color? backgroundColor,
}) {
  if (!context.mounted) return;

  showAuraSnackBarWithMessenger(
    ScaffoldMessenger.of(context),
    message: message,
    action: action,
    duration: duration,
    backgroundColor: backgroundColor,
  );
}

void showAuraSnackBarWithMessenger(
  ScaffoldMessengerState messenger, {
  required String message,
  SnackBarAction? action,
  Duration duration = auraSnackBarDuration,
  Color? backgroundColor,
}) {
  final generation = ++_snackBarGeneration;

  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      action: action,
    ),
  );

  unawaited(
    controller.closed.then((_) {
      if (_snackBarGeneration == generation) {
        _snackBarGeneration++;
      }
    }),
  );

  unawaited(
    Future<void>.delayed(duration, () {
      if (_snackBarGeneration == generation) {
        controller.close();
      }
    }),
  );
}
