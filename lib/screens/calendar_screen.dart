import 'package:flutter/material.dart';

import '../data/contacts_repository.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import '../theme.dart';
import '../util/calendar.dart';
import '../util/format.dart';
import '../widgets/empty_state.dart';
import '../widgets/initials_avatar.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

/// The Calendar destination: a period header + a view switcher (Month · 3-day · Day ·
/// Agenda) over four data-driven views. Loads events once (cached future, like the
/// Contacts list) and reloads after any create/edit/delete.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.eventsRepository,
    required this.contactsRepository,
    this.initialDate,
  });

  final EventsRepository eventsRepository;
  final ContactsRepository contactsRepository;

  /// Defaults to today; injectable so widget tests are deterministic.
  final DateTime? initialDate;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['Month', '3-day', 'Day', 'Agenda'];

  late final TabController _tab;
  late DateTime _focused;

  // Cache the fetch future in a field — this screen rebuilds on every tab/step/select
  // setState, so calling fetchAll() in build() would refetch on every rebuild.
  late Future<List<Event>> _future;
  List<Event>? _lastData;

  @override
  void initState() {
    super.initState();
    _focused = dayOnly(widget.initialDate ?? DateTime.now());
    _tab = TabController(length: _tabs.length, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final future = widget.eventsRepository.fetchAll();
    setState(() {
      _future = future;
    });
    try {
      _lastData = await future;
      if (mounted) setState(() {});
    } catch (_) {
      // First load: surfaced by the FutureBuilder's error branch. But on a reload
      // with data already cached, the FutureBuilder keeps showing the stale list —
      // so a failed refresh after create/edit/delete would otherwise be invisible.
      if (mounted && _lastData != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't refresh events.")),
        );
      }
    }
  }

  void _step(int dir) {
    setState(() {
      switch (_tab.index) {
        case 0:
          _focused = DateTime(_focused.year, _focused.month + dir, 1);
        case 1:
          _focused = DateTime(
            _focused.year,
            _focused.month,
            _focused.day + 3 * dir,
          );
        case 2:
          _focused = DateTime(
            _focused.year,
            _focused.month,
            _focused.day + dir,
          );
        default:
          _focused = DateTime(
            _focused.year,
            _focused.month,
            _focused.day + 7 * dir,
          );
      }
    });
  }

  void _goToday() => setState(() => _focused = dayOnly(DateTime.now()));

  Future<void> _openForm({
    Event? existing,
    DateTime? initialDate,
    int? initialHour,
  }) async {
    final saved = await Navigator.of(context).push<Event>(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(
          eventsRepository: widget.eventsRepository,
          contactsRepository: widget.contactsRepository,
          existing: existing,
          initialDate: initialDate,
          initialHour: initialHour,
        ),
      ),
    );
    if (saved != null && mounted) _load();
  }

  Future<void> _openDetail(Event event) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventsRepository: widget.eventsRepository,
          contactsRepository: widget.contactsRepository,
          event: event,
        ),
      ),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final showPeriodNav = _tabs[_tab.index] != 'Agenda';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                periodLabel(_tab.index, _focused),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showPeriodNav) ...[
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
          ],
        ),
        actions: [
          if (showPeriodNav) ...[
            TextButton(onPressed: _goToday, child: const Text('Today')),
            const SizedBox(width: 8),
          ],
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [for (final t in _tabs) Tab(text: t)],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(initialDate: _focused),
        icon: const Icon(Icons.add),
        label: const Text('New event'),
      ),
      body: FutureBuilder<List<Event>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _lastData == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && _lastData == null) {
            return _ErrorState(onRetry: _load);
          }
          final events = snapshot.data ?? _lastData ?? const <Event>[];
          final byDay = _groupByDay(events);
          return TabBarView(
            controller: _tab,
            children: [
              _MonthView(
                month: _focused,
                selected: _focused,
                byDay: byDay,
                onSelect: (d) => setState(() => _focused = d),
                onOpenEvent: _openDetail,
              ),
              _TimelineView(
                start: _focused,
                dayCount: 3,
                byDay: byDay,
                onOpenEvent: _openDetail,
                onAddAt: (d, h) => _openForm(initialDate: d, initialHour: h),
              ),
              _TimelineView(
                start: _focused,
                dayCount: 1,
                byDay: byDay,
                onOpenEvent: _openDetail,
                onAddAt: (d, h) => _openForm(initialDate: d, initialHour: h),
              ),
              _AgendaView(events: events, onOpenEvent: _openDetail),
            ],
          );
        },
      ),
    );
  }
}

// --- grouping -------------------------------------------------------------

/// Events keyed by `yyyy-MM-dd`. Input is already globally sorted (date, then all-day
/// first, then start time), so each day's list stays in display order.
Map<String, List<Event>> _groupByDay(List<Event> events) {
  final m = <String, List<Event>>{};
  for (final e in events) {
    (m[ymd(e.date)] ??= []).add(e);
  }
  return m;
}

List<Event> _dayEvents(Map<String, List<Event>> byDay, DateTime d) =>
    byDay[ymd(d)] ?? const [];

// ---------------------------------------------------------------------------
// Month
// ---------------------------------------------------------------------------

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.selected,
    required this.byDay,
    required this.onSelect,
    required this.onOpenEvent,
  });

  final DateTime month;
  final DateTime selected;
  final Map<String, List<Event>> byDay;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<Event> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = monthGrid(month);
    final today = dayOnly(DateTime.now());

    return ListView(
      children: [
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
                    eventCount: _dayEvents(byDay, days[row * 7 + col]).length,
                    onTap: () => onSelect(days[row * 7 + col]),
                  ),
                ),
            ],
          ),
        _SelectedDayPanel(
          day: selected,
          isToday: isSameDay(selected, today),
          events: _dayEvents(byDay, selected),
          onOpenEvent: onOpenEvent,
        ),
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
    required this.eventCount,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final bool lastCol;
  final int eventCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final Color numberColor = isToday
        ? scheme.onPrimary
        : (inMonth ? scheme.onSurface : scheme.onSurfaceVariant);

    final countLabel = eventCount == 0
        ? 'no events'
        : (eventCount == 1 ? '1 event' : '$eventCount events');

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${dayLabel(day)}${isToday ? ', today' : ''}, $countLabel',
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
              right: lastCol
                  ? BorderSide.none
                  : BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
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
              const SizedBox(height: 3),
              // Event-density dots (mono; the panel below lists the actual events).
              SizedBox(
                height: 5,
                child: eventCount == 0
                    ? null
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (
                            var i = 0;
                            i < (eventCount > 3 ? 3 : eventCount);
                            i++
                          )
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: inMonth
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDayPanel extends StatelessWidget {
  const _SelectedDayPanel({
    required this.day,
    required this.isToday,
    required this.events,
    required this.onOpenEvent,
  });

  final DateTime day;
  final bool isToday;
  final List<Event> events;
  final ValueChanged<Event> onOpenEvent;

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
          if (events.isEmpty)
            Text(
              'No events',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final e in events)
              _EventRow(event: e, onTap: () => onOpenEvent(e)),
        ],
      ),
    );
  }
}

/// A compact list row for an event (used in the month panel): time · title · attendees.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(
                event.allDay ? 'All\nday' : hhmm(event.startMin!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: theme.textTheme.bodyLarge),
                  if (event.attendees.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _AttendeeStack(attendees: event.attendees),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day / 3-day timeline
// ---------------------------------------------------------------------------

typedef _AddAt = void Function(DateTime day, int hour);

class _TimelineView extends StatefulWidget {
  const _TimelineView({
    required this.start,
    required this.dayCount,
    required this.byDay,
    required this.onOpenEvent,
    required this.onAddAt,
  });

  final DateTime start;
  final int dayCount;
  final Map<String, List<Event>> byDay;
  final ValueChanged<Event> onOpenEvent;
  final _AddAt onAddAt;

  @override
  State<_TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<_TimelineView> {
  static const double _rowHeight = 56;
  static const double _gutter = 52;
  static const double _minBlock = 30; // keep a tap target even for short events
  static const int _openHour = 7;

  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(
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

    final allDayByCol = [
      for (final d in days)
        _dayEvents(widget.byDay, d).where((e) => e.allDay).toList(),
    ];
    final hasAllDay = allDayByCol.any((l) => l.isNotEmpty);
    final anyEvents = days.any((d) => _dayEvents(widget.byDay, d).isNotEmpty);

    return Column(
      children: [
        if (widget.dayCount > 1) ...[
          _TimelineHeader(days: days, gutter: _gutter),
          const Divider(height: 1),
        ],
        // Persistent-ish all-day band: animates open/closed so the hour grid's origin
        // doesn't hard-jump between days as you page.
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.topCenter,
          child: hasAllDay
              ? _AllDayBand(
                  columns: allDayByCol,
                  gutter: _gutter,
                  onOpenEvent: widget.onOpenEvent,
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colWidth = (constraints.maxWidth - _gutter) / days.length;
              return Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scroll,
                    child: SizedBox(
                      height: 24 * _rowHeight,
                      width: constraints.maxWidth,
                      child: Stack(
                        children: [
                          // Tap an empty area to add an event at that hour (behind
                          // everything; blocks on top capture their own taps).
                          Positioned.fill(
                            left: _gutter,
                            child: _AddSurface(
                              days: days,
                              colWidth: colWidth,
                              rowHeight: _rowHeight,
                              onAddAt: widget.onAddAt,
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _GridDecoration(
                                days: days,
                                gutter: _gutter,
                                colWidth: colWidth,
                                rowHeight: _rowHeight,
                              ),
                            ),
                          ),
                          // Event blocks, lane-split so overlaps don't occlude.
                          for (var c = 0; c < days.length; c++)
                            ..._blocksForColumn(
                              theme,
                              _dayEvents(
                                widget.byDay,
                                days[c],
                              ).where((e) => !e.allDay).toList(),
                              colLeft: _gutter + c * colWidth,
                              colWidth: colWidth,
                            ),
                          if (todayIndex >= 0)
                            _NowLine(
                              left: _gutter + todayIndex * colWidth,
                              width: colWidth,
                              top: (now.hour + now.minute / 60) * _rowHeight,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!anyEvents) IgnorePointer(child: _EmptyTimelineHint()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _blocksForColumn(
    ThemeData theme,
    List<Event> timed, {
    required double colLeft,
    required double colWidth,
  }) {
    final placed = _packDay(timed);
    return [
      for (final p in placed)
        Positioned(
          top: p.event.startMin! / 60 * _rowHeight,
          height: (((p.event.endMin! - p.event.startMin!) / 60) * _rowHeight)
              .clamp(_minBlock, 24 * _rowHeight),
          left: colLeft + p.lane * (colWidth / p.lanes) + 2,
          width: colWidth / p.lanes - 3,
          child: _EventBlock(
            event: p.event,
            onTap: () => widget.onOpenEvent(p.event),
          ),
        ),
    ];
  }
}

/// A timed event laid out in a lane: [lane] of [lanes] side-by-side slots. Overlapping
/// events share lanes so none is fully hidden behind another.
class _Placed {
  const _Placed(this.event, this.lane, this.lanes);
  final Event event;
  final int lane;
  final int lanes;
}

/// Greedy interval partitioning per overlap cluster: walk the day's timed events (already
/// sorted by start), gather transitively-overlapping runs into clusters, and assign each
/// event the first free lane within its cluster.
List<_Placed> _packDay(List<Event> timed) {
  final out = <_Placed>[];
  var i = 0;
  while (i < timed.length) {
    var clusterEnd = timed[i].endMin!;
    final cluster = <Event>[timed[i]];
    var j = i + 1;
    while (j < timed.length && timed[j].startMin! < clusterEnd) {
      cluster.add(timed[j]);
      if (timed[j].endMin! > clusterEnd) clusterEnd = timed[j].endMin!;
      j++;
    }
    final laneEnd = <int>[]; // running end-time per lane
    final laneOf = <int, int>{}; // cluster index -> lane
    for (var k = 0; k < cluster.length; k++) {
      final e = cluster[k];
      var lane = -1;
      for (var l = 0; l < laneEnd.length; l++) {
        if (laneEnd[l] <= e.startMin!) {
          lane = l;
          break;
        }
      }
      if (lane == -1) {
        lane = laneEnd.length;
        laneEnd.add(0);
      }
      laneEnd[lane] = e.endMin!;
      laneOf[k] = lane;
    }
    final lanes = laneEnd.length;
    for (var k = 0; k < cluster.length; k++) {
      out.add(_Placed(cluster[k], laneOf[k]!, lanes));
    }
    i = j;
  }
  return out;
}

class _GridDecoration extends StatelessWidget {
  const _GridDecoration({
    required this.days,
    required this.gutter,
    required this.colWidth,
    required this.rowHeight,
  });

  final List<DateTime> days;
  final double gutter;
  final double colWidth;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        for (var h = 1; h < 24; h++) ...[
          Positioned(
            top: h * rowHeight,
            left: gutter,
            right: 0,
            child: Divider(height: 1, color: theme.dividerColor),
          ),
          Positioned(
            top: h * rowHeight - 7,
            left: 0,
            width: gutter - 8,
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
        for (var c = 1; c < days.length; c++)
          Positioned(
            top: 0,
            bottom: 0,
            left: gutter + colWidth * c,
            child: VerticalDivider(width: 1, color: theme.dividerColor),
          ),
      ],
    );
  }
}

/// Handles taps on empty grid area (add an event) and a desktop hover affordance.
class _AddSurface extends StatefulWidget {
  const _AddSurface({
    required this.days,
    required this.colWidth,
    required this.rowHeight,
    required this.onAddAt,
  });

  final List<DateTime> days;
  final double colWidth;
  final double rowHeight;
  final _AddAt onAddAt;

  @override
  State<_AddSurface> createState() => _AddSurfaceState();
}

class _AddSurfaceState extends State<_AddSurface> {
  ({int col, int hour})? _hover;

  (int, int) _cell(Offset local) {
    final col = (local.dx / widget.colWidth).floor().clamp(
      0,
      widget.days.length - 1,
    );
    final hour = (local.dy / widget.rowHeight).floor().clamp(0, 23);
    return (col, hour);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onHover: (e) {
        final (col, hour) = _cell(e.localPosition);
        if (_hover?.col != col || _hover?.hour != hour) {
          setState(() => _hover = (col: col, hour: hour));
        }
      },
      onExit: (_) => setState(() => _hover = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final (col, hour) = _cell(d.localPosition);
          widget.onAddAt(widget.days[col], hour);
        },
        child: Stack(
          children: [
            if (_hover != null)
              Positioned(
                top: _hover!.hour * widget.rowHeight,
                height: widget.rowHeight,
                left: _hover!.col * widget.colWidth,
                width: widget.colWidth,
                child: Container(
                  alignment: Alignment.center,
                  color: scheme.onSurface.withValues(alpha: 0.04),
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({
    required this.left,
    required this.width,
    required this.top,
    required this.color,
  });

  final double left;
  final double width;
  final double top;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      width: width,
      top: top - 0.75,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            Expanded(child: Container(height: 1.5, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EventBlock extends StatelessWidget {
  const _EventBlock({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<EventBlockStyle>()!;
    final timeLabel = '${hhmm(event.startMin!)} – ${hhmm(event.endMin!)}';
    final attendeeLabel = event.attendees.isEmpty
        ? ''
        : ', ${event.attendees.length} attendee${event.attendees.length == 1 ? '' : 's'}';

    return Semantics(
      button: true,
      label: '${event.title}, $timeLabel$attendeeLabel',
      child: LayoutBuilder(
        builder: (context, c) {
          final tall = c.maxHeight >= 44;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              // Uniform border (borderRadius forbids a non-uniform one) with the ink
              // rail drawn as a flush left strip.
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: style.fill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: style.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 2.5, color: style.rail),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            if (tall)
                              Text(
                                timeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AllDayBand extends StatelessWidget {
  const _AllDayBand({
    required this.columns,
    required this.gutter,
    required this.onOpenEvent,
  });

  final List<List<Event>> columns;
  final double gutter;
  final ValueChanged<Event> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<EventBlockStyle>()!;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: gutter,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 10),
              child: Text(
                'all-day',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          for (final col in columns)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Column(
                  children: [
                    for (final e in col)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => onOpenEvent(e),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: double.infinity,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: style.fill,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: style.border),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(width: 2.5, color: style.rail),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      child: Text(
                                        e.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyTimelineHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outlineVariant),
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
  const _AgendaView({required this.events, required this.onOpenEvent});

  final List<Event> events;
  final ValueChanged<Event> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = dayOnly(DateTime.now());
    final upcoming = events.where((e) => !e.date.isBefore(today)).toList();

    if (upcoming.isEmpty) {
      return const EmptyState(
        icon: Icons.event_note_outlined,
        title: 'Nothing scheduled',
        message: 'Events you schedule will show up here, grouped by day.',
      );
    }

    // Group the (already-sorted) upcoming events by day, preserving order.
    final groups = <String, List<Event>>{};
    for (final e in upcoming) {
      (groups[ymd(e.date)] ??= []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              '${dayLabel(entry.value.first.date)}'
                      '${isSameDay(entry.value.first.date, today) ? ' · Today' : ''}'
                  .toUpperCase(),
              style: theme.textTheme.labelMedium,
            ),
          ),
          for (final e in entry.value)
            _EventRow(event: e, onTap: () => onOpenEvent(e)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

/// Overlapping attendee faces (ringed so they separate in mono), capped with "+N".
class _AttendeeStack extends StatelessWidget {
  const _AttendeeStack({required this.attendees});

  final List attendees; // List<Contact>

  static const _max = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = attendees.take(_max).toList();
    final extra = attendees.length - shown.length;
    return SizedBox(
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 20.0,
              child: InitialsAvatar(
                name: shown[i].name,
                radius: 13,
                ring: true,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * 20.0,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.secondaryContainer,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+$extra',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: "Couldn't load events",
      message: 'Check that the backend is running, then try again.',
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    );
  }
}
