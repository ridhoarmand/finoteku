# Finoteku - Personal Finance Management App

<img width="500" height="500" alt="icon" src="https://github.com/user-attachments/assets/b93bf38a-b4ff-4ab9-8178-58f080446742" />

**Finoteku** adalah aplikasi manajemen keuangan pribadi yang dirancang dengan focus pada kesederhanaan dan kemudahan penggunaan. Aplikasi ini dibangun menggunakan Flutter dengan backend Supabase untuk memberikan pengalaman yang modern dan reliable.

*Developed by Ridho Armansyah*

## ✨ Features

- 💰 **Multi-Wallet Management** - Kelola berbagai jenis dompet (cash, bank, e-wallet, credit card)
- 📊 **Transaction Management** - Catat income dan expense dengan mudah
- 🏷️ **Smart Categorization** - Sistem kategori hierarkis untuk pengorganisasian yang lebih baik
- 🔄 **Transfer Between Wallets** - Transfer antar wallet dengan fee calculation
- 🤖 **AI-Powered Bot Integration** - Telegram bot untuk mencatat transaksi (lihat [finoteku-agent](https://github.com/ridhoarmand/finoteku-agent))
- 📱 **Cross-Platform** - Support untuk Android, Linux, Windows, dan Web
- 🎨 **Modern UI** - Material Design 3 dengan light/dark theme
- 🌍 **Multi-Language** - Support Bahasa Indonesia dan English

## 🚀 Tech Stack

- **Framework**: Flutter dengan Dart 3.8.0+
- **State Management**: Riverpod 2.x
- **Routing**: GoRouter
- **UI/UX**: Material Design 3 + Flex Color Scheme
- **Backend**: Supabase (PostgreSQL + Auth + Storage)
- **Database**: PostgreSQL dengan RLS (Row Level Security)
- **Authentication**: Supabase Auth (Email & Social Login)
- **Localization**: Custom i18n implementation
- **AI Bot**: Deno-based dengan Telegram bot (separate repo)

## 📋 Quick Start

### Prerequisites
- Flutter SDK 3.8.0+
- Dart SDK 3.0+
- Android Studio / VS Code
- Git

### Installation

```bash
# 1. Clone repository
git clone https://github.com/ridhoarmand/finoteku.git
cd finoteku

# 2. Install Flutter dependencies
flutter pub get

# 3. Setup environment variables
# Copy .env.example to .env dan isi dengan credentials Supabase Anda
cp .env.example .env

# 4. Run the app (menggunakan compile-time environment variables)
flutter run --dart-define-from-file=.env
```

### Supabase Setup

**⚠️ Supabase database setup instructions telah dipindahkan ke [finoteku-agent](https://github.com/ridhoarmand/finoteku-agent) repository.**

Untuk setup Supabase:

1. Follow detailed setup instructions di: **[finoteku-agent/README.md](https://github.com/ridhoarmand/finoteku-agent#-supabase-setup)**
2. Database schema, migrations, dan konfigurasi ada di project agent
3. Setelah setup Supabase, configure app dengan credentials:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### Bot Integration (Recommended)

Untuk fitur lengkap dengan Telegram bot AI-powered:

**Repository**: [finoteku-agent](https://github.com/ridhoarmand/finoteku-agent)

```bash
# Clone agent repository
git clone https://github.com/ridhoarmand/finoteku-agent.git
cd finoteku-agent

# Follow setup instructions
```

## 🏗️ Project Structure

```
finoteku/
├── supabase/                      # Database schema & configuration
│   ├── setup.sql                  # Complete database setup
│   └── resetdb.sql                # Database reset script
├── lib/                           # Flutter source code
│   ├── core/                      # Core utilities
│   │   ├── errors/                # Error handling
│   │   ├── i18n/                  # Internationalization
│   │   ├── localization/          # Localization setup
│   │   └── logging/               # Logging configuration
│   ├── features/                  # Feature modules (Clean Architecture)
│   │   ├── auth/                  # Authentication
│   │   ├── wallet/                # Wallet management
│   │   ├── category/              # Category management
│   │   ├── transaction/           # Transaction management
│   │   ├── transfer/              # Transfer between wallets
│   │   ├── home/                  # Home dashboard
│   │   ├── account/               # User account
│   │   └── report/                # Financial reports
│   ├── models/                    # Data models
│   ├── routes/                    # App routing (GoRouter)
│   ├── services/                  # External services
│   ├── theme/                     # Theme configuration
│   ├── utils/                     # Utility functions
│   └── widgets/                   # Reusable UI components
├── assets/                        # Static assets
│   ├── banks/                     # Bank icons
│   ├── ewallets/                  # E-wallet icons
│   ├── wallets/                   # Wallet type icons
│   └── onboardings/               # Onboarding images
└── android/linux/windows/web/     # Platform-specific code
```

## 🔗 Related Projects

- **[Finoteku Agent](https://github.com/ridhoarmand/finoteku-agent)** - AI-powered Telegram bot untuk mencatat transaksi dengan natural language processing

## 🤝 Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow Flutter best practices dan clean architecture
- Gunakan Riverpod untuk state management
- Tulis kode yang readable dan maintainable
- Test fitur sebelum create PR
- Update documentation jika perlu

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

Untuk pertanyaan atau dukungan, silakan buka issue di GitHub repository ini.

---

*Built with ❤️ by Ridho Armansyah using Flutter and Supabase*
