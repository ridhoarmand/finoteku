# Finoteku Agent

AI Agent untuk manajemen keuangan pribadi dengan **adaptive learning** yang berjalan di Supabase
Edge Functions.

## ✨ Fitur

- 🤖 **Agent-based Architecture** - Plan → Execute → Evaluate loop
- 🧠 **Adaptive Learning** - Mempelajari preferensi kategori & wallet dari kebiasaan user
- 📝 **Notes Style Learning** - AI mengikuti gaya penulisan notes user
- 💬 **Multi-input** - Text, Voice (STT), dan Image (OCR)
- 📊 **Query Keuangan** - Saldo, ringkasan, tren, tips hemat
- 🤖 **Telegram Bot** - Integrasi dengan Telegram Bot API

## 🛠️ Teknologi

- **Runtime**: Deno
- **Platform**: Supabase Edge Functions
- **Database**: Supabase PostgreSQL
- **AI**: Google Gemini
- **Bot**: Telegram

## 📁 Struktur Proyek

```
finoteku-agent/
├── supabase/
│   ├── schema.sql                      # Database schema (tables, functions, triggers)
│   └── functions/
│       ├── finoteku-agent/             # Core AI Agent
│       │   ├── index.ts                # HTTP endpoint
│       │   ├── agent.ts                # Orchestrator utama
│       │   ├── executor.ts             # Loop Plan-Execute-Evaluate
│       │   ├── reasoning.ts            # Deteksi intent & planning
│       │   ├── types.ts                # Definisi tipe
│       │   ├── data/                   # Data Access Layer
│       │   │   ├── users.ts            # User context
│       │   │   ├── categories.ts       # Kategori
│       │   │   ├── wallets.ts          # Wallet & saldo
│       │   │   ├── transactions.ts     # Transaksi CRUD
│       │   │   └── pending.ts          # Transaksi pending
│       │   ├── memory/                 # Learning System
│       │   │   └── learning.ts         # PreferenceLearner
│       │   ├── providers/              # AI Providers
│       │   │   ├── base.ts             # Interface provider
│       │   │   └── gemini.ts           # Google Gemini
│       │   └── tools/                  # Agent Tools
│       │       ├── base.ts             # Tool registry
│       │       ├── parser/text.ts      # Text parser (with learning)
│       │       ├── parser/regex.ts     # Regex fallback
│       │       ├── scanner.ts          # OCR image scanner
│       │       ├── stt.ts              # Speech-to-text
│       │       ├── pending.ts          # Handler konfirmasi/batal
│       │       ├── balance.ts          # Query saldo
│       │       ├── summary.ts          # Ringkasan bulanan
│       │       ├── history.ts          # Riwayat transaksi
│       │       ├── trend.ts            # Tren pengeluaran
│       │       └── tips.ts             # Tips hemat
│       └── telegram-bot/               # Telegram webhook
│           ├── index.ts                # Webhook handler
│           └── telegram.ts             # Telegram API utils
└── deno.json                           # Konfigurasi Deno
```

## 🧠 Adaptive Learning System

Agent mempelajari preferensi user dari waktu ke waktu:

### 1. Category Learning

```
User: "beli kopi 15k"
→ Agent parse: kategori "Makanan"
→ User koreksi: "kategorinya Minuman"
→ Agent belajar: "kopi" → Minuman

Next time: "kopi 20k"
→ Agent langsung: kategori "Minuman" 🧠
```

### 2. Wallet Learning

```
User sering pakai "Cash" untuk jajan
→ Agent belajar pola

Next time: jajan → suggest "Cash" 🧠
```

### 3. Notes Style Learning

```
User punya riwayat:
- "Indomaret - Susu"
- "Alfamart - Minyak"

AI akan ikuti gaya "Toko - Item"
bukan "Beli susu di Indomaret"
```

## 📋 Prerequisites

- [Deno](https://deno.land/) installed
- [Supabase CLI](https://supabase.com/docs/guides/cli) installed
- Supabase project created
- Telegram Bot Token dari [@BotFather](https://t.me/botfather)
- Google Gemini API Key

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
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
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
  -d '{"url": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/telegram-bot"}'
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

| Variable             | Description           | Required |
| -------------------- | --------------------- | -------- |
| `TELEGRAM_BOT_TOKEN` | Token dari BotFather  | ✅       |
| `GEMINI_API_KEY`     | Google Gemini API key | ✅       |

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
