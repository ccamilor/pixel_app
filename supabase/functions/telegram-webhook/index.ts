import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { parseMessageHybrid } from "../_shared/hybrid_parser.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const TELEGRAM_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

async function sendTelegramReply(chatId: number | string, text: string) {
  if (!TELEGRAM_TOKEN) return;
  await fetch(`https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text, parse_mode: "Markdown" }),
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  const update = await req.json();

  // 1. Respuestas a botones interactivos (Callback Query)
  if (update.callback_query) {
    const cb = update.callback_query;
    const data = String(cb.data ?? "");
    const chatId = cb.message?.chat?.id;
    const today = new Date().toISOString().slice(0, 10);

    if (data.startsWith("work:open:")) {
      const hour = data.split(":")[2];
      const openTime = hour === "now" ? new Date().toISOString() : `${today}T${hour}:00:00-05:00`;
      await supabase.from("work_logs").upsert({
        date: today,
        open_time: openTime,
        updated_at: new Date().toISOString(),
      }, { onConflict: "date" });
      await sendTelegramReply(chatId, `✅ Apertura registrada (${hour === "now" ? "ahora" : `${hour}:00`}).`);
    } else if (data === "work:lunch_start") {
      const { data: log } = await supabase.from("work_logs").select("id").eq("date", today).single();
      if (log) {
        await supabase.from("work_breaks").insert({
          work_log_id: log.id,
          type: "lunch",
          start_time: new Date().toISOString(),
        });
        await sendTelegramReply(chatId, "🍽️ Pausa de almuerzo iniciada.");
      }
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }

  // 2. Mensajes de texto libre / comandos rápidos
  const message = update.message;
  const text = message?.text?.trim();
  const chatId = message?.chat?.id;
  if (!text || !chatId) return new Response("OK", { status: 200 });

  const parsed = await parseMessageHybrid(text, GEMINI_API_KEY);

  if (parsed.intent === "expense") {
    await supabase.from("expenses").insert({
      amount: parsed.amount,
      scope: parsed.scope,
      payment_method: parsed.payment_method,
      category: parsed.category,
      subcategory: parsed.subcategory,
      description: parsed.description,
      source: "telegram",
    });
    await sendTelegramReply(
      chatId,
      `💸 Gasto guardado: *$${parsed.amount.toLocaleString("es-CO")}* (${parsed.category} / ${parsed.payment_method}).`,
    );
  } else if (parsed.intent === "order_note") {
    await sendTelegramReply(
      chatId,
      `📐 Medida recibida para *${parsed.client_name}*: ${parsed.title}. Lista para asociar en App Pixel.`,
    );
  } else {
    await sendTelegramReply(
      chatId,
      'No entendí el formato. Prueba con:\n• `Gasto 15000 comida almuerzo nequi`\n• `Medida 50x30 vinilo reflectivo cliente Juan`',
    );
  }

  return new Response(JSON.stringify({ ok: true }), { status: 200 });
});
