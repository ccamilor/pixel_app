import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { parseMessageHybrid } from "../_shared/hybrid_parser.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const VERIFY_TOKEN = Deno.env.get("WHATSAPP_VERIFY_TOKEN") ?? "";
const WHATSAPP_TOKEN = Deno.env.get("WHATSAPP_ACCESS_TOKEN") ?? "";
const PHONE_NUMBER_ID = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

async function sendWhatsAppText(to: string, body: string) {
  if (!WHATSAPP_TOKEN || !PHONE_NUMBER_ID) return;
  await fetch(`https://graph.facebook.com/v21.0/${PHONE_NUMBER_ID}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${WHATSAPP_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to,
      type: "text",
      text: { body },
    }),
  });
}

Deno.serve(async (req) => {
  // Verificación inicial del webhook de Meta WhatsApp Cloud API
  if (req.method === "GET") {
    const url = new URL(req.url);
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");
    if (mode === "subscribe" && token === VERIFY_TOKEN) {
      return new Response(challenge ?? "", { status: 200 });
    }
    return new Response("Forbidden", { status: 403 });
  }

  const body = await req.json();
  const msg = body?.entry?.[0]?.changes?.[0]?.value?.messages?.[0];
  if (!msg) return new Response("OK", { status: 200 });

  const from = msg.from as string;
  const text =
    msg.type === "text"
      ? msg.text?.body
      : msg.type === "interactive"
      ? msg.interactive?.button_reply?.id
      : undefined;

  if (!text) return new Response("OK", { status: 200 });

  const parsed = await parseMessageHybrid(text, GEMINI_API_KEY);
  if (parsed.intent === "expense") {
    await supabase.from("expenses").insert({
      amount: parsed.amount,
      scope: parsed.scope,
      payment_method: parsed.payment_method,
      category: parsed.category,
      subcategory: parsed.subcategory,
      description: parsed.description,
      source: "whatsapp",
    });
    await sendWhatsAppText(
      from,
      `✅ Gasto registrado: $${parsed.amount.toLocaleString("es-CO")} (${parsed.category} - ${parsed.payment_method}).`,
    );
  } else {
    await sendWhatsAppText(
      from,
      'Mensaje recibido. Ejemplos válidos:\n- "Gasto 18000 comida almuerzo nequi"\n- "Medida 50x30 vinilo reflectivo cliente Juan"',
    );
  }

  return new Response(JSON.stringify({ ok: true }), { status: 200 });
});
