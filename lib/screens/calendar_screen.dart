import 'package:flutter/material.dart';

import '../util/calendar.dart';
import '../widgets/empty_state.dart';

/// The Calendar destination: a period header + a scrollable view switcher
/// (Month · 3-day · Day · Agenda) over the four views. This slice is the calendar
/// *chrome* only — there are no events yet (that's the next slice), so the day
/// panel, timelines, and agenda show designed empty states.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.initialDate});

  /// Defaults to today; injectable so widget tests are deterministic.
  final DateTime? initialDate;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['Month', '3-day', 'Day', 'Agenda'];

  late final TabController _tab;
  // The focused day is the single source of truth: it drives the month grid, the
  // selected-day highlight/panel, and the Day/3-day timeline anchor — so a day
  // picked in Month carries into the other views instead of desyncing.
  late DateTime _focused;

  @override
  void initState() {
    super.initState();
    _focused = dayOnly(widget.initialDate ?? DateTime.now());
    _tab = TabController(length: _tabs.length, vsync: this);
    // Rebuild so the AppBar period label tracks the active tab.
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// Step the focused period by one unit in the current view's own unit.
  void _step(int dir) {
    setState(() {
      switch (_tab.index) {
        case 0: // Month → ±1 month (constructor normalizes)
          _focused = DateTime(_focused.year, _focused.month + dir, 1);
        case 1: // 3-day → ±3 days
          _focused = DateTime(
            _focused.year,
            _focused.month,
            _focused.day + 3 * dir,
          );
        case 2: // Day → ±1 day
          _focused = DateTime(
            _focused.year,
            _focused.month,
            _focused.day + dir,
          );
        default: // Agenda → ±1 week
          _focused = DateTime(
            _focused.year,
            _focused.month,
            _focused.day + 7 * dir,
          );
      }
    });
  }

  void _goToday() {
    setState(() => _focused = dayOnly(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        // Group the nav chevrons with the period label (not floated to the far
        // right), matching the prototype.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                periodLabel(_tab.index, _focused),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () => _step(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () => _step(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: _goToday, child: const Text('Today')),
          const SizedBox(width: 8),
        ],
        // Four short labels fit — evenly split, not a left-packed scroll strip.
        bottom: TabBar(
          controller: _tab,
          tabs: [for (final t in _tabs) Tab(text: t)],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MonthView(
            month: _focused,
            selected: _focused,
            onSelect: (d) => setState(() => _focused = d),
          ),
          _TimelineView(start: _focused, dayCount: 3),
          _TimelineView(start: _focused, dayCount: 1),
          const _AgendaView(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month
// ---------------------------------------------------------------------------

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.selected,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = monthGrid(month);
    final today = dayOnly(DateTime.now());

    return ListView(
      children: [
        // weekday header
        Row(
          children: [
            for (final wd in weekdayShort)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    wd,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ),
          ],
        ),
        const Divider(height: 1),
        // 6 rows × 7 cells
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _DayCell(
                    day: days[row * 7 + col],
                    inMonth: days[row * 7 + col].month == month.month,
                    isToday: isSameDay(days[row * 7 + col], today),
                    isSelected: isSameDay(days[row * 7 + col], selected),
                    lastCol: col == 6,
                    onTap: () => onSelect(days[row * 7 + col]),
                  ),
                ),
            ],
          ),
        _SelectedDayPanel(day: selected, isToday: isSameDay(selected, today)),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.lastCol,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final bool lastCol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // today = ink fill; selected (not today) = ink ring — distinct by shape, not
    // colour alone, and distinct from each other even when today is selected.
    final Color numberColor = isToday
        ? scheme.onPrimary
        : (inMonth ? scheme.onSurface : scheme.onSurfaceVariant);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${dayLabel(day)}${isToday ? ', today' : ''}, no events',
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56, // ≥44 tap target under compact density
          // Hairline grid so it reads as a calendar (Decision 13), like the mockup.
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
              right: lastCol
                  ? BorderSide.none
                  : BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday ? scheme.primary : Colors.transparent,
                border: (isSelected && !isToday)
                    ? Border.all(color: scheme.primary, width: 1.5)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: textTheme.bodyMedium?.copyWith(
                  color: numberColor,
                  fontWeight: (isToday || isSelected)
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDayPanel extends StatelessWidget {
  const _SelectedDayPanel({required this.day, required this.isToday});

  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dayLabel(day)}${isToday ? ' · Today' : ''}'.toUpperCase(),
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'No events',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day / 3-day timeline
// ---------------------------------------------------------------------------

class _TimelineView extends StatefulWidget {
  const _TimelineView({required this.start, required this.dayCount});

  final DateTime start;
  final int dayCount;

  @override
  State<_TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<_TimelineView> {
  static const double _rowHeight = 56;
  static const double _gutter = 52;
  static const int _openHour = 7; // open scrolled to ~business hours

  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(
      // Nudge up so the top hour label isn't clipped by the header edge.
      initialScrollOffset: (_openHour * _rowHeight - 12).clamp(
        0.0,
        double.infinity,
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = daySpan(widget.start, widget.dayCount);
    final now = DateTime.now();
    final todayIndex = days.indexWhere((d) => isSameDay(d, now));
    final showNow = todayIndex != -1;
    final nowTop = (now.hour + now.minute / 60) * _rowHeight;

    return Column(
      children: [
        // The Day view's date is already in the AppBar title, so only the
        // multi-day (3-day) view needs per-column date headers.
        if (widget.dayCount > 1) ...[
          _TimelineHeader(days: days, gutter: _gutter),
          const Divider(height: 1),
        ],
        Expanded(
          // Use the timeline's own width (not the window's) so the column
          // dividers stay correct behind the NavigationRail on wide screens.
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  child: SizedBox(
                    height: 24 * _rowHeight,
                    child: Stack(
                      children: [
                        // hour hairlines + gutter labels (shared coordinate space)
                        for (var h = 1; h < 24; h++) ...[
                          Positioned(
                            top: h * _rowHeight,
                            left: _gutter,
                            right: 0,
                            child: Divider(
                              height: 1,
                              color: theme.dividerColor,
                            ),
                          ),
                          Positioned(
                            top: h * _rowHeight - 7,
                            left: 0,
                            width: _gutter - 8,
                            child: Text(
                              '${h.toString().padLeft(2, '0')}:00',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                        // column dividers
                        for (var c = 1; c < days.length; c++)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left:
                                _gutter +
                                (constraints.maxWidth - _gutter) /
                                    days.length *
                                    c,
                            child: VerticalDivider(
                              width: 1,
                              color: theme.dividerColor,
                            ),
                          ),
                        // static now-line (ink, weight not colour) when today is shown
                        if (showNow) ...[
                          Positioned(
                            top: nowTop - 0.75,
                            left: _gutter,
                            right: 0,
                            child: Container(
                              height: 1.5,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Positioned(
                            top: nowTop - 4,
                            left: _gutter - 4,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // A compact, contained chip so an empty timeline reads as
                // intentional — a solid background keeps it off the hour lines.
                IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'No events yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({required this.days, required this.gutter});

  final List<DateTime> days;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = dayOnly(DateTime.now());
    return Row(
      children: [
        SizedBox(width: gutter),
        for (final d in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    weekdayShort[d.weekday - 1],
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSameDay(d, today)
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                    ),
                    child: Text(
                      '${d.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSameDay(d, today)
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Agenda
// ---------------------------------------------------------------------------

class _AgendaView extends StatelessWidget {
  const _AgendaView();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.event_note_outlined,
      title: 'Nothing scheduled',
      message: 'Events you schedule will show up here, grouped by day.',
    );
  }
}
