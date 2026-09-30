import 'package:flutter/services.dart';

Future<void> loadAppFonts() async {
  for (final (family, files) in [
    ('Barlow', ['Barlow-Regular', 'Barlow-Medium', 'Barlow-Bold']),
    ('BarlowCondensed', ['BarlowCondensed-Regular', 'BarlowCondensed-SemiBold']),
  ]) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f.ttf'));
    }
    await loader.load();
  }
}
