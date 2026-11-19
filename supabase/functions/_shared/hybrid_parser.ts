// Parser híbrido (Regex instantáneo + Gemini Flash API) para Telegram y WhatsApp Cloud API.

export interface ParsedExpense {
  intent: "expense";
  amount: number;
  scope: "business" | "personal";
  payment_method: "cash" | "nequi" | "daviplata" | "bancolombia" | "transfer" | "other";
  category: string;
  subcategory: string;
  description: string;
}

export interface ParsedWorkAction {
  intent: "work_action";
  action: "open" | "lunch_start" | "lunch_end" | "close";
  time_iso?: string;
}

export interface ParsedOrderNote {
  intent: "order_note";
  client_name: string;
  title: string;
  width_cm?: number;
  height_cm?: number;
  material?: string;
  notes: string;
}

export interface ParsedUnknown {
  intent: "unknown";
  raw_text: string;
}

export type ParsedMessage =
  | ParsedExpense
  | ParsedWorkAction
  | ParsedOrderNote
  | ParsedUnknown;

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
 * Paso 1: Parser determinístico rápido (Regex) sin costo de latencia/API.
 * Ejemplo: "Gasto 15000 comida almuerzo nequi"
 */
export function parseWithRegex(rawText: string): ParsedMessage | null {
  const text = rawText.trim();

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
 * Paso 2: Fallback a Gemini Flash API para lenguaje natural libre.
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

  const prompt = `Eres el asistente de un taller de impresión digital y calcomanías de motos en Colombia (moneda COP).
Extrae un único JSON estricto del siguiente mensaje del dueño:
"${rawText}"

Formatos permitidos:
1) {"intent":"expense","amount":number,"scope":"business"|"personal","payment_method":"cash"|"nequi"|"daviplata"|"bancolombia"|"transfer"|"other","category":string,"subcategory":string,"description":string}
2) {"intent":"work_action","action":"open"|"lunch_start"|"lunch_end"|"close","time_iso":string|null}
3) {"intent":"order_note","client_name":string,"title":string,"width_cm":number|null,"height_cm":number|null,"material":string|null,"notes":string}
4) {"intent":"unknown","raw_text":string}
Responde SOLO con JSON válido sin markdown.`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { responseMimeType: "application/json" },
      }),
    },
  );

  if (!res.ok) {
    return { intent: "unknown", raw_text: rawText };
  }

  const data = await res.json();
  const content = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!content) return { intent: "unknown", raw_text: rawText };

  try {
    return JSON.parse(content) as ParsedMessage;
  } catch {
    return { intent: "unknown", raw_text: rawText };
  }
}
