const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const PRIMARY_GEMINI_MODEL =
  Deno.env.get('GEMINI_MODEL') ?? 'gemini-2.5-flash-lite';

const FALLBACK_GEMINI_MODEL = 'gemini-2.5-flash';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders,
    });
  }

  try {
    const geminiKey = Deno.env.get('GEMINI_API_KEY');

    if (!geminiKey) {
      console.log('Missing GEMINI_API_KEY in Supabase secrets.');

      return jsonResponse(
        {
          error: 'Gemini API key is missing.',
        },
        500,
      );
    }

    const body = await req.json();

    const childId = body.childId?.toString().trim() ?? '';
    const userMessage = body.message?.toString().trim() ?? '';
    const history = Array.isArray(body.history) ? body.history : [];

    if (userMessage.length === 0) {
      return jsonResponse(
        {
          error: 'Message is empty.',
        },
        400,
      );
    }

    if (userMessage.length > 800) {
      return jsonResponse(
        {
          error: 'Please ask a shorter question.',
        },
        400,
      );
    }

    const historyText = buildHistoryText(history);

    const systemPrompt = `
You are Marvey, a kind and child-friendly AI helper inside a children's learning app.

Child ID:
${childId}

Rules:
- Answer in simple child-friendly language.
- Keep the answer short and helpful.
- Be warm, positive, and encouraging.
- Help with learning, stories, quizzes, tasks, feelings, and good habits.
- Do not give unsafe, adult, violent, or harmful content.
- If the child asks a math question, show the answer clearly.
`;

    const userPrompt = `
Recent chat:
${historyText}

Child question:
${userMessage}
`;

    const reply = await askGemini(systemPrompt, userPrompt, geminiKey);

    return jsonResponse(
      {
        reply: reply,
      },
      200,
    );
  } catch (error) {
    console.log('Marvey Gemini function failed:', error);

    return jsonResponse(
      {
        error: 'Marvey could not connect right now. Please try again later.',
      },
      500,
    );
  }
});

function buildHistoryText(history: unknown[]) {
  if (!Array.isArray(history) || history.length === 0) {
    return 'No previous messages.';
  }

  const limitedHistory = history.slice(-4);

  const lines = limitedHistory.map((item) => {
    if (typeof item !== 'object' || item === null) {
      return '';
    }

    const message = item as Record<string, unknown>;

    const role = message.role?.toString() ?? 'unknown';
    const text = message.text?.toString() ?? '';

    if (text.trim().length === 0) {
      return '';
    }

    return `${role}: ${text.trim()}`;
  });

  const cleanedLines = lines.filter((line) => line.trim().length > 0);

  if (cleanedLines.length === 0) {
    return 'No previous messages.';
  }

  return cleanedLines.join('\n');
}

async function askGemini(
  systemPrompt: string,
  userPrompt: string,
  geminiKey: string,
) {
  const modelsToTry = [
    PRIMARY_GEMINI_MODEL,
    FALLBACK_GEMINI_MODEL,
  ];

  let lastError = '';

  for (const model of modelsToTry) {
    try {
      const reply = await callGeminiModel(
        model,
        systemPrompt,
        userPrompt,
        geminiKey,
      );

      return reply;
    } catch (error) {
      if (error instanceof Error) {
        lastError = error.message;
      } else {
        lastError = String(error);
      }

      console.log(`Gemini model ${model} failed: ${lastError}`);

      if (lastError.includes('429')) {
        throw new Error(
          'Gemini rate limit reached. Please wait a little and try again.',
        );
      }
    }
  }

  throw new Error(lastError);
}

async function callGeminiModel(
  model: string,
  systemPrompt: string,
  userPrompt: string,
  geminiKey: string,
) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  const requestBody = {
    systemInstruction: {
      parts: [
        {
          text: systemPrompt,
        },
      ],
    },
    contents: [
      {
        role: 'user',
        parts: [
          {
            text: userPrompt,
          },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.6,
      maxOutputTokens: 220,
    },
  };

  const controller = new AbortController();

  const timeoutId = setTimeout(() => {
    controller.abort();
  }, 20000);

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': geminiKey,
      },
      body: JSON.stringify(requestBody),
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    const data = await response.json();

    if (!response.ok) {
      throw new Error(`Gemini error ${response.status}: ${JSON.stringify(data)}`);
    }

    const parts = data?.candidates?.[0]?.content?.parts;

    if (Array.isArray(parts)) {
      const text = parts
        .map((part) => part?.text ?? '')
        .join('')
        .trim();

      if (text.length > 0) {
        return text;
      }
    }

    throw new Error('Gemini returned an empty reply.');
  } catch (error) {
    clearTimeout(timeoutId);
    throw error;
  }
}

function jsonResponse(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status: status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}