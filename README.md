# Finoteku - Personal Finance Management App

**Finoteku** adalah aplikasi manajemen keuangan pribadi yang dirancang dengan focus pada kesederhanaan dan kemudahan penggunaan. Aplikasi ini dibangun menggunakan Flutter dengan backend Supabase untuk memberikan pengalaman yang modern dan reliable.

*Developed by Ridho Armansyah*

## ✨ Features

- 💰 **Multi-Wallet Management** - Kelola berbagai jenis dompet (cash, bank, e-wallet, credit card)
- 📊 **Transaction Management** - Catat income dan expense dengan mudah
- 🏷️ **Smart Categorization** - Sistem kategori hierarkis untuk pengorganisasian yang lebih baik
- 🔄 **Transfer Between Wallets** - Transfer antar wallet dengan fee calculation
- 📸 **Multi-Image Receipts** - Attach multiple images per transaction
- 📱 **Cross-Platform** - Support untuk Android, iOS, dan web
- 🎨 **Modern UI** - Material Design 3 dengan light/dark theme
- ⚡ **Real-time Updates** - Auto-sync data dengan real-time balance tracking

## 🚀 Tech Stack

- **Framework**: Flutter dengan Dart 3.8.0+
- **State Management**: Riverpod
- **UI/UX**: Material Design 3 + Flex Color Scheme
- **Backend**: Supabase (PostgreSQL + Real-time + Auth + Storage)
- **Authentication**: Supabase Auth

## 📋 Quick Start

### Prerequisites
- Flutter SDK 3.8.0+
- Dart SDK 3.0+
- Android Studio / VS Code
- Git

### Installation
```bash
# Clone repository
git clone <repository-url>
cd finoteku

# Install dependencies
flutter pub get

# Setup Supabase 
# Follow instructions in supabase/README.md

# Run the app
flutter run
```

### Supabase Setup
Ikuti panduan setup di **[supabase/README.md](./supabase/README.md)** untuk konfigurasi database backend.

## 🏗️ Project Structure

```
finoteku/
├── supabase/               # Database schema & configuration
│   ├── schema.sql          # Database schema
│   ├── policies.sql        # Row Level Security
│   ├── storage.sql         # Storage configuration
│   └── README.md           # Setup instructions
├── lib/                    # Flutter source code
│   ├── features/           # Feature modules
│   ├── theme/              # Theme configuration
│   ├── services/           # External services
│   ├── models/             # Data models
│   ├── routes/             # App routing
│   ├── utils/              # Utility functions
│   └── widgets/            # Reusable UI components
└── assets/                 # Static assets
    ├── banks/              # Bank icons
    ├── ewallets/           # E-wallet icons
    └── onboardings/        # Onboarding images
```

## 🎯 Current Status

**Development Status: Active** ✅
- ✅ Core foundation implemented
- ✅ Multi-wallet management
- ✅ Hierarchical category system
- ✅ Transaction management
- ✅ Real-time sync with Supabase
- ✅ Material Design 3 theming
- 🔄 Ongoing improvements and refinements

## 🤝 Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

Untuk pertanyaan atau dukungan, silakan buka issue di GitHub repository ini.

---

*Built with ❤️ by Ridho Armansyah using Flutter and Supabase*
