Future<bool> tryH5Break(String client, String type, String name) async => false;

void showGoogleBanner(
  String client,
  String slot,
  double left,
  double top,
  double width,
  double height,
  void Function(bool filled) onFilled,
) => onFilled(false);

void hideGoogleBanner() {}
