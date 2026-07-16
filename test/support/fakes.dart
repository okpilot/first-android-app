// Shared in-memory fake repositories for widget/unit tests, so tests never touch the
// network/Supabase. All six repos in lib/data/ are `abstract interface class`, so fakes
// `implements` them (never `extends` — there is no base to extend). Only the *reusable*
// fakes live here: a fake belongs in this file once its body is duplicated across ≥2 test
// files. Single-file specials (load-error / ordering / full-CRUD / gated fakes) stay local
// to the one test that needs them — see docs/decisions.md.
//
// Seeds are always positional so call sites read `FakeXRepo(seed)`; capture fields
// (`lastCreated`, `lastUpdated`, `archivedId`, `restoredId`) are public so asserting tests
// can read them.
import 'package:first_android_app/data/comments_repository.dart';
import 'package:first_android_app/data/contacts_repository.dart';
import 'package:first_android_app/data/event_types_repository.dart';
import 'package:first_android_app/data/events_repository.dart';
import 'package:first_android_app/data/task_categories_repository.dart';
import 'package:first_android_app/data/tasks_repository.dart';
import 'package:first_android_app/models/comment.dart';
import 'package:first_android_app/models/contact.dart';
import 'package:first_android_app/models/event.dart';
import 'package:first_android_app/models/event_type.dart';
import 'package:first_android_app/models/task.dart';
import 'package:first_android_app/models/task_category.dart';

/// fetchAll returns the seeded roster (empty by default); writes echo their argument.
class FakeContactsRepo implements ContactsRepository {
  FakeContactsRepo([this.contacts = const []]);
  final List<Contact> contacts;

  @override
  Future<List<Contact>> fetchAll() async => contacts;
  @override
  Future<Contact> create(Contact draft) async => draft;
  @override
  Future<Contact> update(Contact contact) async => contact;
  @override
  Future<void> softDelete(String id) async {}
}

/// fetchAll returns the seeded events (empty by default); writes echo. `create` also records
/// the draft in [lastCreated] so a form test can assert what it sent.
class FakeEventsRepo implements EventsRepository {
  FakeEventsRepo([this.events = const []]);
  final List<Event> events;
  Event? lastCreated;

  @override
  Future<List<Event>> fetchAll() async => events;
  @override
  Future<Event> create(Event draft) async {
    lastCreated = draft;
    return draft;
  }

  @override
  Future<Event> update(Event event) async => event;
  @override
  Future<void> softDelete(String id) async {}
}

/// fetchAll returns the seeded types (empty by default); writes echo.
class FakeEventTypesRepo implements EventTypesRepository {
  FakeEventTypesRepo([this.types = const []]);
  final List<EventType> types;

  @override
  Future<List<EventType>> fetchAll() async => types;
  @override
  Future<EventType> create(EventType draft) async => draft;
  @override
  Future<EventType> update(EventType type) async => type;
  @override
  Future<void> softDelete(String id) async {}
}

/// fetchAll returns the seeded categories (empty by default); writes echo.
class FakeTaskCategoriesRepo implements TaskCategoriesRepository {
  FakeTaskCategoriesRepo([this.categories = const []]);
  final List<TaskCategory> categories;

  @override
  Future<List<TaskCategory>> fetchAll() async => categories;
  @override
  Future<TaskCategory> create(TaskCategory draft) async => draft;
  @override
  Future<TaskCategory> update(TaskCategory category) async => category;
  @override
  Future<void> softDelete(String id) async {}
}

/// Inert tasks repo: no rows, writes echo, archive/restore return a throwaway Task. For tests
/// that thread a tasks repo through but never drive it. Use [StatefulTasksRepo] when a
/// complete-toggle or archive/restore must actually change state.
class FakeTasksRepo implements TasksRepository {
  @override
  Future<List<Task>> fetchAll() async => const [];
  @override
  Future<Task> create(Task draft) async => draft;
  @override
  Future<Task> update(Task task) async => task;
  @override
  Future<Task> archive(String id) async => const Task(id: '', title: 'x');
  @override
  Future<Task> restore(String id) async => const Task(id: '', title: 'x');
}

/// A stateful in-memory tasks repo: mutations persist, so a complete-toggle moves a row
/// between sections and archive/restore return a genuinely (un)archived Task (the views apply
/// the *returned* task in place). Records [lastUpdated] / [archivedId] / [restoredId] for
/// tests that assert what was written.
class StatefulTasksRepo implements TasksRepository {
  StatefulTasksRepo(List<Task> initial) : _tasks = [...initial];
  final List<Task> _tasks;
  Task? lastUpdated;
  String? archivedId;
  String? restoredId;

  @override
  Future<List<Task>> fetchAll() async => List.of(_tasks);

  @override
  Future<Task> create(Task draft) async {
    final t = Task(
      id: draft
          .id, // persist the client-supplied id (issue #9), like the real repo
      title: draft.title.trim(),
      notes: draft.notes,
      contacts: draft.contacts,
      importance: draft.importance,
      categories: draft.categories,
    );
    _tasks.add(t);
    return t;
  }

  @override
  Future<Task> update(Task task) async {
    lastUpdated = task;
    final i = _tasks.indexWhere((t) => t.id == task.id);
    if (i >= 0) _tasks[i] = task;
    return task;
  }

  @override
  Future<Task> archive(String id) async {
    archivedId = id;
    final i = _tasks.indexWhere((t) => t.id == id);
    final t = _tasks[i];
    // Archive changes only deleted_at server-side — notes, People, importance, categories (and
    // title/is_done) survive.
    _tasks[i] = Task(
      id: t.id,
      title: t.title,
      isDone: t.isDone,
      notes: t.notes,
      contacts: t.contacts,
      importance: t.importance,
      categories: t.categories,
      deletedAt: DateTime(2026, 7, 12),
    );
    return _tasks[i];
  }

  @override
  Future<Task> restore(String id) async {
    restoredId = id;
    final i = _tasks.indexWhere((t) => t.id == id);
    final t = _tasks[i];
    _tasks[i] = Task(
      id: t.id,
      title: t.title,
      isDone: t.isDone,
      notes: t.notes,
      contacts: t.contacts,
      importance: t.importance,
      categories: t.categories,
    );
    return _tasks[i];
  }
}

/// Every mutation throws — to exercise a screen's failure snackbars. fetchAll returns no rows.
class ThrowingTasksRepo implements TasksRepository {
  @override
  Future<List<Task>> fetchAll() async => const [];
  @override
  Future<Task> create(Task draft) => throw Exception('offline');
  @override
  Future<Task> update(Task task) => throw Exception('offline');
  @override
  Future<Task> archive(String id) => throw Exception('offline');
  @override
  Future<Task> restore(String id) => throw Exception('offline');
}

/// Inert comments repo: fetchFor returns nothing, add echoes the draft, edit/archive/unarchive
/// are inert. For tests that thread a comments repo through but never drive it. Use
/// [SeededCommentsRepo] when the composer/loaded-list path matters.
class FakeCommentsRepo implements CommentsRepository {
  @override
  Future<List<Comment>> fetchFor(String parentId) async => const [];
  @override
  Future<Comment> add(Comment draft) async => draft;
  @override
  Future<Comment> edit(Comment comment) async => comment;
  @override
  Future<Comment> archive(String id) async =>
      Comment.draft(parentId: '', body: '');
  @override
  Future<Comment> unarchive(String id) async =>
      Comment.draft(parentId: '', body: '');
}

/// A seedable comments repo: fetchFor returns the seeded comments filtered by parentId (newest
/// first by id), and add round-trips a saved Comment (id `c0`, `c1`, …) so the composer path
/// works. edit/archive/unarchive are inert (callers that need real edit/archive semantics keep
/// a local fake).
class SeededCommentsRepo implements CommentsRepository {
  SeededCommentsRepo([List<Comment>? seed]) : _items = seed ?? [];
  final List<Comment> _items;
  int _seq = 0;

  @override
  Future<List<Comment>> fetchFor(String parentId) async =>
      _items.where((c) => c.parentId == parentId).toList()
        ..sort((a, b) => b.id.compareTo(a.id));
  @override
  Future<Comment> add(Comment draft) async {
    final saved = Comment(
      id: 'c${_seq++}',
      parentId: draft.parentId,
      body: draft.body.trim(),
    );
    _items.add(saved);
    return saved;
  }

  @override
  Future<Comment> edit(Comment comment) async => comment;
  @override
  Future<Comment> archive(String id) async =>
      Comment.draft(parentId: '', body: '');
  @override
  Future<Comment> unarchive(String id) async =>
      Comment.draft(parentId: '', body: '');
}
