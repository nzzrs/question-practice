import 'package:flutter/services.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';

abstract class WebLauncher {
  Future<void> open(Uri uri);
}

class CustomTabWebLauncher implements WebLauncher {
  @override
  Future<void> open(Uri uri) async {
    try {
      await launchUrl(uri);
    } on PlatformException catch (error) {
      throw WebLaunchException(error.message ?? 'Could not open the browser.');
    }
  }
}

class WebLaunchException implements Exception {
  const WebLaunchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecordingWebLauncher implements WebLauncher {
  final List<Uri> opened = [];

  @override
  Future<void> open(Uri uri) async {
    opened.add(uri);
  }
}
