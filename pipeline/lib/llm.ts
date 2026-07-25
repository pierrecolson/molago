import Anthropic from '@anthropic-ai/sdk';

const MODEL = process.env.MOLAGO_LLM_MODEL ?? 'claude-opus-5';

let client: Anthropic | null = null;
function anthropic(): Anthropic {
  if (!client) client = new Anthropic();
  return client;
}

export interface LlmUsage {
  input_tokens: number;
  output_tokens: number;
}

/**
 * Appel LLM avec sortie structurée forcée via tool_use.
 * Rend l'objet validé par le schéma + l'usage (pour generation_meta).
 */
export async function llmJson<T>(opts: {
  system: string;
  user: string;
  schema: Record<string, unknown>;
  maxTokens?: number;
}): Promise<{ data: T; usage: LlmUsage }> {
  const response = await anthropic().messages.create({
    model: MODEL,
    max_tokens: opts.maxTokens ?? 4096,
    system: opts.system,
    messages: [{ role: 'user', content: opts.user }],
    tools: [
      {
        name: 'emit',
        description: 'Rend le résultat structuré.',
        input_schema: opts.schema as Anthropic.Tool['input_schema'],
      },
    ],
    tool_choice: { type: 'tool', name: 'emit' },
  });
  const block = response.content.find((b) => b.type === 'tool_use');
  if (!block || block.type !== 'tool_use') throw new Error('LLM : pas de sortie structurée');
  return {
    data: block.input as T,
    usage: {
      input_tokens: response.usage.input_tokens,
      output_tokens: response.usage.output_tokens,
    },
  };
}
