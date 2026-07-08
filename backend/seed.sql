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
