import 'leave_warning_stub.dart'
    if (dart.library.js_interop) 'leave_warning_browser.dart'
    as impl;

/// While [on], a reload or a closed tab asks the browser's «Leave site?»
/// first, so a table in progress is not lost to a stray pull or click.
/// Does nothing off the web.
void setLeaveWarning(bool on) => impl.setLeaveWarning(on);
