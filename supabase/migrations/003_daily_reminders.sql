-- =============================================================================
-- App Pixel - Migración 003: Recordatorios Personales del Día (daily_reminders)
-- =============================================================================

create table if not exists public.daily_reminders (
  id uuid primary key default gen_random_uuid(),
  date_key date not null,
  title text not null,
  is_done boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_daily_reminders_date on public.daily_reminders (date_key);

alter table public.daily_reminders enable row level security;

drop policy if exists "auth_all_daily_reminders" on public.daily_reminders;
create policy "auth_all_daily_reminders"
on public.daily_reminders for all to authenticated
using (true) with check (true);

grant select, insert, update, delete on public.daily_reminders to authenticated, service_role;

notify pgrst, 'reload schema';
