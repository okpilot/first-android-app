import 'dart:ui' show Brightness;

import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/util/importance.dart';

void main() {
  group('importanceMarks', () {
    test('0 is empty; 1..3 are ! .. !!!', () {
      expect(importanceMarks(0), '');
      expect(importanceMarks(1), '!');
      expect(importanceMarks(2), '!!');
      expect(importanceMarks(3), '!!!');
    });

    test('negative and over-range are safe', () {
      expect(importanceMarks(-1), '');
      expect(importanceMarks(9), '!!!'); // clamped to 3
    });
  });

  group('importanceName', () {
    test('maps each level to a human name', () {
      expect(importanceName(0), 'None');
      expect(importanceName(1), 'Low');
      expect(importanceName(2), 'Medium');
      expect(importanceName(3), 'High');
      expect(importanceName(7), 'None'); // out of range → None
    });
  });

  group('importanceColor', () {
    test('level 0 and out-of-range have no colour', () {
      expect(importanceColor(0, Brightness.light), isNull);
      expect(importanceColor(4, Brightness.light), isNull);
      expect(importanceColor(-1, Brightness.dark), isNull);
    });

    test('levels 1..3 have a colour that differs between light and dark', () {
      for (final level in [1, 2, 3]) {
        final light = importanceColor(level, Brightness.light);
        final dark = importanceColor(level, Brightness.dark);
        expect(light, isNotNull);
        expect(dark, isNotNull);
        expect(light, isNot(dark)); // tuned per theme
      }
    });
  });
}
