# Arquitectura y Especificación Técnica: Sistema de Gestión Integral (Impresión Digital & Accesorios de Motos)

Este documento define la arquitectura, lógica de negocio, diseño UI/UX, modelo de datos y reglas estrictas de desarrollo para el proyecto. Está diseñado para ser utilizado como fuente de verdad y contexto principal dentro de **Antigravity**.

---

## 1. Visión General y Stack Tecnológico

Sistema **Offline-First** multiplataforma para la gestión operativa, financiera y horaria de un emprendimiento unipersonal de impresión digital, publicidad y personalización de motos (calcomanías, protectores, vinilos).

* **Frontend (Móvil + Web Adaptativo):** Flutter con despliegue simultáneo para **Android** y **Web Online (PWA)**, permitiendo uso fluido tanto en celular como en pantalla ancha de **iPad** sin compilar nativamente para iOS.
* **Base de Datos Local (Offline-First Relacional):** **Drift (SQLite + WASM en Web)** con una cola de sincronización transaccional (`sync_queue`) hacia Supabase. Reemplaza a Isar para garantizar compatibilidad total en Flutter Web (iPad) y paridad 1:1 con el esquema relacional de PostgreSQL.
* **Backend, Almacenamiento y Sincronización:** **Supabase** (PostgreSQL, Auth, Storage para imágenes de referencia comprimidas, Edge Functions, `pg_cron` y Realtime).
* **Integraciones de Mensajería Inteligente (Evaluación Dual):** Implementación en paralelo de **Telegram Bot** y **WhatsApp Cloud API** mediante Supabase Edge Functions, utilizando un **parser híbrido (Reglas Regex + Gemini Flash API)** para interpretar lenguaje natural y **botones interactivos** para respuestas en un toque.
* **Gestión de Estado Estándar:** **Riverpod** (`flutter_riverpod` + `riverpod_annotation` / `AsyncNotifier`) bajo estricto cumplimiento de Clean Architecture.

---

## 2. Identidad Visual y UI/UX Adaptativa

* **Tema Base:** Modo Oscuro OLED con **fondos negro puro (`#000000`)** (evitar fondos grises planos; usar superficies de contraste sutil `#0A0A0A` o `#111111` con bordes definidos `#1E293B`).
* **Paleta de Colores:** Azules profundos (`#0D47A1`, `#1565C0`) y cianes vibrantes (`#00E5FF`, `#00B8D4`) para acentos, acciones primarias y niveles de actividad.
* **Tipografía:** Sans-serif geométrica de alta legibilidad (**Inter** o **Roboto**).
* **Diseño Responsivo / Adaptativo (Android vs. iPad Web):**
  * **Android (Móvil `< 600px`):** `BottomNavigationBar`, Kanban por pestañas o carrusel horizontal con *snap*, formularios en `ModalBottomSheet`.
  * **iPad / Web (`>= 600px`):** `NavigationRail` lateral fijo, tablero Kanban multicolumna completo en pantalla y paneles laterales de detalle.
* **Pantallas Principales (4 Vistas Core):**
  1. **Dashboard Principal:**
     * Tarjeta destacada de **Control de Jornada** (Iniciar/Cerrar día, múltiples pausas de almuerzo o diligencias del negocio).
     * **Mapa de Calor Estilo GitHub (12 semanas / Anual):** Cuadrícula de actividad con intensidad en tonos azules/cianes (`#000000` → `#0D47A1` → `#1565C0` → `#00B8D4` → `#00E5FF`). Incluye selector de métrica: **Índice Combinado** (Horas trabajadas + Pedidos entregados/avanzados), **Solo Horas** o **Solo Ventas/Entregas**.
     * **Resumen de Caja Real Separada:** Arqueo rápido del día desglosado en **Efectivo Físico** vs. **Cuentas Digitales (Nequi, Daviplata, Transferencia)** + pedidos activos.
  2. **Tablero de Pedidos (Kanban Interactivo):**
     * Columnas arrastrables por estado principal (`Pendiente` → `En Diseño` → `En Impresión` → `Listo para Entrega` → `Entregado`).
     * Etiquetas visibles de subestados, fecha límite, saldo pendiente, miniatura de imagen de referencia, **cronómetro en vivo (Play/Pause)** para tiempo invertido y **botón de WhatsApp directo al cliente** con plantillas dinámicas.
  3. **Módulo Financiero:**
     * Balance unificado (Ingresos vs. Gastos totales) y arqueo por medio de pago (`cash`, `nequi`, `daviplata`, `bancolombia`, `transfer`).
     * Registro rápido de gastos diarios (Negocio vs. Personal) con categorías, subcategorías y medio de pago.
     * Cuentas por cobrar (historial detallado de abonos y saldos pendientes) y reportes mensuales.
  4. **Clientes e Inventario:**
     * Directorio de clientes con datos de moto/vehículo e historial para repetir pedidos en un toque.
     * Catálogo de materiales/insumos con costos unitarios, precios de venta sugeridos por $m^2$, descuento automático de stock y **alertas de stock mínimo (`min_stock`)**.

---

## 3. Módulos y Lógica de Negocio

### 3.1. Gestión de Pedidos, Ítems, Archivos y Producción (Kanban)
* **Estados Principales:** `Pendiente`, `En Diseño`, `En Impresión`, `Listo para Entrega`, `Entregado`.
* **Subestados Específicos:**
  * *En Diseño:* Control de aprobación (`Esperando aprobación`, `Diseño aprobado: Sí / No`).
  * *En Impresión:* Etapa física (`Imprimiendo`, `Cortando`, `Laminando`, `Finalizado`).
* **Ítems y Especificaciones del Pedido (`order_items`):** Un pedido puede contener uno o varios ítems con sus medidas (`width_cm`, `height_cm`), cantidad, material del inventario, acabados y descuento automático opcional del stock.
* **Referencias Visuales y Archivos:**
  * Soporte para adjuntar imágenes de referencia o bocetos comprimidos (almacenados en caché local y sincronizados con Supabase Storage).
  * Campo para ruta o enlace al archivo fuente en el PC (`.cdr`, `.ai`, `.psd`, `.pdf`).
* **Cronómetro de Producción y Modo Pomodoro:**
  * *Modo Cronómetro Libre (Play/Pause):* En la tarjeta del pedido calcula y acumula automáticamente `time_invested_minutes` (permitiendo también edición manual).
  * *Modo Pomodoro (Opcional):* Permite alternar el timer de un pedido a bloques de enfoque configurables (por defecto `25 min` trabajo / `5 min` descanso corto / `15 min` descanso largo tras 4 ciclos) con alerta sonora/visual al completar cada bloque. Los minutos completados en enfoque se suman automáticamente al `time_invested_minutes` del pedido y opcionalmente se registran en el historial de productividad.
* **Contacto Rápido con Cliente (WhatsApp Deep Link):** Botón en la tarjeta que abre el chat de WhatsApp del cliente con mensaje prellenado según el estado (ej. *"Hola [Nombre], te envío el boceto de tu pedido [Título] para aprobación"* o *"Hola [Nombre], tu pedido [Título] ya está listo para entrega. Saldo pendiente: $[Saldo]"*).

### 3.2. Motor Financiero Dual, Abonos y Gastos Unificados
* **Cálculo de Precios en Pedidos:**
  * *Modo Predeterminado (Manual):* Ingreso manual del precio total, registro de abonos parciales y cálculo automático del saldo pendiente.
  * *Modo Opcional (Calculadora Avanzada):* Calcula el precio sugerido basándose en:
    * Área (`ancho x alto x cantidad`) multiplicada por el costo base y precio de venta sugerido por $m^2$ del material seleccionado.
    * Porcentaje configurable de **merma/desperdicio** de corte.
    * Recargo por **acabados adicionales** (laminado protector, troquelado/corte plotter).
    * Cobro opcional por **tiempo de diseño** invertido.
* **Historial de Abonos y Arqueo (`order_payments`):**
  * Cada pago o abono se registra individualmente con su fecha, monto y **método de pago** (`Efectivo`, `Nequi`, `Daviplata`, `Transferencia`).
* **Control de Gastos Diarios (`expenses`):**
  * **Cuenta Única Unificada:** Registra tanto gastos del negocio (`business`) como gastos personales (`personal`), indicando siempre el **método de pago** de donde salió el dinero para mantener el cuadre exacto entre efectivo físico y cuentas digitales.
  * **Categorización Obligatoria:** Categorías y subcategorías detalladas (ej. *Alimentación/Comida*, *Insumos/Vinilos*, *Servicios Local*, *Gastos Personales*, *Transporte*).

### 3.3. Control de Jornada Laboral Múltiple y Alertas Inteligentes
* Registro ágil de: **Hora de apertura**, **Múltiples pausas/salidas en el día** y **Hora de cierre**.
* **Tipos de Pausa (`work_breaks`):** Permite registrar tanto el **Almuerzo / Descanso personal** como **Diligencias del negocio** (ej. salir a comprar vinilo o entregar un pedido) con notas opcionales.
* **Notificaciones Locales y Proactivas (con Botones Interactivos en Chat):**
  * Ej. 10:00 AM (si no hay apertura registrada): *"¿A qué hora abriste hoy el local?"* con botones rápidos en Telegram/WhatsApp (`[Abrí 8:00 AM]`, `[Abrí 9:00 AM]`, `[Abrí Ahora]`).
  * Ej. Entre 12:00 PM y 3:00 PM: Recordatorio para registrar la pausa de almuerzo (`[Iniciar Almuerzo]`).
  * Recordatorio de cierre de jornada al finalizar el día.

### 3.4. Analítica y Reportes Mensuales
* Cálculo automático mensual, semanal y diario de:
  * Total facturado (ventas realizadas), dinero recaudado por medio de pago (Efectivo vs. Digital) y dinero pendiente por cobrar.
  * Total de gastos desglosados por ámbito (`business` vs. `personal`), categoría/subcategoría y ganancia neta real.
  * Días trabajados, horas netas laboradas, tiempo en diligencias y tiempo total de descansos.

### 3.5. Integración Bidireccional Inteligente (Telegram Bot & WhatsApp Cloud API)
* **Entrada (Tú → App) con Parser Híbrido (Regex + Gemini Flash API):**
  * Las Supabase Edge Functions intentan primero un parseo instantáneo por reglas (`Regex`) para comandos directos.
  * Si el mensaje es en lenguaje natural libre (ej. *"Me gasté 18 mil en almuerzo pagando por Nequi"* o *"Pedido de Juan calcomanías Pulsar 50x30 en vinilo reflectivo para el viernes, abonó 20000 en efectivo"*), la función invoca a **Gemini Flash API** para extraer el JSON estructurado e insertarlo en Supabase.
* **Salida (App → Tú):** El bot envía notificaciones proactivas al chat sobre pedidos próximos a vencer, alertas de stock mínimo, saldos pendientes y recordatorios interactivos de apertura/almuerzo/cierre.

---

## 4. Esquema de Base de Datos Relacional (Drift SQLite + Supabase PostgreSQL)

> **Nota de Sincronización Offline-First:** Todas las tablas incluyen `updated_at` y `deleted_at` (nullable, para *soft-deletes*), además de una tabla local `sync_queue` en Drift que almacena operaciones pendientes (`INSERT`, `UPDATE`, `DELETE`) cuando no hay internet y las sincroniza automáticamente con Supabase al recuperar conexión.

### `clients` (Clientes)
* `id`: UUID (PK)
* `name`: String (Nombre o razón social)
* `document_id`: String (Cédula / NIT - nullable)
* `phone`: String (Número de WhatsApp con código de país)
* `vehicle_info`: String (Modelo de moto/vehículo, color, año - nullable)
* `notes`: String (Preferencias recurrentes - nullable)
* `created_at`: Timestamp
* `updated_at`: Timestamp
* `deleted_at`: Timestamp (nullable)

### `materials` (Inventario / Insumos)
* `id`: UUID (PK)
* `name`: String (Ej. Vinilo laminado, Vinilo reflectivo, Papel transfer)
* `unit`: Enum (`m2`, `cm2`, `unit`, `linear_meter`)
* `unit_cost`: Double (Costo bruto de compra por unidad/m²)
* `suggested_sale_price`: Double (Precio base de venta sugerido por unidad/m²)
* `default_waste_percentage`: Double (Porcentaje de merma por defecto, ej. `15.0`)
* `stock`: Double (Cantidad actual disponible)
* `min_stock`: Double (Umbral para disparar alerta de stock bajo)
* `updated_at`: Timestamp
* `deleted_at`: Timestamp (nullable)

### `orders` (Pedidos - Cabecera)
* `id`: UUID (PK)
* `client_id`: UUID (FK → `clients.id`)
* `title`: String (Descripción corta del trabajo)
* `status`: Enum (`pending`, `design`, `printing`, `ready`, `delivered`)
* `design_approved`: Boolean (Subestado de diseño)
* `print_stage`: Enum (`none`, `printing`, `cutting`, `laminating`, `done`)
* `technical_notes`: String (Notas generales de diseño o instalación)
* `source_file_path`: String (Ruta local en PC o link externo al archivo `.cdr`/`.ai` - nullable)
* `reference_images`: JSONB / List\<String\> (Rutas locales / URLs en Supabase Storage de bocetos o fotos)
* `time_invested_minutes`: Integer (Acumulado total de tiempo)
* `active_timer_started_at`: Timestamp (nullable - para el cronómetro Play/Pause o Pomodoro en vivo)
* `timer_mode`: Enum (`stopwatch`, `pomodoro`)
* `pomodoro_sessions_completed`: Integer (Cantidad de ciclos Pomodoro completados en este pedido)
* `deadline`: Timestamp
* `priority`: Enum (`low`, `medium`, `high`)
* `pricing_mode`: Enum (`manual`, `auto`)
* `design_fee`: Double (Cobro adicional opcional por tiempo de diseño)
* `total_price`: Double
* `amount_paid`: Double (Suma calculada/sincronizada de `order_payments`)
* `balance_due`: Double (Calculado: `total_price - amount_paid`)
* `created_at`: Timestamp
* `updated_at`: Timestamp
* `deleted_at`: Timestamp (nullable)

### `order_items` (Ítems y Medidas del Pedido)
* `id`: UUID (PK)
* `order_id`: UUID (FK → `orders.id`)
* `material_id`: UUID (FK → `materials.id`, nullable)
* `description`: String (Ej. "Calcomanías laterales tanque")
* `width_cm`: Double
* `height_cm`: Double
* `quantity`: Integer
* `waste_percentage`: Double (Merma aplicada)
* `finishing_type`: Enum (`none`, `matte_laminate`, `gloss_laminate`, `die_cut`, `reflective`)
* `finishing_surcharge`: Double (Recargo por acabado)
* `calculated_price`: Double
* `deducted_from_stock`: Boolean (Indica si ya descontó del inventario)
* `updated_at`: Timestamp

### `order_payments` (Historial de Abonos y Pagos de Pedidos)
* `id`: UUID (PK)
* `order_id`: UUID (FK → `orders.id`)
* `amount`: Double
* `payment_method`: Enum (`cash`, `nequi`, `daviplata`, `bancolombia`, `transfer`, `other`)
* `notes`: String (nullable)
* `payment_date`: Timestamp
* `created_at`: Timestamp

### `expenses` (Gastos Diarios Unificados)
* `id`: UUID (PK)
* `amount`: Double
* `scope`: Enum (`business`, `personal`)
* `payment_method`: Enum (`cash`, `nequi`, `daviplata`, `bancolombia`, `transfer`, `other`)
* `category`: String (Ej. Comida, Insumos, Servicios, Transporte)
* `subcategory`: String (Ej. Almuerzo, Vinilo Negro)
* `description`: String
* `date`: Timestamp
* `source`: Enum (`app`, `telegram`, `whatsapp`)
* `updated_at`: Timestamp
* `deleted_at`: Timestamp (nullable)

### `work_logs` (Control de Jornada Diaria)
* `id`: UUID (PK)
* `date`: Date (Único por día)
* `open_time`: Timestamp
* `close_time`: Timestamp (nullable)
* `total_worked_minutes`: Integer (Tiempo neto trabajado descontando pausas personales)
* `total_break_minutes`: Integer (Suma de pausas personales/almuerzo)
* `notes`: String (nullable)
* `updated_at`: Timestamp

### `work_breaks` (Pausas y Salidas de la Jornada)
* `id`: UUID (PK)
* `work_log_id`: UUID (FK → `work_logs.id`)
* `type`: Enum (`lunch`, `personal_break`, `business_errand`)
* `start_time`: Timestamp
* `end_time`: Timestamp (nullable)
* `notes`: String (Ej. "Salida a comprar vinilo reflectivo" - nullable)
* `updated_at`: Timestamp

---

## 5. Arquitectura de Carpetas (Clean Code & Clean Architecture con Riverpod)

```text
lib/
├── core/
│   ├── constants/        # Colores (#000000, azules, cianes), strings, rutas, enums
│   ├── theme/            # ThemeData OLED negro puro, tipografías Inter/Roboto
│   ├── layout/           # ResponsiveShell (NavigationRail iPad vs BottomNav Android)
│   ├── errors/           # Failures y Exceptions personalizadas
│   ├── network/          # Cliente Supabase, verificador de conectividad
│   ├── database/         # Esquema Drift (SQLite + WASM Web) y SyncEngine (sync_queue)
│   └── utils/            # Formateadores COP, fechas, WhatsApp deep-links y calculadora m2
├── features/
│   ├── dashboard/        # Resumen de caja (Efectivo vs Digital), Heatmap GitHub y tarjeta jornada
│   ├── orders/           # Tablero Kanban, items, pagos, cronómetro, imágenes y calculadora
│   │   ├── data/         # Drift Tables/DAOs, DTOs, DataSources (local/remote), RepositoriesImpl
│   │   ├── domain/       # Entities (Freezed), Repositories (interfaces), UseCases
│   │   └── presentation/ # Pages, Widgets adaptativos, Riverpod Notifiers/Providers
│   ├── finance/          # Gastos unificados, arqueo por método de pago, categorías y reportes
│   ├── clients/          # Directorio, datos de motos/vehículos e historial en 1 toque
│   ├── inventory/        # Catálogo de materiales, precios m2 y alertas de min_stock
│   └── time_tracking/    # Lógica de apertura, múltiples pausas/diligencias, cierre y alertas
└── main.dart
```

---

## 6. Reglas Estrictas de Desarrollo para Antigravity

> **INSTRUCCIONES PARA EL AGENTE DE DESARROLLO:**
> 1. **Clean Code 100%:** Aplicar principios SOLID, nombres descriptivos en inglés para código (comentarios/UI en español), funciones cortas con responsabilidad única y cero código duplicado.
> 2. **Separación de Capas:** Nunca mezclar lógica de negocio o llamadas a Supabase/Drift dentro de los Widgets de Flutter. Usar siempre el flujo `UI -> Riverpod Notifier -> UseCase -> Repository -> DataSource (Drift Local / Supabase Remote)`.
> 3. **Protocolo Obligatorio de GitHub (Alerta Constante):**
>    * Mantener el repositorio conectado a GitHub desde el inicio.
>    * Usar **Conventional Commits** (`feat:`, `fix:`, `refactor:`, `docs:`, `style:`).
>    * **REGLA CRÍTICA:** Al finalizar CADA funcionalidad, corrección o cambio significativo, el agente **DEBE detenerse y preguntar explícitamente al usuario** si desea hacer `git add`, `git commit` y `git push` a GitHub, insistiendo/recordando mantener el repositorio actualizado antes de pasar al siguiente módulo.
> 4. **Compatibilidad Web (iPad) y Móvil (Android):** Verificar siempre que todos los paquetes funcionen en Flutter Web (usando Drift WASM para base de datos local, `image_picker` compatible con Web/Android y layouts responsivos para iPad).

---

## 7. Hoja de Ruta (Paso a Paso en Antigravity)

1. **Fase 1: Configuración Inicial, Entorno y Shell Adaptativo**
   * Crear proyecto Flutter con soporte Mobile (Android) + Web (PWA para iPad).
   * Inicializar Git, configurar `.gitignore` y conectar con el repositorio remoto en GitHub.
   * Configurar el tema visual OLED (`#000000` + azules/cianes), Riverpod y el `ResponsiveShell` (`BottomNavigationBar` en Android / `NavigationRail` en iPad).
2. **Fase 2: Base de Datos Relacional (Drift + Supabase) y Motor Offline-First**
   * Crear tablas relacionales en Supabase (PostgreSQL) con políticas RLS y bucket en Supabase Storage para imágenes de referencia.
   * Configurar tablas locales en **Drift (SQLite + soporte Web WASM)** y construir el `SyncEngine` con `sync_queue` para operación 100% Offline-First.
3. **Fase 3: Módulos Core (Inventario, Clientes y Finanzas por Medio de Pago)**
   * Implementar Clientes (con datos de moto y botón a WhatsApp) e Inventario (costos, precios por $m^2$, alertas de `min_stock`).
   * Implementar Finanzas: registro de gastos unificados (`business`/`personal`) con categorías y arqueo separado por medio de pago (`Efectivo` vs. `Nequi/Digital`).
4. **Fase 4: Tablero Kanban de Pedidos, Calculadora Avanzada y Cronómetro**
   * Implementar Kanban interactivo adaptativo con subestados (`design_approved`, `print_stage`).
   * Integrar calculadora avanzada ($m^2$, merma, acabados, diseño), gestión de múltiples `order_items`, historial de abonos (`order_payments`), cronómetro en vivo con **modo Pomodoro opcional** y carga de imágenes de referencia.
5. **Fase 5: Control de Jornada Múltiple y Dashboard con Mapa de Calor GitHub**
   * Implementar Control de Jornada (`work_logs` + `work_breaks` para almuerzo y diligencias) y notificaciones locales.
   * Construir el Dashboard con el **Mapa de Calor Estilo GitHub** (selector de índice combinado, horas o ventas) y métricas de caja real.
6. **Fase 6: Integraciones de Mensajería Inteligente (Telegram & WhatsApp Cloud API)**
   * Desplegar Edge Functions en Supabase con el **parser híbrido (Regex + Gemini Flash API)** para registro natural de gastos/pedidos por chat.
   * Configurar alertas proactivas con **botones interactivos** para apertura, almuerzo, cierre y vencimiento de pedidos, evaluando ambos canales en paralelo.
