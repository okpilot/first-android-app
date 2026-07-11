-- Dev-only seed data. Runs after migrations on a fresh volume. NOT a migration —
-- do not rely on this on homebase. Idempotent-ish: only inserts if the table is empty.
insert into public.contacts (name, dob, email, phone, company, remarks)
select * from (values
  ('Ada Lovelace',     '1815-12-10'::date, 'ada@analytical.engine', '+44 20 7946 0001', 'Analytical Engine Co.', 'First programmer; notes on Bernoulli numbers.'),
  ('Alan Turing',      '1912-06-23'::date, 'alan@bletchley.uk',     '+44 20 7946 0011', 'Bletchley Park',        'Codebreaker; the halting problem.'),
  ('Grace Hopper',     '1906-12-09'::date, 'grace@navy.mil',        '+1 202 555 0104',  'US Navy',               'Coined "debugging"; COBOL.'),
  ('Katherine Johnson','1918-08-26'::date, 'katherine@nasa.gov',    '+1 202 555 0148',  'NASA',                  'Orbital mechanics for Mercury & Apollo.')
) as v(name, dob, email, phone, company, remarks)
where not exists (select 1 from public.contacts);

-- Dev-only seed events. Only if there are no events yet. Dates are relative to
-- current_date so the seed always lands near "today" across the four calendar views.
-- (Seed writes go direct as the superuser; the app uses the create/update RPCs.)
with ins as (
  insert into public.events (title, event_date, all_day, start_time, end_time, location, notes)
  select * from (values
    ('Coffee with Ada',   current_date,     false, time '09:00', time '09:45', 'Blue Bottle, 2nd St',    'Catch up before the Q3 push.'),
    ('Onboarding — NASA', current_date,     false, time '14:00', time '15:00', 'https://zoom.us/j/8841', 'Walk through setup + the first data import.'),
    ('Q3 kickoff',        current_date,     true,  null,         null,         null,                     null),
    ('Pipeline review',   current_date - 1, false, time '11:00', time '12:00', null,                     null),
    ('Contract signing',  current_date + 1, false, time '16:00', time '16:30', 'Office — Room 2',        null),
    ('Product demo',      current_date + 2, false, time '10:00', time '11:00', 'https://zoom.us/j/2210', null)
  ) as v(title, event_date, all_day, start_time, end_time, location, notes)
  where not exists (select 1 from public.events)
  returning id, title
)
insert into public.event_attendees (event_id, contact_id)
select ins.id, c.id
from ins
join public.contacts c on (
     (ins.title = 'Coffee with Ada'   and c.name = 'Ada Lovelace')
  or (ins.title = 'Onboarding — NASA' and c.name in ('Katherine Johnson', 'Grace Hopper'))
  or (ins.title = 'Q3 kickoff'        and c.name in ('Alan Turing', 'Grace Hopper'))
  or (ins.title = 'Pipeline review'   and c.name = 'Katherine Johnson')
  or (ins.title = 'Contract signing'  and c.name = 'Alan Turing')
  or (ins.title = 'Product demo'      and c.name = 'Ada Lovelace')
);

-- Dev-only seed comments. Only if there are no comments yet. One is pre-archived so the
-- "Show archived" toggle has something to reveal on a fresh volume.
insert into public.event_comments (event_id, body, deleted_at)
select e.id, v.body, v.deleted_at
from public.events e
join (values
  ('Onboarding — NASA', 'Sent the agenda round — Grace is covering the data import.', null::timestamptz),
  ('Onboarding — NASA', 'Need final headcount from the team before this.',            null::timestamptz),
  ('Onboarding — NASA', 'Original slot was 15:00; rescheduled to the afternoon.',      now())
) as v(title, body, deleted_at) on e.title = v.title
where not exists (select 1 from public.event_comments);
