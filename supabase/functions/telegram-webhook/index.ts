import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  parseAudioWithGemini,
  parseMessageHybrid,
  type ParsedMessage,
} from "../_shared/hybrid_parser.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const TELEGRAM_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

type InlineKeyboard = Array<Array<{ text: string; callback_data: string }>>;

const MAIN_MENU_BUTTONS: InlineKeyboard = [
  [
    { text: "☀️ Abrir Local", callback_data: "work:open:now" },
    { text: "🍽️ Almuerzo", callback_data: "work:lunch_start" },
    { text: "▶️ Reanudar", callback_data: "work:resume" },
  ],
  [
    { text: "🏍️ Diligencia", callback_data: "work:errand_start" },
    { text: "🌙 Cerrar Día", callback_data: "work:close" },
  ],
  [
    { text: "📊 Resumen de Hoy", callback_data: "info:summary" },
    { text: "⚠️ Stock Bajo", callback_data: "info:low_stock" },
  ],
  [
    { text: "❓ Ver Comandos y Ejemplos", callback_data: "info:help" },
  ],
];

async function sendTelegramReply(
  chatId: number | string,
  text: string,
  buttons?: InlineKeyboard,
) {
  if (!TELEGRAM_TOKEN) return;
  await fetch(`https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      parse_mode: "Markdown",
      reply_markup: buttons ? { inline_keyboard: buttons } : undefined,
    }),
  });
}

async function answerCallbackQuery(callbackQueryId: string, text?: string) {
  if (!TELEGRAM_TOKEN) return;
  await fetch(
    `https://api.telegram.org/bot${TELEGRAM_TOKEN}/answerCallbackQuery`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ callback_query_id: callbackQueryId, text }),
    },
  );
}

async function downloadTelegramFileBase64(
  fileId: string,
): Promise<{ base64: string; mimeType: string } | null> {
  const infoRes = await fetch(
    `https://api.telegram.org/bot${TELEGRAM_TOKEN}/getFile?file_id=${fileId}`,
  );
  if (!infoRes.ok) return null;
  const infoJson = await infoRes.json();
  const filePath = infoJson?.result?.file_path as string | undefined;
  if (!filePath) return null;

  const fileRes = await fetch(
    `https://api.telegram.org/file/bot${TELEGRAM_TOKEN}/${filePath}`,
  );
  if (!fileRes.ok) return null;
  const bytes = new Uint8Array(await fileRes.arrayBuffer());
  const mimeType = filePath.endsWith(".mp3")
    ? "audio/mpeg"
    : filePath.endsWith(".m4a")
    ? "audio/mp4"
    : "audio/ogg";

  return { base64: encodeBase64(bytes), mimeType };
}

async function buildDailySummaryText(): Promise<string> {
  // Hora local de Colombia (UTC-5) para el corte exacto del día
  const colombiaNow = new Date(Date.now() - 5 * 60 * 60 * 1000);
  const todayCol = colombiaNow.toISOString().slice(0, 10);
  const startOfDayUtc = `${todayCol}T05:00:00.000Z`;

  const [
    { data: payments },
    { data: expenses },
    { data: orders },
    { data: allPayments },
    { data: allExpenses },
  ] = await Promise.all([
    supabase
      .from("order_payments")
      .select("amount, payment_method")
      .gte("payment_date", startOfDayUtc)
      .is("deleted_at", null),
    supabase
      .from("expenses")
      .select("amount, payment_method")
      .gte("date", startOfDayUtc)
      .is("deleted_at", null),
    supabase
      .from("orders")
      .select("id, title, status, total_price, amount_paid, created_at")
      .is("deleted_at", null),
    supabase
      .from("order_payments")
      .select("amount, payment_method")
      .is("deleted_at", null),
    supabase
      .from("expenses")
      .select("amount, payment_method")
      .is("deleted_at", null),
  ]);

  const incomeToday = (payments ?? []).reduce(
    (s, p) => s + Number(p.amount ?? 0),
    0,
  );
  const expensesToday = (expenses ?? []).reduce(
    (s, e) => s + Number(e.amount ?? 0),
    0,
  );
  const ordersToday = (orders ?? []).filter(
    (o) => String(o.created_at ?? "") >= startOfDayUtc,
  );
  const salesTodayTotal = ordersToday.reduce(
    (s, o) => s + Number(o.total_price ?? 0),
    0,
  );

  let cashIn = 0;
  let digitalIn = 0;
  for (const p of allPayments ?? []) {
    if (p.payment_method === "cash") cashIn += Number(p.amount ?? 0);
    else digitalIn += Number(p.amount ?? 0);
  }
  let cashOut = 0;
  let digitalOut = 0;
  for (const e of allExpenses ?? []) {
    if (e.payment_method === "cash") cashOut += Number(e.amount ?? 0);
    else digitalOut += Number(e.amount ?? 0);
  }
  const totalAvailable = cashIn + digitalIn - (cashOut + digitalOut);

  const activeOrders = (orders ?? []).filter((o) => o.status !== "delivered");
  const receivable = (orders ?? []).reduce(
    (s, o) =>
      s + Math.max(0, Number(o.total_price ?? 0) - Number(o.amount_paid ?? 0)),
    0,
  );

  return `📊 *Resumen Pixel App (${todayCol})*\n\n` +
    `🛒 *Hoy:*\n` +
    `• Ventas del día (${ordersToday.length}): *$${salesTodayTotal.toLocaleString("es-CO")}*\n` +
    `• Recaudado hoy: *$${incomeToday.toLocaleString("es-CO")}*\n` +
    `• Gastos hoy: *$${expensesToday.toLocaleString("es-CO")}*\n\n` +
    `💰 *Caja Total Disponible:* *$${totalAvailable.toLocaleString("es-CO")}*\n` +
    `• Efectivo: $${(cashIn - cashOut).toLocaleString("es-CO")}\n` +
    `• Cuenta Digital: $${(digitalIn - digitalOut).toLocaleString("es-CO")}\n\n` +
    `📦 *Pedidos Activos:* *${activeOrders.length}*\n` +
    `⏳ *Por Cobrar:* *$${receivable.toLocaleString("es-CO")}*`;
}

async function buildLowStockText(): Promise<string> {
  const { data: materials } = await supabase
    .from("materials")
    .select("name, stock, min_stock, unit")
    .is("deleted_at", null);

  const low = (materials ?? []).filter(
    (m) => Number(m.stock) <= Number(m.min_stock),
  );
  if (low.length === 0) {
    return "✅ *Inventario al día:* No tienes materiales por debajo del stock mínimo.";
  }
  const lines = low
    .map((m) => `• *${m.name}*: ${m.stock} ${m.unit} (mín: ${m.min_stock})`)
    .join("\n");
  return `⚠️ *Alertas de Stock Bajo (${low.length}):*\n${lines}`;
}

async function handleWorkAction(
  chatId: number | string,
  action: "open" | "lunch_start" | "lunch_end" | "errand_start" | "close",
  customHour?: string,
  notes?: string | null,
) {
  const today = new Date().toISOString().slice(0, 10);
  const nowIso = new Date().toISOString();

  if (action === "open") {
    const openTime =
      customHour && customHour !== "now"
        ? `${today}T${customHour}:00:00-05:00`
        : nowIso;
    await supabase
      .from("work_logs")
      .upsert(
        { date: today, open_time: openTime, updated_at: nowIso },
        { onConflict: "date" },
      );
    await sendTelegramReply(
      chatId,
      `☀️ *Jornada iniciada* (${customHour && customHour !== "now" ? `${customHour}:00` : "ahora"}).`,
    );
    return;
  }

  const { data: log } = await supabase
    .from("work_logs")
    .select("id, open_time")
    .eq("date", today)
    .maybeSingle();

  if (!log) {
    await sendTelegramReply(
      chatId,
      "Primero debes iniciar la jornada de hoy.",
      MAIN_MENU_BUTTONS,
    );
    return;
  }

  if (action === "lunch_start" || action === "errand_start") {
    const breakType =
      action === "errand_start" ? "business_errand" : "lunch";
    await supabase.from("work_breaks").insert({
      work_log_id: log.id,
      type: breakType,
      start_time: nowIso,
      notes: notes ?? null,
    });
    await sendTelegramReply(
      chatId,
      breakType === "lunch"
        ? "🍽️ *Pausa de almuerzo iniciada.*"
        : "🏍️ *Salida por diligencia del negocio registrada.*",
    );
  } else if (action === "lunch_end") {
    await supabase
      .from("work_breaks")
      .update({ end_time: nowIso, updated_at: nowIso })
      .eq("work_log_id", log.id)
      .is("end_time", null);
    await sendTelegramReply(chatId, "▶️ *Pausa finalizada. ¡De vuelta al trabajo!*");
  } else if (action === "close") {
    await supabase
      .from("work_breaks")
      .update({ end_time: nowIso, updated_at: nowIso })
      .eq("work_log_id", log.id)
      .is("end_time", null);

    const openMs = new Date(log.open_time).getTime();
    const totalMinutes = Math.max(0, Math.round((Date.now() - openMs) / 60000));
    await supabase
      .from("work_logs")
      .update({
        close_time: nowIso,
        total_worked_minutes: totalMinutes,
        updated_at: nowIso,
      })
      .eq("id", log.id);
    await sendTelegramReply(
      chatId,
      `🌙 *Jornada cerrada.* Total registrado hoy: ${(totalMinutes / 60).toFixed(1)}h.`,
    );
  }
}

async function executeParsedIntent(
  chatId: number | string,
  parsed: ParsedMessage,
) {
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
      `💸 *Gasto guardado:* $${parsed.amount.toLocaleString("es-CO")}\n` +
        `• Categoría: ${parsed.category}${parsed.subcategory ? ` / ${parsed.subcategory}` : ""}\n` +
        `• Medio: ${parsed.payment_method} (${parsed.scope === "personal" ? "Personal" : "Negocio"})`,
    );
    return;
  }

  if (parsed.intent === "sale") {
    const clientName = parsed.client_name?.trim() || "Cliente Mostrador";
    const { data: existingClient } = await supabase
      .from("clients")
      .select("id")
      .ilike("name", clientName)
      .is("deleted_at", null)
      .limit(1)
      .maybeSingle();

    let clientId = existingClient?.id as string | undefined;
    if (!clientId) {
      const { data: createdClient } = await supabase
        .from("clients")
        .insert({ name: clientName, phone: "" })
        .select("id")
        .single();
      clientId = createdClient?.id;
    }

    if (clientId) {
      const deadline = new Date(Date.now() + 86400000).toISOString();
      const { data: order } = await supabase
        .from("orders")
        .insert({
          client_id: clientId,
          title: parsed.title,
          status: "pending",
          technical_notes: parsed.notes ?? "",
          deadline,
          total_price: parsed.total_price,
          amount_paid: parsed.amount_paid,
        })
        .select("id")
        .single();

      if (order?.id && parsed.amount_paid > 0) {
        await supabase.from("order_payments").insert({
          order_id: order.id,
          amount: parsed.amount_paid,
          payment_method: parsed.payment_method,
          notes: "Registrado vía Telegram",
        });
      }

      const balance = Math.max(0, parsed.total_price - parsed.amount_paid);
      await sendTelegramReply(
        chatId,
        `💰 *Venta registrada:* ${parsed.title}\n` +
          `• Cliente: ${clientName}\n` +
          `• Total: $${parsed.total_price.toLocaleString("es-CO")} (${parsed.payment_method})\n` +
          `• ${balance > 0 ? `Saldo pendiente: $${balance.toLocaleString("es-CO")}` : "Pagado en su totalidad ✅"}`,
      );
      return;
    }
  }

  if (parsed.intent === "work_action") {
    await handleWorkAction(chatId, parsed.action, undefined, parsed.notes);
    return;
  }

  if (parsed.intent === "order_note") {
    await sendTelegramReply(
      chatId,
      `📐 *Medida anotada para ${parsed.client_name}:*\n${parsed.title}\n_${parsed.notes}_`,
    );
    return;
  }

  if (parsed.intent === "summary") {
    await sendTelegramReply(chatId, await buildDailySummaryText(), MAIN_MENU_BUTTONS);
    return;
  }

  await sendTelegramReply(
    chatId,
    "No entendí el mensaje. Toca un botón o envíame *texto o nota de voz*:\n" +
      "• `Gasto 15000 comida almuerzo nequi`\n" +
      "• `Venta 45000 calcomanía tanque efectivo`\n" +
      "• `Medida 50x30 vinilo reflectivo cliente Juan`\n" +
      "• O habla natural: _\"Me gasté 18 mil en vinilo por Bancolombia\"_",
    MAIN_MENU_BUTTONS,
  );
}

const HELP_TEXT =
  `🤖 *Menú de Comandos — Pixel App Bot*\n\n` +
  `🎙️ *Puedes hablar por NOTA DE VOZ o escribir natural:*\n` +
  `• _"Me gasté 16 mil en almuerzo pagando por Nequi"_\n` +
  `• _"Vendí unas calcomanías para Pulsar en 60 mil en efectivo"_\n` +
  `• _"Pedido de Carlos kit tanque 80 mil, abonó 30 mil por Daviplata"_\n` +
  `• _"Abrí el local ahora"_ / _"Voy a almorzar"_ / _"Salí a comprar vinilo"_ / _"Cerré el día"_\n` +
  `• _"¿Cómo va la caja hoy?"_\n\n` +
  `⚡ *Comandos rápidos exactos:*\n` +
  `• \`/menu\` — Abrir botones interactivos\n` +
  `• \`/resumen\` — Caja y ventas de hoy\n` +
  `• \`Gasto 15000 comida almuerzo nequi\`\n` +
  `• \`Venta 45000 calcomania tanque efectivo\`\n` +
  `• \`Medida 50x30 vinilo reflectivo cliente Juan\``;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const update = await req.json();

  // 1. Botones interactivos (Callback Query)
  if (update.callback_query) {
    const cb = update.callback_query;
    const data = String(cb.data ?? "");
    const chatId = cb.message?.chat?.id;
    await answerCallbackQuery(cb.id);

    if (!chatId) return new Response(JSON.stringify({ ok: true }), { status: 200 });

    if (data.startsWith("work:open:")) {
      await handleWorkAction(chatId, "open", data.split(":")[2]);
    } else if (data === "work:lunch_start") {
      await handleWorkAction(chatId, "lunch_start");
    } else if (data === "work:errand_start") {
      await handleWorkAction(chatId, "errand_start", undefined, "Diligencia del negocio");
    } else if (data === "work:resume") {
      await handleWorkAction(chatId, "lunch_end");
    } else if (data === "work:close") {
      await handleWorkAction(chatId, "close");
    } else if (data === "info:summary") {
      await sendTelegramReply(chatId, await buildDailySummaryText(), MAIN_MENU_BUTTONS);
    } else if (data === "info:low_stock") {
      await sendTelegramReply(chatId, await buildLowStockText(), MAIN_MENU_BUTTONS);
    } else if (data === "info:help") {
      await sendTelegramReply(chatId, HELP_TEXT, MAIN_MENU_BUTTONS);
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }

  const message = update.message;
  const chatId = message?.chat?.id;
  if (!message || !chatId) return new Response("OK", { status: 200 });

  // 2. Notas de voz / Audios (procesados en segundo plano para responder 200 OK al instante a Telegram)
  const voiceOrAudio = message.voice ?? message.audio;
  if (voiceOrAudio?.file_id) {
    const processVoice = async () => {
      await sendTelegramReply(chatId, "🎙️ _Escuchando nota de voz..._");
      const downloaded = await downloadTelegramFileBase64(voiceOrAudio.file_id);
      if (!downloaded) {
        await sendTelegramReply(chatId, "⚠️ No pude descargar el audio. Intenta de nuevo.");
        return;
      }
      const parsed = await parseAudioWithGemini(
        downloaded.base64,
        downloaded.mimeType,
        GEMINI_API_KEY,
      );
      await executeParsedIntent(chatId, parsed);
    };

    // EdgeRuntime.waitUntil responde 200 OK de inmediato a Telegram evitando "Read timeout expired"
    const runtime = (globalThis as unknown as {
      EdgeRuntime?: { waitUntil: (p: Promise<unknown>) => void };
    }).EdgeRuntime;
    if (runtime?.waitUntil) {
      runtime.waitUntil(processVoice());
    } else {
      await processVoice();
    }
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }

  // 3. Mensajes de texto / comandos de menú
  const text = (message.text ?? "").trim();
  if (!text) return new Response("OK", { status: 200 });

  const lower = text.toLowerCase();
  if (lower === "/start" || lower === "/menu" || lower === "menu" || lower === "hola") {
    await sendTelegramReply(
      chatId,
      "👋 *¡Hola! Soy Pixel App Bot.*\nUsa los botones rápidos o envíame *texto o nota de voz* para registrar gastos, ventas, medidas o tu jornada:",
      MAIN_MENU_BUTTONS,
    );
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }

  if (lower === "/ayuda" || lower === "/help" || lower === "ayuda") {
    await sendTelegramReply(chatId, HELP_TEXT, MAIN_MENU_BUTTONS);
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }

  const parsed = await parseMessageHybrid(text, GEMINI_API_KEY);
  await executeParsedIntent(chatId, parsed);

  return new Response(JSON.stringify({ ok: true }), { status: 200 });
});
