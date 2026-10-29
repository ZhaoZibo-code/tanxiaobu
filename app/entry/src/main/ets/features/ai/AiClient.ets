import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

/** User-supplied OpenAI-compatible endpoint. Nothing here ships with a key baked in. */
export interface AiConfig {
  baseUrl: string;
  model: string;
  apiKey: string;
}

export const DEFAULT_BASE_URL: string = 'https://market.frostfox.ai/v1';
export const DEFAULT_MODEL: string = 'gpt-6.1-terra';

const STORE_NAME: string = 'carbon_ai_config';
const KEY_BASE_URL: string = 'baseUrl';
const KEY_MODEL: string = 'model';
const KEY_API_KEY: string = 'apiKey';

interface ChatMessage {
  role: string;
  content: string;
}

/** One turn of the on-device conversation. */
export interface ChatTurn {
  role: string;
  content: string;
}

interface ChatChoice {
  message: ChatMessage;
}

interface ChatErrorBody {
  message: string;
}

interface ChatResponse {
  choices: ChatChoice[];
  error: ChatErrorBody;
}

interface ChatRequest {
  model: string;
  messages: ChatMessage[];
  temperature: number;
  max_tokens: number;
  stream: boolean;
}

export function isConfigured(config: AiConfig): boolean {
  return config.baseUrl.length > 0 && config.model.length > 0 && config.apiKey.length > 0;
}

/** Turns raw socket/HTTP errors into something a user can act on. */
export function friendlyAiError(raw: string): string {
  const lower = raw.toLowerCase();
  if (lower.indexOf('resolve') >= 0 || lower.indexOf('host name') >= 0) {
    return '无法解析模型服务地址：请检查设备网络或 DNS。本地建议不受影响，仍在下方。';
  }
  if (lower.indexOf('timeout') >= 0 || lower.indexOf('timed out') >= 0) {
    return '请求超时：模型响应太慢，稍后再试一次。';
  }
  if (lower.indexOf('401') >= 0 || lower.indexOf('invalid api key') >= 0 ||
    lower.indexOf('invalid_api_key') >= 0) {
    return '密钥无效或已过期，请在「设置」里重新填写。';
  }
  if (lower.indexOf('model_not_found') >= 0 || lower.indexOf('model not found') >= 0) {
    return '模型名称不存在，请核对「设置」里的模型名。';
  }
  return raw;
}

function trimTrailingSlash(url: string): string {
  let end = url.length;
  while (end > 0 && url.charAt(end - 1) === '/') {
    end -= 1;
  }
  return url.substring(0, end);
}

export async function loadAiConfig(context: common.UIAbilityContext): Promise<AiConfig> {
  const store = await preferences.getPreferences(context, STORE_NAME);
  const baseUrl = await store.get(KEY_BASE_URL, DEFAULT_BASE_URL) as string;
  const model = await store.get(KEY_MODEL, DEFAULT_MODEL) as string;
  const apiKey = await store.get(KEY_API_KEY, '') as string;
  return { baseUrl: baseUrl, model: model, apiKey: apiKey };
}

export async function saveAiConfig(context: common.UIAbilityContext, config: AiConfig): Promise<void> {
  const store = await preferences.getPreferences(context, STORE_NAME);
  await store.put(KEY_BASE_URL, config.baseUrl);
  await store.put(KEY_MODEL, config.model);
  await store.put(KEY_API_KEY, config.apiKey);
  await store.flush();
}

export async function clearAiConfig(context: common.UIAbilityContext): Promise<void> {
  await saveAiConfig(context, { baseUrl: DEFAULT_BASE_URL, model: '', apiKey: '' });
}

function errorFrom(text: string, code: number): string {
  try {
    const parsed = JSON.parse(text) as ChatResponse;
    if (parsed.error !== undefined && parsed.error !== null && parsed.error.message !== undefined) {
      return `模型服务返回：${parsed.error.message}`;
    }
  } catch (error) {
    // Body was not JSON; fall through to the status code.
  }
  return `模型服务返回 HTTP ${code}。`;
}

/** Network hiccups are worth one more try; auth or model errors are not. */
function looksTransient(message: string): boolean {
  const lower = message.toLowerCase();
  return lower.indexOf('timeout') >= 0 || lower.indexOf('timed out') >= 0 ||
    lower.indexOf('resolve') >= 0 || lower.indexOf('connect') >= 0 ||
    lower.indexOf('socket') >= 0 || lower.indexOf('broken') >= 0;
}

async function requestOnce(config: AiConfig, systemPrompt: string, turns: ChatTurn[]): Promise<string> {
  const request = http.createHttp();
  try {
    const url = `${trimTrailingSlash(config.baseUrl)}/chat/completions`;
    const messages: ChatMessage[] = [{ role: 'system', content: systemPrompt }];
    turns.forEach((turn: ChatTurn) => {
      messages.push({ role: turn.role, content: turn.content });
    });
    const body: ChatRequest = {
      model: config.model,
      messages: messages,
      temperature: 0.6,
      max_tokens: 1200,
      stream: false
    };
    const response = await request.request(url, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.apiKey}`
      },
      extraData: JSON.stringify(body),
      connectTimeout: 30000,
      readTimeout: 90000
    });
    const text = response.result as string;
    if (response.responseCode !== 200) {
      throw new Error(errorFrom(text, response.responseCode));
    }
    const parsed = JSON.parse(text) as ChatResponse;
    if (parsed.choices === undefined || parsed.choices === null || parsed.choices.length === 0) {
      throw new Error('模型没有返回内容。');
    }
    return parsed.choices[0].message.content.trim();
  } finally {
    request.destroy();
  }
}

/**
 * One non-streaming chat completion over a full conversation. Retries once on a
 * transient network failure, then throws a readable Error so the caller can fall
 * back to offline suggestions.
 */
export async function askChat(config: AiConfig, systemPrompt: string, turns: ChatTurn[]): Promise<string> {
  try {
    return await requestOnce(config, systemPrompt, turns);
  } catch (error) {
    const message = (error as Error).message;
    if (!looksTransient(message)) {
      throw new Error(message);
    }
    return await requestOnce(config, systemPrompt, turns);
  }
}

/** Single question shortcut used by the one-sentence recorder. */
export async function askModel(config: AiConfig, systemPrompt: string, question: string): Promise<string> {
  return askChat(config, systemPrompt, [{ role: 'user', content: question }]);
}
