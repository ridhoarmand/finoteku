# Finoteku Agent

Agent keuangan pribadi untuk Telegram/WhatsApp di Supabase Edge Functions. Mencatat
transaksi dari chat **tanpa LLM** (aturan + belajar dari riwayat user), dan memakai LLM hanya
untuk bagian yang ragu, dengan prompt kecil.

## ✨ Fitur

- 🧩 **Lokal dulu, LLM cadangan**: nominal, tanggal, wallet, tipe, dan kategori dibaca dengan aturan.
  LLM dipanggil hanya bila kategori ragu (berisi ≤6 kandidat, bukan semua kategori), atau bila
  nominal tidak terbaca. Mode **RegEx** di aplikasi = tidak pernah memakai LLM.
- 🧠 **Belajar dari riwayat**: kata di catatan 300 transaksi terakhir → kategori/wallet yang biasa
  dipakai user. Koreksi yang disimpan otomatis ikut dipelajari, tanpa tabel tambahan.
- 🧾 **Banyak transaksi per pesan**: `makan 20k, kopi 15k pakai gopay kemarin`.
- 📅 **Tanggal bebas**: kemarin, lusa, `3 hari lalu`, `senin`, `tgl 5`, `5/11`, di zona waktu user.
- ✏️ **Ubah sebelum simpan**: `kategorinya Minuman`, `pakai BCA`, `yang kedua 25rb`, `kemarin`.
- 💬 **Multi-input**: teks, voice note dan foto struk (1 panggilan LLM untuk jadi teks).
- 📊 **Query keuangan**: saldo, ringkasan, riwayat, tren, tips (tanpa LLM); pertanyaan bebas
  dijawab dari angka ringkas.

## 🛠️ Teknologi

- **Runtime**: Deno
- **Platform**: Supabase Edge Functions
- **Database**: Supabase PostgreSQL
- **AI**: 9Router (OpenAI-compatible), opsional
- **Bot**: Telegram

## 📁 Struktur Proyek

```
supabase/
├── schema.sql                     # Dump schema (tables, RPC, triggers, RLS)
├── migrations/                    # Perubahan schema setelah dump (jalankan berurutan)
├── tests/balance_triggers.sql     # Cek trigger saldo (psql, di-rollback)
└── functions/
    ├── finoteku-agent/
    │   ├── index.ts               # HTTP endpoint (hanya menerima service key)
    │   ├── agent.ts               # Pilih LLM per user, media → teks, routing
    │   ├── router.ts              # Intent dengan aturan
    │   ├── flow/transaction.ts    # Parse → pending → ubah/pilih → simpan
    │   ├── nlu/                   # Parser lokal: amount, date, match, parse (+ test)
    │   ├── llm/resolve.ts         # Satu-satunya panggilan LLM untuk transaksi
    │   ├── data/                  # Akses data Supabase
    │   ├── providers/             # 9Router (OpenAI-compatible)
    │   └── tools/                 # Query: saldo, ringkasan, riwayat, tren, tips, tanya data
    ├── telegram-bot/              # Webhook Telegram
    └── whatsapp-bot/              # Webhook GOWA (WhatsApp)
```

## 🧠 Cara agent membaca pesan

1. `router.ts` menentukan jenis pesan: transaksi, pertanyaan, atau balasan untuk transaksi pending.
2. `nlu/parse.ts` membaca transaksi (juga format template emoji 📁💳💵📝) dan memberi skor kategori dari
   contoh pelatihan user (`agent_training`), riwayat user, nama kategori, dan kamus sinonim (`nlu/match.ts`).
3. Kalau kategori kurang yakin: mode AI → `llm/resolve.ts` memilih dari kandidat; mode RegEx →
   user memilih lewat tombol (WhatsApp: balas angka).
4. Hasil disimpan sebagai pending (`pending_bot_transactions.payload`) sampai user membalas `ya`.

### Test

```bash
bun test supabase/functions/finoteku-agent   # parser + skenario agent (Supabase palsu)
```

## 📋 Prerequisites

- [Deno](https://deno.land/) installed
- [Supabase CLI](https://supabase.com/docs/guides/cli) installed
- Supabase project created
- Telegram Bot Token dari [@BotFather](https://t.me/botfather)
- Key 9Router (opsional)

## 🚀 Setup dari Awal

### 1. Buat Supabase Project

1. Buka [supabase.com](https://supabase.com) dan buat project baru
2. Catat **Project Reference** dan **Database Password**

### 2. Clone Repository

```bash
git clone https://github.com/ridhoarmand/finoteku-agent.git
cd finoteku-agent
```

### 3. Link ke Supabase Project

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
# Masukkan database password saat diminta
```

### 4. Setup Database Schema

Jalankan `supabase/schema.sql`, lalu semua file di `supabase/migrations/` berurutan.

File `supabase/schema.sql` berisi semua:

- Tables (users, wallets, categories, transactions, transfers, bot_links, user_preferences, dll)
- Functions (link_telegram_account, get_user_by_platform_id, create_wallet_transfer, dll)
- Triggers (update_wallet_balance, handle_transfer, dll)
- Views (ledger_entries)
- RLS Policies

Jalankan schema di Supabase:

```bash
# Opsi 1: Push langsung
supabase db push

# Opsi 2: Jalankan manual di SQL Editor
# Buka Supabase Dashboard → SQL Editor
# Copy-paste isi file supabase/schema.sql
# Klik Run
```

### 5. Set Secrets

```bash
supabase secrets set TELEGRAM_BOT_TOKEN=your_telegram_bot_token
supabase secrets set TELEGRAM_WEBHOOK_SECRET=$(openssl rand -hex 32)
supabase secrets set AI_API_KEY=your_9router_key   # opsional: tanpa ini hanya mode Tanpa AI
```

> **Note**: `SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` otomatis tersedia di Supabase Edge
> Functions.

### 6. Deploy Functions

```bash
supabase functions deploy finoteku-agent --no-verify-jwt
supabase functions deploy telegram-bot --no-verify-jwt
```

### 7. Set Telegram Webhook

```bash
# Ganti <YOUR_BOT_TOKEN> dan <YOUR_PROJECT_REF>
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/telegram-bot", "secret_token": "<TELEGRAM_WEBHOOK_SECRET>"}'
```

### 8. Verifikasi Webhook

```bash
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo"
```

## 💬 Penggunaan

### Commands

- `/start` - Memulai bot
- `/help` - Panduan penggunaan
- `/balance` - Cek saldo
- `/history` - Riwayat transaksi

### Catat Transaksi

- `kopi 15k` - Pengeluaran
- `gaji 5jt mandiri` - Pemasukan
- `bensin 100k kemarin` - Dengan tanggal

### Query Keuangan

- `berapa saldo?` - Cek saldo
- `ringkasan bulan ini` - Monthly summary
- `riwayat` - Transaksi terakhir

### Media

- 📸 Kirim foto struk/nota
- 🎤 Kirim voice note

## 🔧 Environment Variables

| Variable                  | Description                                                  | Required |
| ------------------------- | ------------------------------------------------------------ | -------- |
| `TELEGRAM_BOT_TOKEN`      | Token dari BotFather                                         | ✅       |
| `TELEGRAM_WEBHOOK_SECRET` | Sama dengan `secret_token` di setWebhook; request lain ditolak | ✅     |
| `GOWA_WEBHOOK_SECRET`     | Secret HMAC webhook GOWA (WhatsApp); tanpa ini WA menolak semua | WA     |
| `AI_API_KEY`              | Key 9Router (OpenAI-compatible) untuk mode AI; tanpa ini semua user jalan Tanpa AI | Opsional |
| `AI_BASE_URL` / `AI_MODEL` | Default `https://9router.idho.eu.org/v1` / `my-combo`        | Opsional |

## 🗄️ Database Schema

File `supabase/schema.sql` berisi definisi lengkap. Tabel utama:

| Table                      | Deskripsi                         |
| -------------------------- | --------------------------------- |
| `users`                    | Data user (dari auth.users)       |
| `wallets`                  | Wallet/dompet user                |
| `categories`               | Kategori income/expense           |
| `transactions`             | Transaksi keuangan                |
| `transfers`                | Transfer antar wallet             |
| `bot_links`                | Link akun ke Telegram             |
| `pending_bot_transactions` | Transaksi pending (belum konfirm) |
| `user_preferences`         | Preferensi yang dipelajari AI     |

### Database Functions (RPC)

| Function                     | Deskripsi                  |
| ---------------------------- | -------------------------- |
| `get_user_by_platform_id`    | Cari user by Telegram ID   |
| `link_telegram_account`      | Link akun Telegram ke user |
| `create_wallet_transfer`     | Buat transfer antar wallet |
| `recalculate_wallet_balance` | Hitung ulang saldo wallet  |

## 🐛 Troubleshooting

### Function tidak menerima updates

```bash
# Cek webhook
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"

# Cek logs
supabase functions logs telegram-bot --tail
```

### AI parsing error

```bash
# Pastikan secrets sudah diset
supabase secrets list
```

### Database schema error

```bash
# Dump ulang schema dari production
supabase db dump --schema public -f supabase/schema.sql
```

## 📄 License

MIT License

## 👨‍💻 Author

**Ridho Armand**

- GitHub: [@ridhoarmand](https://github.com/ridhoarmand)

## 🙏 Acknowledgments

- [Supabase](https://supabase.com/) - Backend & hosting
- [Deno](https://deno.land/) - Runtime
- [Google Gemini](https://ai.google.dev/) - AI
- [Telegram Bot API](https://core.telegram.org/bots/api) - Bot platform
