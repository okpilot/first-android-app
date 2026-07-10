import 'dart:ui' show Brightness;

import 'package:first_android_app/models/event_type.dart';
import 'package:first_android_app/util/event_type_palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hexFromColor', () {
    test('emits a 6-digit #rrggbb with alpha stripped', () {
      // The raw 32-bit value would be 8 digits (AARRGGBB) and fail the DB CHECK; the
      // alpha here (0x80) must NOT leak into the string.
      expect(hexFromColor(const Color(0x804E7BC9)), '#4e7bc9');
      expect(hexFromColor(const Color(0xFF4E7BC9)), '#4e7bc9');
      expect(hexFromColor(const Color(0xFF4E7BC9)).length, 7);
    });

    test('round-trips through colorFromHex (opaque)', () {
      for (final s in kEventTypePalette) {
        expect(
          colorFromHex(hexFromColor(s.color)).toARGB32(),
          s.color.toARGB32(),
        );
      }
    });
  });

  group('colorFromHex', () {
    test('parses a valid #RRGGBB as an opaque colour', () {
      expect(
        colorFromHex('#4E7BC9').toARGB32(),
        const Color(0xFF4E7BC9).toARGB32(),
      );
    });

    test('falls back to the neutral swatch on bad input', () {
      for (final bad in ['#fff', 'blue', '#ff4e7bc9', '']) {
        expect(colorFromHex(bad).toARGB32(), kNeutralSwatch.toARGB32());
      }
    });
  });

  group('fillForType', () {
    const baseFill = Color(0xFF202020);

    test('an untyped event keeps the mono base fill', () {
      expect(
        fillForType(null, Brightness.light, baseFill).toARGB32(),
        baseFill.toARGB32(),
      );
    });

    test('a typed event tints the base fill, matching tintForType', () {
      const type = EventType(id: 't', name: 'Blue', colorHex: '#4E7BC9');
      for (final b in Brightness.values) {
        final got = fillForType(type, b, baseFill);
        expect(
          got.toARGB32(),
          tintForType(colorFromHex('#4E7BC9'), b, baseFill).toARGB32(),
        );
        // A colour is actually applied — not left as the mono fill.
        expect(got.toARGB32(), isNot(baseFill.toARGB32()));
      }
    });
  });
}
