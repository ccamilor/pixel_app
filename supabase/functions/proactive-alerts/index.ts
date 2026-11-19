import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Edge Function programable con Supabase pg_cron para enviar alertas proactivas
// con botones interactivos a Telegram y/o WhatsApp Cloud API.

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const TELEGRAM_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const TELEGRAM_CHAT_ID = Deno.env.get("TELEGRAM_OWNER_CHAT_ID") ?? "";

async function sendTelegramAlert(text: string, buttons?: Array<Array<{ text: string; callback_data: string }>>) {
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

Deno.serve(async (req) => {
  const { alert_type } = await req.json().catch(() => ({ alert_type: "daily_check" }));
  const today = new Date().toISOString().slice(0, 10);

  if (alert_type === "morning_open_check") {
    const { data: log } = await supabase
      .from("work_logs")
      .select("id")
      .eq("date", today)
      .maybeSingle();

    if (!log) {
      await sendTelegramAlert(
        "☀️ *Buenos días!* Aún no registras apertura hoy. ¿A qué hora abriste el local?",
        [[
          { text: "8:00 AM", callback_data: "work:open:08" },
          { text: "9:00 AM", callback_data: "work:open:09" },
          { text: "Abrí Ahora", callback_data: "work:open:now" },
        ]],
      );
    }
  } else if (alert_type === "lunch_reminder") {
    await sendTelegramAlert(
      "🍽️ *Recordatorio de almuerzo:* ¿Vas a tomar tu pausa?",
      [[{ text: "Iniciar Almuerzo", callback_data: "work:lunch_start" }]],
    );
  } else if (alert_type === "daily_check") {
    const { data: lowStock } = await supabase
      .from("materials")
      .select("name, stock, min_stock")
      .is("deleted_at", null);

    const alerts = (lowStock ?? []).filter((m) => m.stock <= m.min_stock);
    if (alerts.length > 0) {
      const list = alerts.map((m) => `• ${m.name}: ${m.stock}`).join("\n");
      await sendTelegramAlert(`⚠️ *Alerta de Stock Bajo:*\n${list}`);
    }
  }

  return new Response(JSON.stringify({ ok: true, alert_type }), { status: 200 });
});
