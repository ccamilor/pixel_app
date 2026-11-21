// Parser híbrido (Regex instantáneo + Gemini 2.5 Flash para texto y audio nativo).

export interface ParsedExpense {
  intent: "expense";
  amount: number;
  scope: "business" | "personal";
  payment_method: "cash" | "nequi" | "daviplata" | "bancolombia" | "transfer" | "other";
  category: string;
  subcategory: string;
  description: string;
}

export interface ParsedSale {
  intent: "sale";
  client_name: string;
  title: string;
  total_price: number;
  amount_paid: number;
  payment_method: "cash" | "nequi" | "daviplata" | "bancolombia" | "transfer" | "other";
  notes: string;
}

export interface ParsedWorkAction {
  intent: "work_action";
  action: "open" | "lunch_start" | "lunch_end" | "errand_start" | "close";
  time_iso?: string | null;
  notes?: string | null;
}

export interface ParsedOrderNote {
  intent: "order_note";
  client_name: string;
  title: string;
  width_cm?: number | null;
  height_cm?: number | null;
  material?: string | null;
  notes: string;
}

export interface ParsedSummaryRequest {
  intent: "summary";
}

export interface ParsedUnknown {
  intent: "unknown";
  raw_text: string;
}

export type ParsedMessage =
  | ParsedExpense
  | ParsedSale
  | ParsedWorkAction
  | ParsedOrderNote
  | ParsedSummaryRequest
  | ParsedUnknown;

const GEMINI_SCHEMA_PROMPT = `Eres el asistente de "Pixel App", un taller unipersonal de impresión digital, publicidad y personalización de motos en Colombia (moneda COP).
Analiza el mensaje (texto o audio transcrito) del dueño y devuelve ÚNICAMENTE un objeto JSON válido sin markdown con uno de estos 6 formatos exactos:

1) Gasto:
{"intent":"expense","amount":number,"scope":"business"|"personal","payment_method":"cash"|"nequi"|"daviplata"|"bancolombia"|"transfer"|"other","category":string,"subcategory":string,"description":string}

2) Venta / Pedido con valor:
{"intent":"sale","client_name":string,"title":string,"total_price":number,"amount_paid":number,"payment_method":"cash"|"nequi"|"daviplata"|"bancolombia"|"transfer"|"other","notes":string}
(Si no menciona abono parcial, asume amount_paid = total_price. Si no menciona cliente, usa "Cliente Mostrador".)

3) Control de Jornada:
{"intent":"work_action","action":"open"|"lunch_start"|"lunch_end"|"errand_start"|"close","time_iso":string|null,"notes":string|null}

4) Medida o nota técnica sin precio:
{"intent":"order_note","client_name":string,"title":string,"width_cm":number|null,"height_cm":number|null,"material":string|null,"notes":string}

5) Consulta de resumen / caja / ventas de hoy:
{"intent":"summary"}

6) Si no corresponde a ninguno:
{"intent":"unknown","raw_text":string}`;

function detectPaymentMethod(text: string): ParsedExpense["payment_method"] {
  const lower = text.toLowerCase();
  if (lower.includes("nequi")) return "nequi";
  if (lower.includes("daviplata")) return "daviplata";
  if (lower.includes("bancolombia")) return "bancolombia";
  if (lower.includes("transfer")) return "transfer";
  return "cash";
}

function detectScope(category: string, text: string): "business" | "personal" {
  const lower = `${category} ${text}`.toLowerCase();
  if (
    lower.includes("personal") ||
    lower.includes("almuerzo") ||
    lower.includes("comida") ||
    lower.includes("desayuno")
  ) {
    return "personal";
  }
  return "business";
}

/**
 * Paso 1: Parser determinístico rápido (Regex) sin latencia ni consumo de API.
 */
export function parseWithRegex(rawText: string): ParsedMessage | null {
  const text = rawText.trim();
  const lower = text.toLowerCase();

  if (lower === "/resumen" || lower === "resumen" || lower === "caja") {
    return { intent: "summary" };
  }

  // Ejemplo: "Gasto 15000 comida almuerzo nequi"
  const expenseMatch = text.match(
    /^gasto\s+(\d+(?:[.,]\d+)?)\s+(\S+)(?:\s+(\S+))?(.*)$/i,
  );
  if (expenseMatch) {
    const amount = Number(expenseMatch[1].replace(/[.,](?=\d{3})/g, ""));
    const category = expenseMatch[2];
    const subcategory = expenseMatch[3] ?? "";
    const rest = (expenseMatch[4] ?? "").trim();
    return {
      intent: "expense",
      amount,
      scope: detectScope(category, text),
      payment_method: detectPaymentMethod(text),
      category,
      subcategory,
      description: rest || `${category} ${subcategory}`.trim(),
    };
  }

  // Ejemplo: "Venta 45000 calcomania tanque nequi"
  const saleMatch = text.match(/^venta\s+(\d+(?:[.,]\d+)?)\s+(.+)$/i);
  if (saleMatch) {
    const total = Number(saleMatch[1].replace(/[.,](?=\d{3})/g, ""));
    const detail = saleMatch[2].trim();
    return {
      intent: "sale",
      client_name: "Cliente Mostrador",
      title: detail,
      total_price: total,
      amount_paid: total,
      payment_method: detectPaymentMethod(detail),
      notes: "Registrado desde chat",
    };
  }

  // Ejemplo: "Medida 50x30 vinilo reflectivo cliente Juan"
  const measureMatch = text.match(
    /^medida\s+(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)\s+(.+?)\s+cliente\s+(.+)$/i,
  );
  if (measureMatch) {
    return {
      intent: "order_note",
      width_cm: Number(measureMatch[1]),
      height_cm: Number(measureMatch[2]),
      material: measureMatch[3].trim(),
      client_name: measureMatch[4].trim(),
      title: `Trabajo ${measureMatch[1]}x${measureMatch[2]} (${measureMatch[3].trim()})`,
      notes: text,
    };
  }

  return null;
}

/**
 * Paso 2: Fallback a Gemini 2.5 Flash para texto en lenguaje natural libre.
 */
export async function parseMessageHybrid(
  rawText: string,
  geminiApiKey?: string,
): Promise<ParsedMessage> {
  const regexResult = parseWithRegex(rawText);
  if (regexResult) return regexResult;

  if (!geminiApiKey) {
    return { intent: "unknown", raw_text: rawText };
  }

  return callGeminiJson(
    [
      { text: `${GEMINI_SCHEMA_PROMPT}\n\nMensaje del usuario: "${rawText}"` },
    ],
    geminiApiKey,
    rawText,
  );
}

/**
 * Paso 3: Procesamiento nativo de notas de voz (.ogg / .mp3 / .m4a) con Gemini 2.5 Flash.
 */
export async function parseAudioWithGemini(
  audioBase64: string,
  mimeType: string,
  geminiApiKey?: string,
): Promise<ParsedMessage> {
  if (!geminiApiKey) {
    return { intent: "unknown", raw_text: "Sin GEMINI_API_KEY configurada" };
  }

  return callGeminiJson(
    [
      {
        text: `${GEMINI_SCHEMA_PROMPT}\n\nEscucha este audio en español de Colombia del dueño del taller y devuelve el JSON correspondiente.`,
      },
      {
        inline_data: {
          mime_type: mimeType,
          data: audioBase64,
        },
      },
    ],
    geminiApiKey,
    "[Audio recibido]",
  );
}

async function callGeminiJson(
  parts: Array<Record<string, unknown>>,
  geminiApiKey: string,
  fallbackRaw: string,
): Promise<ParsedMessage> {
  // Más rápido primero; backup solo si el primero falla
  const models = ["gemini-3.1-flash-lite", "gemini-flash-latest"];

  for (const model of models) {
    try {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiApiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts }],
            generationConfig: {
              responseMimeType: "application/json",
              thinkingConfig: { thinkingBudget: 0 },
            },
          }),
        },
      );

      if (!res.ok) continue;

      const data = await res.json();
      const content = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!content) continue;

      return JSON.parse(content) as ParsedMessage;
    } catch {
      continue;
    }
  }

  return { intent: "unknown", raw_text: fallbackRaw };
}
