# Finoteku - Personal Finance Management App

**Finoteku** adalah aplikasi manajemen keuangan pribadi yang dirancang dengan focus pada kesederhanaan dan kemudahan penggunaan. Aplikasi ini dibangun menggunakan Flutter dengan backend Supabase untuk memberikan pengalaman yang modern dan reliable.

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

# Setup Supabase (see detailed guide below)
# Follow instructions in supabase/SETUP_GUIDE.md

# Run the app
flutter run
```

### Supabase Setup
Ikuti panduan lengkap di **[supabase/SETUP_GUIDE.md](./supabase/SETUP_GUIDE.md)** untuk setup database backend.

## 📚 Documentation

Dokumentasi lengkap tersedia di folder **[docs/](./docs/)**:

- **[Business Requirements](./docs/1.%20Business%20Requirements%20Document.md)** - Requirements dan user stories
- **[Technical Design](./docs/2.%20Technical%20Design%20Document.md)** - System architecture dan design
- **[Development Roadmap](./docs/3.%20Roadmap.md)** - Milestone dan timeline
- **[Development Tasks](./docs/4.%20Development%20Tasks%20Checklist.md)** - Task breakdown dan checklist
- **[Testing Guide](./docs/5.%20Testing%20Documentation%20&%20Checklist.md)** - Testing strategy dan checklist
- **[Technical Architecture](./docs/Technical-Architecture-Documentation.md)** - Detailed technical architecture
- **[Quick Developer Guide](./docs/Quick-Developer-Guide.md)** - Developer reference
- **[Project Structure Guide](./docs/Project-Structure-Guide.md)** - Project organization

## 🏗️ Project Structure

```
finoteku/
├── docs/                    # Project documentation
├── supabase/               # Database schema & configuration
│   ├── schema.sql          # Database schema
│   ├── policies.sql        # Row Level Security
│   ├── storage.sql         # Storage configuration
│   ├── seed.sql            # Sample data
│   └── SETUP_GUIDE.md      # Setup instructions
├── lib/                    # Flutter source code
│   ├── features/           # Feature modules
│   ├── theme/              # Theme configuration
│   ├── services/           # External services
│   ├── models/             # Data models
│   └── widgets/            # Reusable UI components
└── assets/                 # Static assets
```

## 🎯 Current Status

**Phase 1: Core Foundation** ✅
- ✅ Documentation complete
- ✅ Database schema designed and simplified
- ✅ Supabase configuration ready
- ⏳ Flutter project setup (next)
- ⏳ Core implementation (next)

## 🤝 Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

Untuk pertanyaan atau dukungan, silakan buka issue di GitHub atau hubungi tim development.

---

*Built with ❤️ using Flutter and Supabase*
