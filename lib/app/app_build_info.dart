import 'package:flutter/foundation.dart';

/// Product name shown in the About section.
const String appName = 'Questions';

/// Version taken from `version` in `pubspec.yaml`.
///
/// `pubspec.yaml` is the single source of truth. Update this constant whenever
/// the version there changes; `app_build_info_test.dart` fails when they drift
/// apart.
const String appVersion = '0.9.9';

/// Human-readable build type for the running binary.
String get appBuildTypeLabel => describeBuildType(
  debug: kDebugMode,
  profile: kProfileMode,
  release: kReleaseMode,
);

/// Maps the Flutter build-mode flags to a user-facing label.
///
/// Kept pure so tests can cover every mode even though a test binary always
/// runs in debug mode.
String describeBuildType({
  required bool debug,
  required bool profile,
  required bool release,
}) {
  if (debug) return 'Debug build';
  if (profile) return 'Profile build';
  if (release) return 'Release build';
  return 'Unknown build';
}
