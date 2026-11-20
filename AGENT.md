# AGENT.md — Guía Rápida de Contexto para Agentes (App Pixel)

> **Propósito:** Evitar exploraciones repetitivas del repositorio. Este archivo resume el entorno local aislado, stack técnico, convenciones obligatorias y ubicación exacta de cada módulo.

---

## 1. Resumen del Proyecto
**App Pixel** es un sistema **Offline-First** multiplataforma (Android + Flutter Web PWA para iPad) para un taller unipersonal de impresión digital, publicidad y personalización de motos (calcomanías, protectores, vinilos).

* **Especificación fuente de verdad:** `arquitectura_y_plan_de_desarrollo.md`
* **Repositorio GitHub:** `https://github.com/ccamilor/pixel_app.git` (rama `main`)
* **Idioma:** Código e identificadores en **inglés**; UI, etiquetas y comentarios en **español**.

---

## 2. Entorno Virtual Local (`.toolchain/`) — MUY IMPORTANTE
Este proyecto **NO** depende de instalaciones globales de Flutter ni Git. Todo el toolchain está aislado en `.toolchain/` (ignorado en `.gitignore`):

* **Flutter SDK 3.50.0:** `.toolchain/flutter/bin/flutter.bat`
* **MinGit 2.56.1:** `.toolchain/git/cmd/git.exe`
* **Pub Cache local:** `.toolchain/pub-cache`

### Variables necesarias en cada comando PowerShell:
```powershell
$env:PATH = "D:\Workspace\dev\App Pixel\.toolchain\flutter\bin;D:\Workspace\dev\App Pixel\.toolchain\git\cmd;$env:PATH"
$env:PUB_CACHE = "D:\Workspace\dev\App Pixel\.toolchain\pub-cache"
$env:APPDATA = "D:\Workspace\dev\App Pixel\.toolchain\appdata"
$env:LOCALAPPDATA = "D:\Workspace\dev\App Pixel\.toolchain\localappdata"
```
*(Nota: Redirigir `APPDATA` y `LOCALAPPDATA` evita errores de permisos del sandbox con `.dartServer` y `unified_analytics`.)*

---

## 3. Stack Tecnológico y Reglas Técnicas Críticas
1. **Flutter 3.50.0 + `material_ui`:**
   * En Flutter 3.50, `package:flutter/material.dart` está deprecado en favor de **`package:material_ui/material_ui.dart`**. Usar siempre `material_ui.dart` para mantener 0 warnings en `flutter analyze`.
2. **Tema OLED Negro Puro:**
   * Fondo `#000000`, superficies `#0A0A0A` / `#111111`, bordes `#1E293B`, azules `#0D47A1` / `#1565C0`, cianes `#00E5FF` / `#00B8D4`. Definido en `lib/core/constants/app_colors.dart` y `lib/core/theme/app_theme.dart`.
3. **Navegación Adaptativa (`ResponsiveShell`):**
   * `< 600px` (Android): `NavigationBar` inferior.
   * `>= 600px` (iPad / Web): `NavigationRail` lateral.
   * Router: `go_router` (`StatefulShellRoute.indexedStack`) en `lib/core/layout/app_router.dart`.
4. **Estado:** **Riverpod 3.5** (`flutter_riverpod`).
5. **Base de Datos Offline-First:**
   * **Drift 2.35** (SQLite nativo en Android, SQLite WASM en Web usando `web/sqlite3.wasm` y `web/drift_worker.js`).
   * **SyncEngine:** Cola transaccional FIFO (`sync_queue`) en `lib/core/database/sync_engine.dart`. Funciona 100% offline aunque Supabase no esté configurado (`--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`).
   * **Regenerar Drift tras cambiar tablas:** `dart run build_runner build`
6. **Backend y Bots (Supabase):**
   * SQL + RLS + Storage bucket `order-references`: `supabase/migrations/001_initial_schema.sql`
   * Edge Functions (Deno/TS): `supabase/functions/` (`_shared/hybrid_parser.ts`, `telegram-webhook/`, `whatsapp-webhook/`, `proactive-alerts/`).

---

## 4. Mapa de Archivos Clave (`lib/`)
```text
lib/
├── main.dart                                 # Arranque + SupabaseConfig + SyncEngine
├── core/
│   ├── constants/
│   │   ├── app_colors.dart                   # Paleta OLED + escala Heatmap (0..4)
│   │   ├── app_enums.dart                    # OrderStatus, PrintStage, TimerMode, PaymentMethod, WorkBreakType...
│   │   └── app_routes.dart                   # /dashboard, /orders, /finance, /clients-inventory
│   ├── theme/app_theme.dart                  # ThemeData OLED negro puro + Inter
│   ├── layout/
│   │   ├── app_router.dart                   # GoRouter con 4 ramas StatefulShellBranch
│   │   └── responsive_shell.dart             # NavigationBar (móvil) vs NavigationRail (iPad/Web)
│   ├── database/
│   │   ├── app_tables.dart                   # 8 tablas de dominio + SyncQueue
│   │   ├── app_database.dart (.g.dart)       # AppDatabase (SQLite + Web WASM)
│   │   └── sync_engine.dart                  # SyncEngine + appDatabaseProvider + pendingSyncCountProvider
│   ├── network/
│   │   ├── connectivity_service.dart         # connectivity_plus
│   │   └── supabase_config.dart              # Inicialización opcional por --dart-define
│   └── utils/
│       ├── formatters.dart                   # Moneda COP y horas/minutos
│       ├── print_calculator.dart             # Calculadora m², merma %, acabados y diseño
│       └── whatsapp_launcher.dart            # Deep-link wa.me + plantillas por estado de pedido
└── features/
    ├── dashboard/presentation/
    │   ├── pages/dashboard_page.dart         # Control de jornada + arqueo rápido + Heatmap
    │   └── widgets/github_activity_heatmap.dart
    ├── orders/
    │   ├── domain/entities/order_entity.dart
    │   ├── data/repositories/orders_repository.dart
    │   └── presentation/
    │       ├── pages/orders_kanban_page.dart # Kanban drag&drop + calculadora + abonos + WhatsApp
    │       └── widgets/order_timer_widget.dart # Cronómetro libre + Modo Pomodoro (25/5/15m)
    ├── finance/
    │   ├── domain/entities/expense_entity.dart
    │   ├── data/repositories/finance_repository.dart # Arqueo Efectivo vs Digital + gastos
    │   └── presentation/pages/finance_page.dart
    ├── clients/
    │   ├── domain/entities/client_entity.dart
    │   ├── data/repositories/client_repository.dart
    │   └── presentation/pages/clients_inventory_page.dart # Tabs Clientes + Inventario
    ├── inventory/
    │   ├── domain/entities/material_entity.dart
    │   └── data/repositories/inventory_repository.dart # Stock + alertas min_stock
    └── time_tracking/
        ├── domain/entities/work_log_entity.dart
        └── data/repositories/time_tracking_repository.dart # Apertura, pausas múltiples, cierre
```

---

## 5. Comandos de Verificación y Ejecución
* **Análisis estático (debe quedar en 0 issues):**
  `flutter analyze --no-pub`
* **Tests (9 tests en `test/`):**
  `flutter test --no-pub`
* **Ejecutar en Web (Chrome / navegador local):**
  `flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1`

---

## 6. Reglas de GitHub (Protocolo Obligatorio)
* Usar **Conventional Commits** (`feat:`, `fix:`, `refactor:`, `docs:`, `style:`).
* Al finalizar cada funcionalidad o cambio significativo, **preguntar explícitamente al usuario** si desea hacer `git add`, `git commit` y `git push` antes de continuar.
