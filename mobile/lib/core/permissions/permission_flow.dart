import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permission handling with explanations. Returns true only when the
/// feature can be used right now.
class PermissionFlow {
  PermissionFlow._();

  static Future<bool> ensureCamera(BuildContext context) async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await _askOpenSettings(
        context,
        title: 'Camera is turned off',
        message: 'Enable camera access in the app settings to take photos.',
      );
      return false;
    }

    final proceed = await _showRationale(
      context,
      title: 'Camera access',
      message: 'Field Notes uses the camera to attach a photo to a note.',
    );
    if (!proceed || !context.mounted) return false;

    status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (!context.mounted) return false;

    if (status.isPermanentlyDenied) {
      await _askOpenSettings(
        context,
        title: 'Camera is turned off',
        message: 'Enable camera access in the app settings to take photos.',
      );
    } else {
      _snack(context, 'Camera permission denied');
    }
    return false;
  }

  static Future<bool> ensureLocation(BuildContext context) async {
    // GPS switch must be on, otherwise there is nothing to read.
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!context.mounted) return false;
      final open = await _confirm(
        context,
        title: 'Location is off',
        message: 'Turn on location services to record where the note was taken.',
        confirmLabel: 'Open settings',
      );
      if (open) await Geolocator.openLocationSettings();
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;
      await _askOpenSettings(
        context,
        title: 'Location is turned off',
        message: 'Enable location access in the app settings to record note locations.',
      );
      return false;
    }

    if (permission == LocationPermission.denied) {
      if (!context.mounted) return false;
      final proceed = await _showRationale(
        context,
        title: 'Location access',
        message: 'Field Notes records your current location so each note shows where it was taken.',
      );
      if (!proceed) return false;

      permission = await Geolocator.requestPermission();
      if (!context.mounted) return false;

      if (permission == LocationPermission.deniedForever) {
        await _askOpenSettings(
          context,
          title: 'Location is turned off',
          message: 'Enable location access in the app settings to record note locations.',
        );
        return false;
      }
      if (permission == LocationPermission.denied) {
        _snack(context, 'Location permission denied');
        return false;
      }
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // ---------------------------------------------------------------- dialogs

  static Future<bool> _showRationale(
      BuildContext context, {
        required String title,
        required String message,
      }) {
    return _confirm(context,
        title: title, message: message, confirmLabel: 'Continue', cancelLabel: 'Not now');
  }

  static Future<void> _askOpenSettings(
      BuildContext context, {
        required String title,
        required String message,
      }) async {
    final open = await _confirm(context,
        title: title, message: message, confirmLabel: 'Open settings');
    if (open) await openAppSettings();
  }

  static Future<bool> _confirm(
      BuildContext context, {
        required String title,
        required String message,
        required String confirmLabel,
        String cancelLabel = 'Cancel',
      }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
        ],
      ),
    );
    return result ?? false;
  }

  static void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}