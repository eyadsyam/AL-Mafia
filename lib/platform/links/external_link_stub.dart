import 'package:url_launcher/url_launcher.dart';

import 'external_link_contract.dart';

Future<bool> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

ExternalLinkReservation reserveExternal(String url) =>
    ExternalLinkReservation(commit: () => openExternal(url), cancel: () {});
