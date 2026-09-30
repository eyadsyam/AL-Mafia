/// This build's number: the part after the `+` in `pubspec.yaml`'s `version`
/// (Android's `versionCode`, and the number the web bundle is stamped with).
///
/// Kept here as a constant because the app has no package-info plugin and the
/// minimum-build check (`update_gate.dart`) must work in every build. A test
/// (`test/app/app_build_test.dart`) reads `pubspec.yaml` and fails if the two
/// drift, so bumping the version means bumping this in the same commit.
const int kAppBuildNumber = 10;
