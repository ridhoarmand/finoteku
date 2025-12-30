# Finoteku - Personal Finance Management App

<img width="500" height="500" alt="icon" src="https://github.com/user-attachments/assets/b93bf38a-b4ff-4ab9-8178-58f080446742" />

**Finoteku** adalah aplikasi manajemen keuangan pribadi yang dirancang dengan focus pada kesederhanaan dan kemudahan penggunaan. Aplikasi ini dibangun menggunakan Flutter dengan backend Supabase untuk memberikan pengalaman yang modern dan reliable.

*Developed by Ridho Armansyah*

## ✨ Features

- 💰 **Multi-Wallet Management** - Kelola berbagai jenis dompet (cash, bank, e-wallet, credit card)
- 📊 **Transaction Management** - Catat income dan expense dengan mudah
- 🏷️ **Smart Categorization** - Sistem kategori hierarkis untuk pengorganisasian yang lebih baik
- 🔄 **Transfer Between Wallets** - Transfer antar wallet dengan fee calculation
- 📱 **Cross-Platform** - Support untuk Android, iOS, dan web
- 🎨 **Modern UI** - Material Design 3 dengan light/dark theme

## 🚀 Tech Stack

- **Framework**: Flutter dengan Dart 3.8.0+
- **State Management**: Riverpod
- **UI/UX**: Material Design 3 + Flex Color Scheme
- **Backend**: Supabase (PostgreSQL + Auth + Storage)
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
│   ├── core/               # Core utilities and constants
│   ├── features/           # Feature modules
│   ├── models/             # Data models
│   ├── routes/             # App routing
│   ├── services/           # External services
│   ├── theme/              # Theme configuration
│   ├── utils/              # Utility functions
│   └── widgets/            # Reusable UI components
└── assets/                 # Static assets
    ├── banks/              # Bank icons
    ├── ewallets/           # E-wallet icons
    └── onboardings/        # Onboarding images
```

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
