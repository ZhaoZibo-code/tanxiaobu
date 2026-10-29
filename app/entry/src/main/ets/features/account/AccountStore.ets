import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';

/** A local-only account: it never leaves the device and is not a cloud identity. */
export interface Account {
  nickname: string;
  secretHash: string;
  createdAt: number;
}

const STORE_NAME: string = 'carbon_account';
const KEY_NICKNAME: string = 'nickname';
const KEY_SECRET: string = 'secretHash';
const KEY_CREATED: string = 'createdAt';
const KEY_SAVED_PASSWORD: string = 'savedPassword';
const SALT: string = 'carbon-steps-local-v1';

function toHex(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    const part = bytes[i].toString(16);
    out += part.length === 1 ? `0${part}` : part;
  }
  return out;
}

/** SHA-256 over nickname + password + fixed salt. Never stores the raw password. */
export async function hashSecret(nickname: string, password: string): Promise<string> {
  const md = cryptoFramework.createMd('SHA256');
  const encoder = new util.TextEncoder();
  const payload = encoder.encodeInto(`${nickname}:${password}:${SALT}`);
  await md.update({ data: payload });
  const digest = await md.digest();
  return toHex(digest.data);
}

export async function loadAccount(context: common.UIAbilityContext): Promise<Account | null> {
  const store = await preferences.getPreferences(context, STORE_NAME);
  const nickname = await store.get(KEY_NICKNAME, '') as string;
  if (nickname.length === 0) {
    return null;
  }
  const secretHash = await store.get(KEY_SECRET, '') as string;
  const createdAt = await store.get(KEY_CREATED, 0) as number;
  return { nickname: nickname, secretHash: secretHash, createdAt: createdAt };
}

export async function createAccount(context: common.UIAbilityContext, nickname: string,
  password: string): Promise<Account> {
  const account: Account = {
    nickname: nickname,
    secretHash: await hashSecret(nickname, password),
    createdAt: Date.now()
  };
  const store = await preferences.getPreferences(context, STORE_NAME);
  await store.put(KEY_NICKNAME, account.nickname);
  await store.put(KEY_SECRET, account.secretHash);
  await store.put(KEY_CREATED, account.createdAt);
  await store.flush();
  return account;
}

export async function verifyPassword(account: Account, password: string): Promise<boolean> {
  return account.secretHash === await hashSecret(account.nickname, password);
}

/** Forgets the local account so another one can be created. Records are untouched. */
export async function clearAccount(context: common.UIAbilityContext): Promise<void> {
  const store = await preferences.getPreferences(context, STORE_NAME);
  await store.put(KEY_NICKNAME, '');
  await store.put(KEY_SECRET, '');
  await store.put(KEY_CREATED, 0);
  await store.put(KEY_SAVED_PASSWORD, '');
  await store.flush();
}

/**
 * Optional "log in with one tap" credential. It is only written when the user
 * ticks the remember box, and it stays on this device.
 */
export async function loadSavedPassword(context: common.UIAbilityContext): Promise<string> {
  const store = await preferences.getPreferences(context, STORE_NAME);
  return await store.get(KEY_SAVED_PASSWORD, '') as string;
}

export async function saveSavedPassword(context: common.UIAbilityContext, password: string): Promise<void> {
  const store = await preferences.getPreferences(context, STORE_NAME);
  await store.put(KEY_SAVED_PASSWORD, password);
  await store.flush();
}
