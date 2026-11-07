/**
 * Recording transactions from chat: parse locally, ask the LLM only about what is
 * unsure, keep the result as a pending confirmation, apply edits, then save.
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { AIProvider } from '../providers/base.ts';
import type { AgentResponse, ActionButton } from '../types.ts';
import type { UserContext } from '../data/users.ts';
import * as pendingData from '../data/pending.ts';
import * as transactionData from '../data/transactions.ts';
import { findAmounts } from '../nlu/amount.ts';
import { addDays, parseDate } from '../nlu/date.ts';
import { type Cat, cashWallet, findWallet, scoreCategories } from '../nlu/match.ts';
import { type ParsedTx, parseTransactions } from '../nlu/parse.ts';
import { normalize } from '../nlu/text.ts';
import { parseEdit, parseFallback, pickCategories } from '../llm/resolve.ts';

export interface FlowDeps {
  supabase: SupabaseClient;
  /** null in regex mode or when no LLM is configured. */
  ai: AIProvider | null;
  ctx: UserContext;
  platform: pendingData.Platform;
  conversationId: string;
}

type Item = pendingData.PendingItem;
type Pending = pendingData.Pending;

const rp = (n: number) => `Rp ${Math.round(n).toLocaleString('id-ID')}`;
const dayLabel = (date: string) =>
  new Date(`${date}T00:00:00Z`).toLocaleDateString('id-ID', {
    timeZone: 'UTC', weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
  });

function toItem(t: ParsedTx): Item {
  return {
    type: t.type,
    amount: t.amount,
    date: t.date,
    category_id: t.category?.id ?? null,
    category_name: t.category?.name ?? null,
    category_parent: t.category?.parent_name ?? null,
    wallet_id: t.wallet?.id ?? null,
    wallet_name: t.wallet?.name ?? null,
    to_wallet_id: t.toWallet?.id ?? null,
    to_wallet_name: t.toWallet?.name ?? null,
    notes: t.notes,
    candidates: t.type !== 'transfer' && !t.categorySure
      ? t.candidates.slice(0, 3).map((c) => ({ id: c.id, name: c.name }))
      : undefined,
  };
}

function setCategory(item: Item, c: Cat): void {
  item.category_id = c.id;
  item.category_name = c.name;
  item.category_parent = c.parent_name;
  item.candidates = undefined;
}

/** What the user still has to answer for this item, if anything. */
function missing(item: Item): 'from_wallet' | 'to_wallet' | 'category' | null {
  if (!item.wallet_id) return 'from_wallet';
  if (item.type === 'transfer' && !item.to_wallet_id) return 'to_wallet';
  if (item.type !== 'transfer' && !item.category_id) return 'category';
  return null;
}

// ---------- new message with amounts ----------

export async function record(text: string, d: FlowDeps): Promise<AgentResponse> {
  const { ctx, ai } = d;
  const history = await transactionData.getHistory(d.supabase, ctx.userId);
  const parsed = parseTransactions(text, { categories: ctx.categories, wallets: ctx.wallets, history, today: ctx.today });
  let items = parsed.map(toItem);

  if (!items.length && ai) {
    try {
      items = (await parseFallback(ai, text, ctx.categories, ctx.wallets)).map((t) => fromLlm(t, ctx));
    } catch (e) {
      console.error('[flow] LLM fallback failed:', e);
    }
  }
  if (!items.length) {
    return {
      type: 'error',
      content: '🤔 Nominalnya belum kebaca.\n\nContoh:\n• <code>makan siang 25rb</code>\n• <code>kopi 15k gopay kemarin</code>\n• <code>gaji 7,5jt bca</code>',
    };
  }

  // one LLM call for every unsure category in the message, with only its top candidates
  const unsure = parsed.map((t, i) => ({ t, i })).filter(({ t }) => t.type !== 'transfer' && !t.categorySure);
  if (ai && unsure.length) {
    try {
      const picked = await pickCategories(
        ai,
        unsure.map(({ t, i }) => ({ i, text: t.source, type: t.type as 'income' | 'expense', candidates: t.candidates })),
        ctx.categories,
      );
      for (const [i, cat] of picked) setCategory(items[i], cat);
    } catch (e) {
      console.error('[flow] LLM category pick failed, asking the user instead:', e);
    }
  }
  // nothing matched at all: offer the categories this user uses most for that type
  for (const it of items) {
    if (it.type === 'transfer' || it.category_id || it.candidates?.length) continue;
    const uses = new Map<string, number>();
    for (const h of history) if (h.category_id) uses.set(h.category_id, (uses.get(h.category_id) ?? 0) + 1);
    it.candidates = ctx.categories.filter((c) => c.type === it.type)
      .sort((a, b) => (uses.get(b.id) ?? 0) - (uses.get(a.id) ?? 0))
      .slice(0, 4).map((c) => ({ id: c.id, name: c.name }));
  }

  return await show({ items, choices: [], original_input: text }, d, false);
}

function fromLlm(t: import('../llm/resolve.ts').LlmTx, ctx: UserContext): Item {
  const byName = <T extends { name: string }>(list: T[], name?: string) =>
    name ? list.find((x) => normalize(x.name) === normalize(name)) ?? null : null;
  const cat = t.type === 'transfer' ? null : byName(ctx.categories.filter((c) => c.type === t.type), t.category) ?? byName(ctx.categories, t.category);
  const wallet = byName(ctx.wallets, t.wallet) ?? (t.wallet ? findWallet(t.wallet, ctx.wallets)?.wallet : null) ??
    (t.type === 'transfer' ? null : cashWallet(ctx.wallets));
  const to = t.type === 'transfer' ? byName(ctx.wallets, t.to_wallet) ?? (t.to_wallet ? findWallet(t.to_wallet, ctx.wallets)?.wallet ?? null : null) : null;
  return {
    type: t.type, amount: Math.round(Number(t.amount)), date: addDays(ctx.today, Number(t.day_offset ?? 0)),
    category_id: cat?.id ?? null, category_name: cat?.name ?? null, category_parent: cat?.parent_name ?? null,
    wallet_id: wallet?.id ?? null, wallet_name: wallet?.name ?? null,
    to_wallet_id: to?.id ?? null, to_wallet_name: to?.name ?? null,
    notes: t.notes?.trim() || cat?.name || 'Transaksi',
  };
}

// ---------- rendering + saving the pending state ----------

async function show(p: Pending, d: FlowDeps, updated: boolean): Promise<AgentResponse> {
  const focusIndex = p.items.findIndex((it) => missing(it) || it.candidates?.length);
  const focus = p.items[focusIndex];
  const actions: ActionButton[] = [];
  const need = focus ? missing(focus) : null;

  if (need === 'from_wallet' || need === 'to_wallet') {
    const exclude = need === 'to_wallet' ? focus.wallet_id : focus.to_wallet_id;
    for (const w of d.ctx.wallets.filter((w) => w.id !== exclude).slice(0, 6)) {
      actions.push({ text: `💳 ${w.name}`, action: `pick_wallet:${w.id}` });
    }
  } else if (focus?.candidates?.length) {
    for (const c of focus.candidates) {
      if (c.id !== focus.category_id) actions.push({ text: `📁 ${c.name}`, action: `pick_cat:${c.id}` });
    }
  }
  const canSave = p.items.every((it) => !missing(it));
  if (canSave) actions.push({ text: p.items.length > 1 ? '✅ Simpan semua' : '✅ Simpan', action: 'confirm_yes' });
  actions.push({ text: '❌ Batal', action: 'confirm_no' });
  p.choices = actions.map((a) => a.action);

  const { error } = await pendingData.save(d.supabase, d.ctx.userId, d.platform, d.conversationId, p);
  if (error) {
    console.error('[flow] save pending failed:', error);
    return { type: 'error', content: `❌ Gagal menyimpan sementara: ${error.message}` };
  }

  let msg = p.items.length === 1 ? renderOne(p.items[0], updated) : renderMany(p.items, updated);
  if (need === 'from_wallet') msg += `\n\n👇 Dari wallet mana${p.items.length > 1 ? ` (no. ${focusIndex + 1})` : ''}?`;
  else if (need === 'to_wallet') msg += `\n\n👇 Ke wallet mana${p.items.length > 1 ? ` (no. ${focusIndex + 1})` : ''}?`;
  else if (focus?.candidates?.length) {
    msg += `\n\n👇 Kategori${p.items.length > 1 ? ` no. ${focusIndex + 1}` : ''} sudah benar? Pilih lain di bawah, atau ketik nama kategorinya.`;
  } else msg += p.items.length > 1 ? '\n\nSimpan semua?' : '\n\nSimpan transaksi ini?';
  return { type: 'confirmation', content: msg, data: p, actions };
}

function label(it: Item): { emoji: string; title: string } {
  if (it.type === 'transfer') return { emoji: '🔄', title: 'Transfer' };
  return it.type === 'income' ? { emoji: '💰', title: 'Pemasukan' } : { emoji: '💸', title: 'Pengeluaran' };
}
const catText = (it: Item) =>
  it.category_name ? `${it.category_parent ? `${it.category_parent} › ` : ''}${it.category_name}${it.candidates?.length ? ' ❓' : ''}` : '❓';

function renderOne(it: Item, updated: boolean): string {
  const { emoji, title } = label(it);
  let m = `${emoji} <b>${title}${updated ? ' (diperbarui)' : ''}</b>\n\n📅 ${dayLabel(it.date)}\n`;
  if (it.type === 'transfer') m += `📤 Dari: ${it.wallet_name ?? '❓'}\n📥 Ke: ${it.to_wallet_name ?? '❓'}\n`;
  else m += `💳 ${it.wallet_name ?? '❓'}\n`;
  m += `💵 ${rp(it.amount)}\n`;
  if (it.type !== 'transfer') m += `📁 ${catText(it)}\n`;
  return m + `📝 ${it.notes}`;
}

function renderMany(items: Item[], updated: boolean): string {
  const sameDate = items.every((it) => it.date === items[0].date);
  let m = `🧾 <b>${items.length} transaksi${updated ? ' (diperbarui)' : ''}</b>\n`;
  if (sameDate) m += `📅 ${dayLabel(items[0].date)}\n`;
  items.forEach((it, i) => {
    const where = it.type === 'transfer'
      ? `${it.wallet_name ?? '❓'} → ${it.to_wallet_name ?? '❓'}`
      : `${catText(it)} · ${it.wallet_name ?? '❓'}`;
    m += `\n${i + 1}. ${label(it).emoji} ${rp(it.amount)} · ${where}\n    ${it.notes}${sameDate ? '' : ` · ${it.date.slice(8)}/${it.date.slice(5, 7)}`}`;
  });
  const total = items.reduce((s, it) => s + (it.type === 'income' ? it.amount : it.type === 'expense' ? -it.amount : 0), 0);
  if (items.some((it) => it.type !== 'transfer')) m += `\n\nTotal: ${total < 0 ? '−' : '+'}${rp(Math.abs(total))}`;
  return m;
}

// ---------- replies while something is pending ----------

export async function pick(field: 'category' | 'wallet', id: string, p: Pending, d: FlowDeps): Promise<AgentResponse> {
  const i = p.items.findIndex((it) => missing(it) || it.candidates?.length);
  const it = p.items[i < 0 ? 0 : i];
  if (field === 'category') {
    const c = d.ctx.categories.find((x) => x.id === id);
    if (!c) return { type: 'error', content: '❌ Kategori tidak ditemukan.' };
    setCategory(it, c);
  } else {
    const w = d.ctx.wallets.find((x) => x.id === id);
    if (!w) return { type: 'error', content: '❌ Wallet tidak ditemukan.' };
    if (missing(it) === 'to_wallet') { it.to_wallet_id = w.id; it.to_wallet_name = w.name; }
    else { it.wallet_id = w.id; it.wallet_name = w.name; }
  }
  return await show(p, d, true);
}

const ORDINALS: Record<string, number> = { pertama: 1, kedua: 2, ketiga: 3, keempat: 4, kelima: 5, terakhir: -1 };

/** "yang kedua 25rb", "kategorinya minuman", "pakai bca", "kemarin", "catatan beli galon". */
export async function edit(text: string, p: Pending, d: FlowDeps): Promise<AgentResponse> {
  const { ctx } = d;
  const t = text.toLowerCase();
  let index: number | null = null;
  const num = t.match(/\b(?:no|nomor|yang|item|ke)\.?\s*-?\s*(\d)\b/);
  if (num) index = Number(num[1]) - 1;
  for (const [w, n] of Object.entries(ORDINALS)) if (new RegExp(`\\b${w}\\b`).test(t)) index = n < 0 ? p.items.length - 1 : n - 1;
  if (index !== null && !p.items[index]) return { type: 'error', content: `❌ Tidak ada transaksi nomor ${index + 1}.` };
  const rest = num ? text.replace(num[0], ' ') : text;

  const changes: Partial<Item> = {};
  const noteM = rest.match(/\b(?:catatan|keterangan|ket|notes?|deskripsi)(?:nya)?\s*:?\s*(.+)$/i);
  if (noteM) changes.notes = noteM[1].trim();
  const scan = noteM ? rest.slice(0, noteM.index) : rest;

  const amount = findAmounts(scan)[0];
  if (amount) changes.amount = amount.amount;
  const date = parseDate(scan, ctx.today);
  if (date) changes.date = date.date;

  const target = index !== null ? [p.items[index]] : p.items;
  const isTransfer = target.every((it) => it.type === 'transfer');
  const toM = scan.match(/\b(?:ke|tujuan)\s+(.+)$/i);
  const toW = isTransfer && toM ? findWallet(toM[1], ctx.wallets) : null;
  const fromW = findWallet(toW ? scan.slice(0, toM!.index) : scan, ctx.wallets);
  if (toW) { changes.to_wallet_id = toW.wallet.id; changes.to_wallet_name = toW.wallet.name; }
  if (fromW) { changes.wallet_id = fromW.wallet.id; changes.wallet_name = fromW.wallet.name; }

  let cat: Cat | null = null;
  const catWord = scan.match(/\bkategori(?:nya)?\s*:?\s*(.+)$/i);
  const catSource = catWord ? catWord[1] : scan;
  const exact = ctx.categories.filter((c) => ` ${normalize(catSource)} `.includes(` ${normalize(c.name)} `))
    .sort((a, b) => b.name.length - a.name.length)[0];
  if (exact) cat = exact;
  else if (catWord) cat = scoreCategories(catWord[1], ctx.categories, [])[0]?.category ?? null;

  const understood = Object.keys(changes).length > 0 || cat;
  if (!understood) {
    if (d.ai) {
      try {
        return await applyLlmEdit(text, p, d);
      } catch (e) {
        console.error('[flow] LLM edit failed:', e);
      }
    }
    return {
      type: 'error',
      content: '🤔 Perubahannya belum kebaca. Contoh:\n• <code>kategorinya Minuman</code>\n• <code>pakai BCA</code>\n• <code>nominalnya 30rb</code>\n• <code>kemarin</code>\n• <code>catatan beli galon</code>' +
        (p.items.length > 1 ? '\n• <code>yang kedua 25rb</code>' : ''),
    };
  }

  // amount/category/notes need a target in a batch; wallet/date may apply to all
  const perItemOnly = changes.amount !== undefined || cat || changes.notes !== undefined;
  if (perItemOnly && index === null && p.items.length > 1) {
    return { type: 'error', content: `Sebutkan nomornya, mis. <code>yang ${p.items.length} ${text}</code>` };
  }
  for (const it of target) {
    Object.assign(it, changes);
    if (cat && it.type !== 'transfer') {
      if (cat.type !== it.type) it.type = cat.type; // "kategorinya Gaji" turns it into income
      setCategory(it, cat);
    }
  }
  return await show(p, d, true);
}

async function applyLlmEdit(text: string, p: Pending, d: FlowDeps): Promise<AgentResponse> {
  const summary = p.items.map((it, i) =>
    `${i + 1}. ${it.type} ${it.amount} ${it.category_name ?? '-'} ${it.wallet_name ?? '-'}${it.to_wallet_name ? `→${it.to_wallet_name}` : ''} ${it.date} "${it.notes}"`
  ).join('\n');
  const e = await parseEdit(d.ai!, text, summary);
  const it = p.items[(e.item ?? 1) - 1] ?? p.items[0];
  const byName = <T extends { name: string }>(list: T[], n?: string) => n ? list.find((x) => normalize(x.name) === normalize(n)) : undefined;
  if (e.amount) it.amount = Math.round(Number(e.amount));
  if (e.notes) it.notes = e.notes;
  if (e.day_offset !== undefined) it.date = addDays(d.ctx.today, Number(e.day_offset));
  const w = byName(d.ctx.wallets, e.wallet) ?? (e.wallet ? findWallet(e.wallet, d.ctx.wallets)?.wallet : undefined);
  if (w) { it.wallet_id = w.id; it.wallet_name = w.name; }
  const to = byName(d.ctx.wallets, e.to_wallet);
  if (to) { it.to_wallet_id = to.id; it.to_wallet_name = to.name; }
  const c = byName(d.ctx.categories, e.category);
  if (c && it.type !== 'transfer') { it.type = c.type; setCategory(it, c); }
  return await show(p, d, true);
}

export async function confirm(p: Pending, d: FlowDeps): Promise<AgentResponse> {
  const blocked = p.items.findIndex((it) => missing(it));
  if (blocked >= 0) return await show(p, d, false);

  const failed: Item[] = [];
  const errors: string[] = [];
  for (const it of p.items) {
    const { error } = it.type === 'transfer'
      ? await transactionData.createTransfer(d.supabase, d.ctx.userId, {
        amount: it.amount, date: it.date, notes: it.notes, from_wallet_id: it.wallet_id!, to_wallet_id: it.to_wallet_id!,
        expense_category_id: null, income_category_id: null,
      })
      : await transactionData.create(d.supabase, d.ctx.userId, {
        amount: it.amount, date: it.date, notes: it.notes, category_id: it.category_id!, wallet_id: it.wallet_id!,
      });
    if (error) { failed.push(it); errors.push(error.message); }
  }

  if (!failed.length) {
    await pendingData.remove(d.supabase, d.ctx.userId, d.platform);
    return { type: 'message', content: p.items.length > 1 ? `✅ <b>${p.items.length} transaksi disimpan.</b>` : '✅ <b>Transaksi disimpan.</b>' };
  }
  // keep only what failed, so "ya" again does not duplicate the saved ones
  const saved = p.items.length - failed.length;
  const res = await show({ ...p, items: failed }, d, false);
  res.content = `⚠️ ${saved ? `${saved} tersimpan, ` : ''}${failed.length} gagal: ${errors[0]}\n\n${res.content}`;
  return res;
}

export async function cancel(d: FlowDeps): Promise<AgentResponse> {
  await pendingData.remove(d.supabase, d.ctx.userId, d.platform);
  return { type: 'message', content: '❌ Dibatalkan.' };
}

