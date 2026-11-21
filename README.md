<p align="center">
  <img src="assets/images/pixel_logo.png" alt="Pixel App Logo" width="140" />
</p>

<h1 align="center">Pixel App</h1>

<p align="center">
  <strong>Sistema de Gestión Integral Offline-First para Impresión Digital, Publicidad y Personalización de Motos</strong><br/>
  <em>Offline-First Management Suite for Digital Printing, Advertising &amp; Motorcycle Customization</em>
</p>

<p align="center">
  <a href="https://ccamilor.github.io/pixel_app/"><strong>🌐 Abrir Web App (PWA)</strong></a> •
  <a href="#español">🇪🇸 Español</a> •
  <a href="#english">🇺🇸 English</a>
</p>

---

<a id="español"></a>
## 🇪🇸 Español

### Descripción General
**Pixel App** es una aplicación multiplataforma (**Android** y **Web PWA para iPad/iPhone/PC**) diseñada bajo arquitectura **Offline-First** y tema **OLED Negro Puro (`#000000`)** con acentos azul profundo y cian (`#00E5FF`). Permite gestionar la operación diaria, finanzas reales por medio de pago, producción Kanban, jornada laboral y automatizaciones por chat (Telegram / WhatsApp) desde un solo lugar.

### Funcionalidades Principales
* **📊 Dashboard Principal Interactivo:**
  * Control de **Jornada Laboral** con apertura, múltiples pausas (`Almuerzo`, `Descanso personal` y `Diligencia del negocio`) y cierre con cálculo neto de horas.
  * Accesos rápidos para **`Nueva Venta`** y **`Agregar Gasto`** directo desde la pantalla principal.
  * Cuadrícula interactiva **3×2** de métricas en vivo: *Ventas del Día*, *Pedidos Activos*, *Por Cobrar* (fila superior) y *Dinero Total*, *Cuenta Digital*, *Efectivo* (fila inferior).
  * Lista de **Ventas del Día** editable en un toque.
  * **Mapa de Calor estilo GitHub (12 semanas)** con días (`Lun–Dom`), meses, resumen de los últimos 7 días y selector de métrica (*Combinado*, *Solo Horas*, *Solo Entregas*).
* **🧩 Tablero de Pedidos (Kanban Adaptativo):**
  * Flujo completo: `Pendiente` → `En Diseño` (con aprobación) → `En Impresión` (`Imprimiendo`, `Cortando`, `Laminando`, `Finalizado`) → `Listo para Entrega` → `Entregado`.
  * **Calculadora Avanzada $\text{m}^2$:** ancho × alto × cantidad, porcentaje de merma, recargo por acabados, cobro opcional de diseño y descuento automático del inventario.
  * **Categorías y Subdivisiones personalizables** + edición y eliminación completa después de crear.
  * **Cronómetro en vivo + Modo Pomodoro (25/5/15 min)** por pedido.
  * Botón directo a **WhatsApp** del cliente con plantillas automáticas según el estado y saldo pendiente.
* **💰 Módulo Financiero y Arqueo Real:**
  * Caja unificada (*Negocio* + *Personal*) con categorías y subdivisiones personalizables, edición completa e historial de abonos (`order_payments`).
  * Arqueo separado entre **Efectivo Físico** y **Cuentas Digitales** (`Nequi`, `Daviplata`, `Bancolombia`, `Transferencia`).
* **👥 Clientes e Inventario:**
  * Directorio de clientes con datos de moto/vehículo y botón de WhatsApp directo.
  * Catálogo de materiales con costo base, precio sugerido por $\text{m}^2$, merma por defecto y alertas automáticas de **Stock Bajo (`min_stock`)**.
* **🕒 Panel en Vivo (Barra Lateral / Barra Móvil):**
  * **Recordatorios Personales solo del día** sincronizados con la nube.
  * **Fútbol en vivo:** América de Cali (Liga BetPlay) y Ligas Europeas (horario 24H antes de iniciar, marcador en vivo/final).
  * **Clima y Ubicación:** GPS de alta precisión del navegador o ciudad fijada manualmente.
  * **Reloj 24H** y fecha en tiempo real.
* **🤖 Bot Inteligente (Telegram / Nicegram & WhatsApp Cloud API):**
  * **Notas de voz nativas y texto en lenguaje natural** procesados con Gemini Flash (`gemini-3.1-flash-lite` + respaldo `gemini-flash-latest`) y comandos rápidos por Regex.
  * Menú de **8 botones interactivos** (`/menu`) para jornada, resumen del día y stock bajo.
  * **Alertas automáticas diarias (`pg_cron`, hora Colombia):** 9:00 AM (apertura + vencimientos + recordatorios), 2:00 PM (almuerzo + check interactivo de recordatorios) y 8:00 PM (cierre + stock bajo + confirmación final).

### Stack Tecnológico
* **Frontend:** Flutter 3.50 (`material_ui`, `flutter_riverpod`, `go_router`, `google_fonts`) — Android + Web PWA.
* **Base de Datos Local (Offline-First):** Drift (SQLite nativo en Android, SQLite WASM en Web) + cola transaccional FIFO (`sync_queue`).
* **Backend & Sync:** Supabase (PostgreSQL con RLS, Auth, Storage, Edge Functions en Deno/TypeScript, `pg_cron` y `pg_net`).
* **CI/CD:** GitHub Actions con despliegue automático a GitHub Pages en cada `push` a `main`.

### Ejecución Local
```powershell
# 1. Configurar variables en .env (ver .env.example)
# 2. Instalar dependencias y generar código Drift
flutter pub get
dart run build_runner build

# 3. Ejecutar en Web conectado a Supabase
flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1 `
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=tu_clave_publica

# 4. Verificar análisis estático y tests
flutter analyze
flutter test
```

---

<a id="english"></a>
## 🇺🇸 English

### Overview
**Pixel App** is a cross-platform (**Android** & **Web PWA for iPad/iPhone/Desktop**) **Offline-First** management suite built with a **Pure OLED Black (`#000000`)** theme and deep blue / cyan (`#00E5FF`) accents. It streamlines daily operations, real cash-flow tracking by payment method, Kanban order production, shift tracking, and intelligent chat automations (Telegram & WhatsApp) for a digital printing and motorcycle customization workshop.

### Key Features
* **📊 Interactive Main Dashboard:**
  * **Work Shift Tracking:** clock-in, multiple breaks (*Lunch*, *Personal Break*, *Business Errand*), and clock-out with net worked hours.
  * One-tap **`New Sale`** and **`Add Expense`** shortcuts right from the main card.
  * **3×2 Interactive Metric Grid:** *Today's Sales*, *Active Orders*, *Receivables* (top row) and *Total Cash Available*, *Digital Accounts*, *Physical Cash* (bottom row).
  * Editable **Today's Sales** list.
  * **GitHub-style Activity Heatmap (12 weeks)** with weekday labels (`Mon–Sun`), month headers, 7-day stats, and metric switcher (*Combined*, *Hours Only*, *Deliveries Only*).
* **🧩 Adaptive Orders Board (Kanban):**
  * Full production pipeline: `Pending` → `In Design` (approval toggle) → `Printing` (`Printing`, `Cutting`, `Laminating`, `Done`) → `Ready for Pickup` → `Delivered`.
  * **Advanced $\text{m}^2$ Print Calculator:** width × height × quantity, configurable waste percentage, finishing surcharges, optional design fee, and automatic inventory stock deduction.
  * **Customizable Categories & Subdivisions** with full post-creation editing and deletion.
  * **Live Stopwatch + Optional Pomodoro Mode (25/5/15 min)** per order card.
  * One-tap **WhatsApp** client messaging with dynamic status & balance templates.
* **💰 Unified Finance & Cash Reconciliation:**
  * Unified cash flow (*Business* + *Personal*) with custom categories/subdivisions, full edit support, and per-order payment history (`order_payments`).
  * Real balance split between **Physical Cash** and **Digital Accounts** (`Nequi`, `Daviplata`, `Bancolombia`, `Transfer`).
* **👥 Clients & Inventory:**
  * Client directory with motorcycle/vehicle notes and direct WhatsApp links.
  * Materials catalog with unit cost, suggested $\text{m}^2$ sale price, default waste %, and **Low Stock (`min_stock`)** alerts.
* **🕒 Live Corner Widgets (Sidebar / Mobile Top Bar):**
  * **Daily Personal Reminders** synced to Supabase.
  * **Live Football Feed:** América de Cali (Liga BetPlay) & top European leagues (24h kickoff schedule pre-match, live/final scores once started).
  * **Weather & Location:** High-accuracy browser geolocation or manually pinned city.
  * **24H Real-Time Clock** & date.
* **🤖 Intelligent Bot (Telegram / Nicegram & WhatsApp Cloud API):**
  * **Native voice notes & natural language text** parsed via Gemini Flash (`gemini-3.1-flash-lite` + `gemini-flash-latest` fallback) plus instant Regex commands.
  * **8-button interactive menu** (`/menu`) for shifts, daily financial summary, and low-stock checks.
  * **Scheduled Daily Alerts (`pg_cron`, Colombia UTC-5):** 9:00 AM (opening + due orders + reminders), 2:00 PM (lunch + interactive reminder confirmation), and 8:00 PM (closing + low stock + final reminder check).

### Tech Stack
* **Frontend:** Flutter 3.50 (`material_ui`, `flutter_riverpod`, `go_router`, `google_fonts`) — Android + Web PWA.
* **Local Offline-First DB:** Drift (SQLite native on Android, SQLite WASM on Web) + transactional FIFO `sync_queue`.
* **Backend & Sync:** Supabase (PostgreSQL + RLS, Auth, Storage, Deno/TypeScript Edge Functions, `pg_cron`, `pg_net`).
* **CI/CD:** GitHub Actions auto-deploying Flutter Web releases to GitHub Pages on every push to `main`.

### Running Locally
```powershell
# 1. Configure local environment variables in .env (see .env.example)
# 2. Install dependencies & generate Drift code
flutter pub get
dart run build_runner build

# 3. Run Flutter Web connected to Supabase
flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1 `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your_publishable_key

# 4. Run static analysis & tests
flutter analyze
flutter test
```
