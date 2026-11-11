/// The app writes every number with Western digits (0-9), in Arabic too:
/// owner's decision 2026-11-11, so a count, a timer and the copy beside them
/// never read «3 من ٤». Locale formatters (dates, `NumberFormat`) hand Arabic
/// back in Arabic-Indic digits; their output passes through here.
String westernDigits(String text) {
  const arabicZero = 0x0660;
  const easternZero = 0x06F0; // Persian/Urdu forms, in case a formatter uses them
  final out = StringBuffer();
  for (final unit in text.codeUnits) {
    if (unit >= arabicZero && unit <= arabicZero + 9) {
      out.writeCharCode(0x30 + unit - arabicZero);
    } else if (unit >= easternZero && unit <= easternZero + 9) {
      out.writeCharCode(0x30 + unit - easternZero);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}
