import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:first_android_app/theme.dart';
import 'package:first_android_app/widgets/initials_avatar.dart';

// InitialsAvatar takes no repository — no fakes needed.
//
// Why an atom this small is tested: it has two failure modes that are invisible to
// `flutter analyze` AND easy to pass in a screenshot with narrow test initials ("AT", "DR")
// while wide ones ("WW") break (Decision 47, found by semantic-reviewer post-commit):
//   1. Inside a Material Chip the avatar's BOX is pinned to a tight `contentSize` and `radius`
//      is ignored — but `fontSize: radius * 0.7` is NOT box-constrained, so the glyphs render
//      for a disc they aren't in and paint out over it. Guarded by a FittedBox(scaleDown).
//   2. The disc fills with `secondaryContainer`, the SAME token a chip fills with (the mono
//      scheme aliases all three container roles onto one colour), so on a chip it dissolves.
//      `onChipFill` flips it to `surface`. (`ring` did too, but cost ~5px out of the pinned
//      box — halving the disc — so the chip sites use colour, not a ring.)

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

Widget _inChip(Widget avatar, String name) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Center(
      child: InputChip(avatar: avatar, label: Text(name), onDeleted: () {}),
    ),
  ),
);

void main() {
  testWidgets('chip site: WIDE initials stay inside the disc (no spill)', (
    tester,
  ) async {
    // "WW" is the widest initial pair; the exact regression semantic-reviewer caught. The
    // FittedBox is laid out to the disc, so its box can never exceed the CircleAvatar's.
    await tester.pumpWidget(
      _inChip(
        const InitialsAvatar(name: 'Wanda Wu', radius: 11, onChipFill: true),
        'Wanda Wu',
      ),
    );
    await tester.pumpAndSettle();

    final disc = tester.getSize(find.byType(CircleAvatar)).width;
    final glyphBox = tester.getSize(find.byType(FittedBox)).width;
    expect(
      glyphBox,
      lessThanOrEqualTo(disc),
      reason: 'initials must never paint past the disc edge',
    );
  });

  testWidgets('onChipFill flips the disc to surface so it does not dissolve', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const InitialsAvatar(name: 'Ada Lovelace', onChipFill: true)),
    );
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));

    // surface, NOT secondaryContainer — the token a chip fills with.
    expect(avatar.backgroundColor, AppTheme.light.colorScheme.surface);
  });

  testWidgets('default disc uses the neutral chip token (off a chip)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const InitialsAvatar(name: 'Ada Lovelace')));
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));

    expect(
      avatar.backgroundColor,
      AppTheme.light.colorScheme.secondaryContainer,
    );
    expect(tester.getSize(find.byType(InitialsAvatar)), const Size(40, 40));
  });

  testWidgets('ring wraps the disc in a surface ring so it punches out', (
    tester,
  ) async {
    // Still used by the calendar's overlapping avatar stack — where nothing pins the box,
    // so the ring's 2px is free. (The chip sites use onChipFill instead; see the header.)
    await tester.pumpWidget(
      _wrap(const InitialsAvatar(name: 'Ada Lovelace', ring: true)),
    );
    final ring =
        tester
                .widgetList<Container>(
                  find.descendant(
                    of: find.byType(InitialsAvatar),
                    matching: find.byType(Container),
                  ),
                )
                .first
                .decoration!
            as BoxDecoration;

    expect(ring.shape, BoxShape.circle);
    expect(ring.color, AppTheme.light.colorScheme.surface);
    expect(ring.border, isNotNull);
  });
}
