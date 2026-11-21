-- =============================================================================
-- App Pixel - Migración 002: Subdivisiones (categoría / subcategoría) en Pedidos/Ventas
-- =============================================================================

alter table public.orders
  add column if not exists category text not null default 'Impresión Digital';

alter table public.orders
  add column if not exists subcategory text not null default '';

create index if not exists idx_orders_category on public.orders (category);

notify pgrst, 'reload schema';
