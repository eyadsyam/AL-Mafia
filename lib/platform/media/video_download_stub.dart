/// Everywhere but the web the file is already on the device.
Future<String?> downloadVideoAsset(
  String assetPath, {
  required void Function(double progress) onProgress,
}) async => null;

void releaseVideoUrl(String url) {}
