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
- **Tasks** — a lightweight to-do list: add a task, tick it complete, edit it, and archive
  ones you're done with. Completed and archived tasks tuck into their own sections so your
  active list stays clean, and nothing is ever hard-deleted.

Your data lives on a backend you host yourself (Postgres behind a REST layer), not a
third-party cloud.

## Development

The stack and workflow are documented in [`CLAUDE.md`](CLAUDE.md); current status and
the next slice live in [`docs/plan.md`](docs/plan.md).

Flutter 3.44.5 is installed at `~/flutter` (not on `PATH`):

- Web: `~/flutter/bin/flutter run -d chrome`
- Linux desktop: `~/flutter/bin/flutter run -d linux`
