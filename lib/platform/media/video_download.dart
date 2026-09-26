/// Fetching a bundled video before it is played, where that is a thing that
/// has to happen.
///
/// On a phone it never is: the film is inside the installed app, so the stub
/// answers "nothing to download" and the player reads the asset. The web is the
/// odd one out — an "asset" there is a file on a server, and a `<video>` given
/// a URL streams it, which means a slow connection turns a 54-second intro into
/// a stutter and a second visit pays for it again. So the browser
/// implementation downloads the whole file first, reports how far it got, and
/// hands back a local URL that cannot stall.
library;

export 'video_download_stub.dart'
    if (dart.library.js_interop) 'video_download_browser.dart';
