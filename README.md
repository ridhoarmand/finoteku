# Finoteku Bot

Bot Telegram untuk manajemen keuangan pribadi dengan AI yang berjalan di Supabase Edge Functions.

## Fitur

- 💬 Deteksi intent otomatis menggunakan AI
- 📊 Pencatatan transaksi keuangan
- 📸 Parse transaksi dari gambar struk/nota
- 📈 Query riwayat transaksi
- 🤖 Integrasi dengan Telegram Bot API

## Teknologi

- **Runtime**: Deno
- **Platform**: Supabase Edge Functions
- **Database**: Supabase PostgreSQL
- **AI**: Google Gemini & OpenAI
- **Bot Platform**: Telegram

## Struktur Proyek

```
finoteku-bot/
├── supabase/
│   └── functions/
│       ├── _shared/              # Shared utilities dan modules
│       │   ├── ai/              # AI intent detection
│       │   ├── parsers/         # Gemini, OpenAI, dan regex parsers
│       │   ├── platforms/       # Telegram platform utilities
│       │   └── queries/         # Database queries
│       └── telegram-bot/        # Telegram bot edge function
│           ├── index.ts         # Main entry point
│           ├── handlers/        # Command, query, dan transaction handlers
│           └── utils/           # Context dan helper utilities
└── deno.json                    # Deno configuration
```

## Prerequisites

- [Deno](https://deno.land/) installed
- [Supabase CLI](https://supabase.com/docs/guides/cli) installed
- Supabase project created
- Telegram Bot Token dari [@BotFather](https://t.me/botfather)
- API Keys:
  - Google Gemini API Key
  - OpenAI API Key (optional)

## Setup Lokal

1. **Clone repository**

```bash
git clone https://github.com/ridhoarmand/finoteku-bot.git
cd finoteku-bot
```

2. **Link ke Supabase project**

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

3. **Buat file `.env` untuk secrets**

```bash
# .env (jangan commit file ini)
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
GEMINI_API_KEY=your_gemini_api_key
OPENAI_API_KEY=your_openai_api_key
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

4. **Set secrets di Supabase**

```bash
supabase secrets set TELEGRAM_BOT_TOKEN=your_telegram_bot_token
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
supabase secrets set OPENAI_API_KEY=your_openai_api_key
```

## Deploy ke Supabase

1. **Deploy function**

```bash
supabase functions deploy telegram-bot --no-verify-jwt
```

2. **Set webhook Telegram**

```bash
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/telegram-bot"}'
```

3. **Verify webhook**

```bash
curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo"
```

## Development

### Running Locally

```bash
# Serve function locally
supabase functions serve telegram-bot --env-file .env

# Test dengan ngrok untuk webhook
ngrok http 54321
```

### Testing

Kirim pesan ke bot Telegram Anda:

- `/start` - Mulai bot
- `/help` - Lihat bantuan
- `/balance` - Cek saldo
- `Saya beli kopi 15000` - Catat transaksi
- Kirim foto struk - Parse transaksi dari gambar

## Commands

- `/start` - Memulai bot
- `/help` - Menampilkan bantuan
- `/balance` - Cek saldo saat ini
- `/history` - Lihat riwayat transaksi

## Environment Variables

| Variable                    | Description           | Required    |
| --------------------------- | --------------------- | ----------- |
| `TELEGRAM_BOT_TOKEN`        | Token dari BotFather  | ✅          |
| `SUPABASE_URL`              | URL Supabase project  | ✅          |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key      | ✅          |
| `GEMINI_API_KEY`            | Google Gemini API key | ✅          |
| `OPENAI_API_KEY`            | OpenAI API key        | ⚠️ Optional |

## Troubleshooting

### Function tidak menerima updates

1. Cek webhook status:

```bash
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"
```

2. Cek logs:

```bash
supabase functions logs telegram-bot
```

### Error AI parsing

Pastikan API keys sudah diset dengan benar:

```bash
supabase secrets list
```

## Contributing

1. Fork repository
2. Buat branch baru (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push ke branch (`git push origin feature/AmazingFeature`)
5. Buat Pull Request

## License

MIT License - lihat file LICENSE untuk detail

## Author

**Ridho Armand**

- GitHub: [@ridhoarmand](https://github.com/ridhoarmand)

## Acknowledgments

- [Supabase](https://supabase.com/) - Backend dan hosting
- [Deno](https://deno.land/) - Runtime JavaScript/TypeScript
- [Telegram Bot API](https://core.telegram.org/bots/api) - Bot platform
- [Google Gemini](https://ai.google.dev/) - AI untuk parsing
