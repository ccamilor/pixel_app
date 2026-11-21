import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Edge Function programada con pg_cron (hora Colombia UTC-5):
// - 9:00 AM COL (14:00 UTC): Apertura + Pedidos por vencer hoy + Recordatorios del día
// - 2:00 PM COL (19:00 UTC): Recordatorio de almuerzo + Confirmación interactiva de recordatorios
// - 8:00 PM COL (01:00 UTC): Cierre de jornada + Resumen financiero + Stock bajo + Confirmación final de recordatorios

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const TELEGRAM_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const TELEGRAM_CHAT_ID = Deno.env.get("TELEGRAM_OWNER_CHAT_ID") ?? "";

type InlineButtons = Array<Array<{ text: string; callback_data: string }>>;

async function sendTelegramAlert(text: string, buttons?: InlineButtons) {
  if (!TELEGRAM_TOKEN || !TELEGRAM_CHAT_ID) return;
  await fetch(`https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: TELEGRAM_CHAT_ID,
      text,
      parse_mode: "Markdown",
      reply_markup: buttons ? { inline_keyboard: buttons } : undefined,
    }),
  });
}

function getColombiaTodayKey(): string {
  const col = new Date(Date.now() - 5 * 60 * 60 * 1000);
  return col.toISOString().slice(0, 10);
}

async function sendPendingRemindersCheck(todayKey: string, header: string) {
  const { data: reminders } = await supabase
    .from("daily_reminders")
    .select("id, title, is_done")
    .eq("date_key", todayKey)
    .eq("is_done", false)
    .is("deleted_at", null);

  if (!reminders || reminders.length === 0) return;

  const lines = reminders.map((r, i) => `${i + 1}. ${r.title}`).join("\n");
  const buttons: InlineButtons = reminders.slice(0, 5).map((r) => [
    { text: `✅ Hecho: ${r.title.slice(0, 26)}`, callback_data: `rem:done:${r.id}` },
    { text: "⏳ Pendiente", callback_data: `rem:keep:${r.id}` },
  ]);

  await sendTelegramAlert(
    `${header}\n${lines}\n\n_Confirma tocando cada botón:_`,
    buttons,
  );
}

Deno.serve(async (req) => {
  const { alert_type } = await req.json().catch(() => ({ alert_type: "morning_9am" }));
  const todayCol = getColombiaTodayKey();
  const endOfTodayUtc = `${todayCol}T23:59:59-05:00`;

  if (alert_type === "morning_9am" || alert_type === "morning_open_check") {
    const [{ data: log }, { data: dueOrders }, { data: reminders }] =
      await Promise.all([
        supabase
          .from("work_logs")
          .select("id")
          .eq("date", todayCol)
          .maybeSingle(),
        supabase
          .from("orders")
          .select("title, deadline, status")
          .neq("status", "delivered")
          .lte("deadline", endOfTodayUtc)
          .is("deleted_at", null),
        supabase
          .from("daily_reminders")
          .select("title")
          .eq("date_key", todayCol)
          .eq("is_done", false)
          .is("deleted_at", null),
      ]);

    const parts: string[] = ["☀️ *¡Buenos días! Alerta 9:00 AM — Pixel App*"];

    if (!log) {
      parts.push("Aún no registras la apertura del local hoy. ¿A qué hora abriste?");
    } else {
      parts.push("✅ Apertura de jornada ya registrada.");
    }

    if (dueOrders && dueOrders.length > 0) {
      const list = dueOrders.map((o) => `• ${o.title}`).join("\n");
      parts.push(`\n📦 *Pedidos por entregar hoy / vencidos (${dueOrders.length}):*\n${list}`);
    }

    if (reminders && reminders.length > 0) {
      const list = reminders.map((r) => `• ${r.title}`).join("\n");
      parts.push(`\n📝 *Recordatorios personales de hoy:*\n${list}`);
    }

    const buttons: InlineButtons = !log
      ? [[
          { text: "8:00 AM", callback_data: "work:open:08" },
          { text: "9:00 AM", callback_data: "work:open:09" },
          { text: "Abrí Ahora", callback_data: "work:open:now" },
        ]]
      : [[{ text: "📊 Ver Resumen", callback_data: "info:summary" }]];

    await sendTelegramAlert(parts.join("\n"), buttons);
  } else if (alert_type === "afternoon_2pm" || alert_type === "lunch_reminder") {
    await sendTelegramAlert(
      "🍽️ *Recordatorio 2:00 PM:* ¿Ya tomaste o vas a tomar tu pausa de almuerzo?",
      [[
        { text: "🍽️ Iniciar Almuerzo", callback_data: "work:lunch_start" },
        { text: "▶️ Ya volví", callback_data: "work:resume" },
      ]],
    );

    await sendPendingRemindersCheck(
      todayCol,
      "📝 *Check de Recordatorios Personales (2:00 PM):*",
    );
  } else if (alert_type === "night_8pm" || alert_type === "daily_check") {
    const [{ data: log }, { data: materials }] = await Promise.all([
      supabase
        .from("work_logs")
        .select("id, close_time")
        .eq("date", todayCol)
        .maybeSingle(),
      supabase
        .from("materials")
        .select("name, stock, min_stock, unit")
        .is("deleted_at", null),
    ]);

    const lowStock = (materials ?? []).filter(
      (m) => Number(m.stock) <= Number(m.min_stock),
    );

    const parts: string[] = ["🌙 *Cierre de Día 8:00 PM — Pixel App*"];
    if (log && !log.close_time) {
      parts.push("Tu jornada sigue abierta. ¿Cerramos el local ahora?");
    }
    if (lowStock.length > 0) {
      const list = lowStock
        .map((m) => `• ${m.name}: ${m.stock} ${m.unit}`)
        .join("\n");
      parts.push(`\n⚠️ *Alertas de Stock Bajo (${lowStock.length}):*\n${list}`);
    }

    const buttons: InlineButtons = [
      [
        { text: "🌙 Cerrar Jornada", callback_data: "work:close" },
        { text: "📊 Resumen de Hoy", callback_data: "info:summary" },
      ],
    ];
    await sendTelegramAlert(parts.join("\n"), buttons);

    await sendPendingRemindersCheck(
      todayCol,
      "🔔 *Confirmación Final de Recordatorios de Hoy (8:00 PM):*",
    );
  }

  return new Response(JSON.stringify({ ok: true, alert_type, todayCol }), {
    status: 200,
  });
});
