-- =============================================================================
-- App Pixel - Esquema Relacional PostgreSQL para Supabase (Fase 2)
-- Ejecutar en Supabase SQL Editor
-- =============================================================================

create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- 1. clients (Clientes)
-- -----------------------------------------------------------------------------
create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  document_id text,
  phone text not null default '',
  vehicle_info text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_clients_updated_at on public.clients (updated_at);
create index if not exists idx_clients_deleted_at on public.clients (deleted_at);

-- -----------------------------------------------------------------------------
-- 2. materials (Inventario / Insumos)
-- -----------------------------------------------------------------------------
create table if not exists public.materials (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  unit text not null default 'm2' check (unit in ('m2', 'cm2', 'unit', 'linear_meter')),
  unit_cost double precision not null default 0,
  suggested_sale_price double precision not null default 0,
  default_waste_percentage double precision not null default 15.0,
  stock double precision not null default 0,
  min_stock double precision not null default 0,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_materials_updated_at on public.materials (updated_at);

-- -----------------------------------------------------------------------------
-- 3. orders (Pedidos - Cabecera)
-- -----------------------------------------------------------------------------
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  title text not null,
  status text not null default 'pending' check (status in ('pending', 'design', 'printing', 'ready', 'delivered')),
  design_approved boolean not null default false,
  print_stage text not null default 'none' check (print_stage in ('none', 'printing', 'cutting', 'laminating', 'done')),
  technical_notes text not null default '',
  source_file_path text,
  reference_images jsonb not null default '[]'::jsonb,
  time_invested_minutes integer not null default 0,
  active_timer_started_at timestamptz,
  timer_mode text not null default 'stopwatch' check (timer_mode in ('stopwatch', 'pomodoro')),
  pomodoro_sessions_completed integer not null default 0,
  deadline timestamptz not null,
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  pricing_mode text not null default 'manual' check (pricing_mode in ('manual', 'auto')),
  design_fee double precision not null default 0,
  total_price double precision not null default 0,
  amount_paid double precision not null default 0,
  balance_due double precision generated always as (total_price - amount_paid) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_orders_client_id on public.orders (client_id);
create index if not exists idx_orders_status on public.orders (status);
create index if not exists idx_orders_deadline on public.orders (deadline);
create index if not exists idx_orders_updated_at on public.orders (updated_at);

-- -----------------------------------------------------------------------------
-- 4. order_items (Ítems y Medidas del Pedido)
-- -----------------------------------------------------------------------------
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  material_id uuid references public.materials(id) on delete set null,
  description text not null,
  width_cm double precision not null default 0,
  height_cm double precision not null default 0,
  quantity integer not null default 1,
  waste_percentage double precision not null default 15.0,
  finishing_type text not null default 'none' check (finishing_type in ('none', 'matte_laminate', 'gloss_laminate', 'die_cut', 'reflective')),
  finishing_surcharge double precision not null default 0,
  calculated_price double precision not null default 0,
  deducted_from_stock boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_order_items_order_id on public.order_items (order_id);

-- -----------------------------------------------------------------------------
-- 5. order_payments (Historial de Abonos y Pagos de Pedidos)
-- -----------------------------------------------------------------------------
create table if not exists public.order_payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  amount double precision not null check (amount > 0),
  payment_method text not null default 'cash' check (payment_method in ('cash', 'nequi', 'daviplata', 'bancolombia', 'transfer', 'other')),
  notes text,
  payment_date timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_order_payments_order_id on public.order_payments (order_id);
create index if not exists idx_order_payments_date on public.order_payments (payment_date);

-- -----------------------------------------------------------------------------
-- 6. expenses (Gastos Diarios Unificados)
-- -----------------------------------------------------------------------------
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  amount double precision not null check (amount > 0),
  scope text not null default 'business' check (scope in ('business', 'personal')),
  payment_method text not null default 'cash' check (payment_method in ('cash', 'nequi', 'daviplata', 'bancolombia', 'transfer', 'other')),
  category text not null,
  subcategory text not null default '',
  description text not null default '',
  date timestamptz not null default now(),
  source text not null default 'app' check (source in ('app', 'telegram', 'whatsapp')),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_expenses_date on public.expenses (date);
create index if not exists idx_expenses_scope on public.expenses (scope);

-- -----------------------------------------------------------------------------
-- 7. work_logs (Control de Jornada Diaria)
-- -----------------------------------------------------------------------------
create table if not exists public.work_logs (
  id uuid primary key default gen_random_uuid(),
  date date not null unique,
  open_time timestamptz not null,
  close_time timestamptz,
  total_worked_minutes integer not null default 0,
  total_break_minutes integer not null default 0,
  notes text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_work_logs_date on public.work_logs (date);

-- -----------------------------------------------------------------------------
-- 8. work_breaks (Pausas y Salidas de la Jornada)
-- -----------------------------------------------------------------------------
create table if not exists public.work_breaks (
  id uuid primary key default gen_random_uuid(),
  work_log_id uuid not null references public.work_logs(id) on delete cascade,
  type text not null default 'lunch' check (type in ('lunch', 'personal_break', 'business_errand')),
  start_time timestamptz not null,
  end_time timestamptz,
  notes text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_work_breaks_work_log_id on public.work_breaks (work_log_id);

-- -----------------------------------------------------------------------------
-- Row Level Security (RLS) - Acceso restringido al usuario autenticado
-- -----------------------------------------------------------------------------
alter table public.clients enable row level security;
alter table public.materials enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_payments enable row level security;
alter table public.expenses enable row level security;
alter table public.work_logs enable row level security;
alter table public.work_breaks enable row level security;

create policy "auth_all_clients" on public.clients for all to authenticated using (true) with check (true);
create policy "auth_all_materials" on public.materials for all to authenticated using (true) with check (true);
create policy "auth_all_orders" on public.orders for all to authenticated using (true) with check (true);
create policy "auth_all_order_items" on public.order_items for all to authenticated using (true) with check (true);
create policy "auth_all_order_payments" on public.order_payments for all to authenticated using (true) with check (true);
create policy "auth_all_expenses" on public.expenses for all to authenticated using (true) with check (true);
create policy "auth_all_work_logs" on public.work_logs for all to authenticated using (true) with check (true);
create policy "auth_all_work_breaks" on public.work_breaks for all to authenticated using (true) with check (true);

-- -----------------------------------------------------------------------------
-- Supabase Storage Bucket para imágenes de referencia de pedidos
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('order-references', 'order-references', false)
on conflict (id) do nothing;

create policy "auth_order_references_all"
on storage.objects for all to authenticated
using (bucket_id = 'order-references')
with check (bucket_id = 'order-references');


-- Permisos de esquema y tablas para los roles authenticated y service_role (Edge Functions)
grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated, service_role;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated, service_role;
notify pgrst, 'reload schema';
