# First App — a light CRM

A small contacts-and-calendar CRM built with Flutter (Android · Web · Linux desktop)
on a self-hosted, Supabase-shaped backend. It's a learning project: the CRM is a
disposable vehicle for learning app development end to end.

## Features

- **Contacts** — keep the people you work with in one place: create, edit, remove,
  and search them. Each contact holds a name plus optional date of birth, email,
  phone, company, and free-text remarks.
- **Calendar** — see your schedule across month, multi-day, day, and agenda views.
  The week starts on Monday.
- **Events** — put events on a day, either all-day or with a start and end time
  (24-hour), and optionally add a location, notes, and attendees drawn from your
  contacts.
- **Event types** — define your own colour-coded categories. The colour is used as
  data throughout the calendar, so you can tell events apart at a glance.
- **Event comments** — attach notes and decisions to an event. Archive old comments to
  keep them but hide them by default; unarchive to show them again.
- **Task categories** — define and assign your own colour-coded categories for tasks, separate from
  event types. Manage them under Settings; choose multiple categories per task on the task form,
  and see them as coloured labels on the task list and detail.
- **Tasks** — a lightweight to-do list: add a task, then tap it to see its details (title,
  status, optional notes, dates, and linked People). **Edit** to change it; **Complete** (or **Reopen**) toggles
  done status, and **Archive** (or **Restore**) tidies away finished tasks. Completed and
  archived tasks tuck into their own sections so your active list stays clean, and nothing is
  ever hard-deleted.
- **Task People** — link contacts to a task so you know who's involved. Add or remove people on
  the task form; see them listed on the detail.
- **Task comments** — attach notes to a task, just like on events. Archive old comments to
  keep them but hide them by default; unarchive to show them again. On archived tasks, the log
  is read-only (frozen history).
- **Task importance** — mark each task with a priority level: none, ! (important), !! (very important),
  or !!! (urgent). Active tasks sort highest-importance first so you see the most pressing work at
  the top of your list.
- **Desktop & wide screens** — on a wide window the app lays itself out for a mouse: a
  labelled sidebar instead of the phone's bottom bar, and a two-pane master-detail for
  Contacts and Tasks (the list on the left, the detail or editor on the right) instead of
  tapping through to a separate screen. Narrow/phone keeps the familiar tap-through flow.

Your data lives on a backend you host yourself (Postgres behind a REST layer), not a
third-party cloud.

## Development

The stack and workflow are documented in [`CLAUDE.md`](CLAUDE.md); current status and
the next slice live in [`docs/plan.md`](docs/plan.md).

Flutter 3.44.5 is installed at `~/flutter` (not on `PATH`):

- Web: `~/flutter/bin/flutter run -d chrome`
- Linux desktop: `~/flutter/bin/flutter run -d linux`
