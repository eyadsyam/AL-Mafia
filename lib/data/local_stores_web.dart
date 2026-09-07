/// [openLocalStores] in a browser, where there is nothing to open.
///
/// Not a stub that throws and not a `TODO`: the app has always had to run with
/// no database, and this is that path taken deliberately rather than by
/// accident. See `local_stores.dart` for why the choice is made at the import.
library data.local_stores_web;

import 'local_stores.dart';

Future<LocalStores?> openLocalStores() async => null;
