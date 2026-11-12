import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:question_practice/app/app_build_info.dart';

void main() {
  test('describeBuildType labels every Flutter build mode', () {
    expect(
      describeBuildType(debug: true, profile: false, release: false),
      'Debug build',
    );
    expect(
      describeBuildType(debug: false, profile: true, release: false),
      'Profile build',
    );
    expect(
      describeBuildType(debug: false, profile: false, release: true),
      'Release build',
    );
    expect(
      describeBuildType(debug: false, profile: false, release: false),
      'Unknown build',
    );
  });

  test('the app version stays in step with pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml needs a semantic version');
    expect(match!.group(1), appVersion);
  });
}
