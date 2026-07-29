# 🌿 Uğrak - Kafe Keşif ve Sosyal Paylaşım Uygulaması

**Uğrak**, yapay zeka destekli semantik arama ile kafe keşfini sosyal bir deneyime dönüştüren bir Flutter mobil uygulamasıdır. Kullanıcılar, doğal dil kullanarak kendilerine en uygun kafeleri bulabilir, deneyimlerini paylaşabilir ve arkadaşlarıyla etkileşime geçebilir.

## 📱 Projenin Amacı


Uğrak, geleneksel arama yöntemlerinin ötesine geçerek, kullanıcıların "sakin ve kitap okumaya uygun" veya "laptop ile çalışılabilir" gibi doğal ifadelerle arama yapmasını sağlar. BERT ve SBERT modelleri kullanarak, yalnızca kafe isimlerine değil, kullanıcı yorumlarına ve post içeriklerine de semantik anlam analizi uygular.

### Temel Özellikler
- 🤖 **AI Destekli Semantik Arama**: Hugging Face'te barındırılan BERT/SBERT modelleri ile doğal dil anlama
- 🗺️ **Harita Tabanlı Keşif**: Google Maps entegrasyonu ile konum bazlı kafe bulma
- 💬 **Sosyal Etkileşim**: Yorum, post paylaşımı, arkadaş sistemi ve sohbet
- 🏆 **Liderlik Tablosu**: Günlük aktivite bazlı sıralama sistemi
- 🎯 **Kişiselleştirme**: Vibe etiketleri, koleksiyonlar ve rozet sistemi
- 🔔 **Push Bildirimleri**: OneSignal entegrasyonu ile gerçek zamanlı bildirimler
- 👨‍💼 **Admin Paneli**: Eksik kafe bildirimleri ve içerik yönetimi

## 🛠️ Teknoloji Yığını

### Frontend
- **Flutter** `3.5.0+` - Cross-platform mobil geliştirme
- **Dart SDK** `>=3.5.0 <4.0.0`

### Backend ve Servisler
- **Supabase** - Backend as a Service (Auth, Database, Storage, Edge Functions)
  - PostgreSQL veritabanı
  - Row Level Security (RLS) politikaları
  - Realtime subscriptions
  - Edge Functions (Liderlik tablosu güncellemeleri)
- **Hugging Face Spaces** - AI Model barındırma
  - BERT modeli (Embedding oluşturma)
  - SBERT modeli (Semantik arama - 384 boyutlu)

### Temel Bağımlılıklar
```yaml
# Backend & State Management
supabase_flutter: ^2.0.0        # Supabase istemcisi
provider: ^6.1.5                  # State management

# Harita ve Konum
google_maps_flutter: ^2.6.0      # Google Maps widget
flutter_map: ^6.1.0               # Alternatif harita widget
geolocator: ^10.1.0               # Konum servisleri
latlong2: ^0.9.1                  # Koordinat işlemleri

# UI & UX
google_fonts: ^6.1.0              # Özel fontlar
flutter_animate: ^4.5.0           # Animasyonlar
image_picker: ^1.0.7              # Görsel seçimi
image_cropper: ^12.2.1            # Görsel düzenleme

# Sosyal & Paylaşım
share_plus: ^10.0.0               # Paylaşım özellikleri
app_links: ^6.4.1                 # Deep linking
timeago: ^3.7.1                   # Zaman formatlama

# Bildirimler
onesignal_flutter: ^5.2.5         # Push bildirimler

# Kimlik Doğrulama
google_sign_in: ^6.2.1            # Google Auth

# Utility
flutter_dotenv: ^6.0.0            # Ortam değişkenleri
http: ^1.1.0                      # HTTP istekleri
path_provider: ^2.1.2             # Dosya yolları
shared_preferences: ^2.2.2        # Lokal depolama
```

### Yapay Zeka Modelleri
- **BERT**: Metin embedding oluşturma
- **SBERT** (Sentence-BERT): 384 boyutlu semantik arama embeddinglari

## 📋 Kurulum Adımları

### Ön Gereksinimler
1. **Flutter SDK** (3.5.0 veya üzeri)
   ```bash
   flutter --version
   ```
   İndirmek için: [flutter.dev](https://flutter.dev/docs/get-started/install)

2. **Android Studio** veya **VS Code** (Flutter eklentileri ile)

3. **Git**

### 1. Projeyi Klonlayın
```bash
git clone https://github.com/your-repo/ugrak_mekan_app.git
cd ugrak_mekan_app
```

### 2. Bağımlılıkları Yükleyin
```bash
flutter pub get
```

### 3. Ortam Değişkenlerini Yapılandırın
Proje kök dizininde `.env` dosyası bulunmalıdır. Aşağıdaki değişkenleri kendi değerlerinizle güncelleyin:

```env
# Supabase Yapılandırması
EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key

# Google Maps API
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
GOOGLE_WEB_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com

# Hugging Face AI Model Endpoints
BERT_API_URL=https://your-bert-model.hf.space/embed
SBERT_API_URL=https://your-sbert-model.hf.space/embed

# Admin Yapılandırması
MY_SYNC_KEY=your-sync-key
ADMIN_EMAIL=admin@example.com, another-admin@example.com

# OneSignal Push Notifications
ONESIGNAL_APP_ID=your-onesignal-app-id
```

 **Güvenlik Notu**: `.env` dosyasını asla git'e commit etmeyin! `.gitignore` dosyasına eklenmiş olduğundan emin olun.

### 4. Android Yapılandırması

#### Google Maps API Key
`android/app/src/main/AndroidManifest.xml` dosyasına API anahtarınızı ekleyin:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${GOOGLE_MAPS_API_KEY}"/>
```

#### Minimum SDK
`android/app/build.gradle.kts` dosyasında:
```kotlin
minSdk = 21
targetSdk = 34
```

### 5. iOS Yapılandırması (Opsiyonel)
`ios/Runner/Info.plist` dosyasına konum izinleri ekleyin:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Uğrak, size yakın kafeleri gösterebilmek için konumunuza ihtiyaç duyar.</string>
```

### 6. Uygulamayı Çalıştırın

**Debug Modu (Geliştirme):**
```bash
flutter run
```

**Release Modu (APK):**
```bash
flutter build apk --release
```

**APK dosyası:** `build/app/outputs/flutter-apk/app-release.apk`

### 7. Test Çalıştırma
```bash
flutter test
```

## 🏗️ Proje Yapısı

```
ugrak_mekan_app/
├── lib/
│   ├── main.dart                    # Uygulama giriş noktası
│   ├── models/                      # Veri modelleri
│   │   ├── cafe_model.dart
│   │   └── user_model.dart
│   ├── views/                       # Ekran widget'ları
│   │   ├── home_screen.dart         # Ana arama ekranı
│   │   ├── auth_screen.dart         # Giriş/Kayıt
│   │   ├── admin_panel_screen.dart  # Admin paneli
│   │   ├── leaderboard_screen.dart  # Liderlik tablosu
│   │   └── ...
│   ├── widgets/                     # Yeniden kullanılabilir UI bileşenleri
│   │   ├── cafe_card.dart
│   │   ├── search_overlay.dart
│   │   └── ...
│   ├── services/                    # İş mantığı katmanı
│   │   ├── api_service.dart         # AI arama servisi
│   │   ├── supabase_service.dart    # Veritabanı işlemleri
│   │   ├── admin_service.dart       # Admin operasyonları
│   │   ├── embedding_service.dart   # AI embedding oluşturma
│   │   └── ...
│   └── controllers/                 # State yönetimi
│       └── map_explore_controller.dart
├── assets/
│   └── images/
│       └── ugrak_logo.jpg
├── android/                         # Android yapılandırması
├── ios/                             # iOS yapılandırması
├── test/                            # Birim ve widget testleri
├── .env                             # Ortam değişkenleri (GİZLİ)
├── pubspec.yaml                     # Bağımlılıklar
└── README.md
```

## 🔑 Önemli Yapılandırma Notları

### Supabase Veritabanı Şeması
Uygulama aşağıdaki temel tablolara ihtiyaç duyar:
- `ilce_isimli_kafeler` - Kafe bilgileri (il, ilce, koordinatlar, vibe_etiketleri)
- `cafe_yorumlar` - Kullanıcı yorumları ve puanları
- `cafe_postlar` - Kullanıcı gönderileri
- `profiles` - Kullanıcı profilleri
- `koleksiyonlar` - Kafe koleksiyonları
- `notifications` - Bildirimler
- `chat_conversations` & `chat_messages` - Mesajlaşma

### Supabase RPC Fonksiyonları
AI arama için aşağıdaki PostgreSQL fonksiyonları gereklidir:
- `kafe_ara_ai_dynamic` - Semantik arama (SBERT embeddingler ile)
- Günlük liderlik tablosu güncellemesi için Edge Function

### Hugging Face Model Deployment
1. BERT ve SBERT modellerinizi Hugging Face Spaces'e deploy edin
2. Her model bir `/embed` endpoint'i sağlamalı
3. Request format: `{"text": "arama sorgusu"}`
4. Response format: `{"embedding": [0.1, 0.2, ..., 0.384]}`

### OneSignal Push Notifications
1. [OneSignal](https://onesignal.com/) hesabı oluşturun
2. Yeni bir uygulama oluşturun
3. App ID'yi `.env` dosyasına ekleyin
4. Android/iOS için gerekli yapılandırmaları tamamlayın

## 🧪 Test ve CI/CD

Proje, GitHub Actions kullanarak otomatik test pipeline'ına sahiptir:
- `.github/workflows/flutter-test.yml` - Her commit'te testleri çalıştırır
- `.github/workflows/keep_alive.yml` - Hugging Face Spaces modellerini aktif tutar

**Manuel test çalıştırma:**
```bash
# Tüm testler
flutter test

# Belirli bir test dosyası
flutter test test/services/admin_service_test.dart

# Coverage raporu
flutter test --coverage
```

## 🚀 Deployment

### Android (Google Play Store)
```bash
# App Bundle oluşturma (önerilen)
flutter build appbundle --release

# Dosya konumu: build/app/outputs/bundle/release/app-release.aab
```

### APK (Direkt kurulum)
```bash
flutter build apk --release --split-per-abi
```

### CodeMagic CI/CD
Proje `codemagic.yaml` dosyasına sahiptir. CodeMagic ile otomatik build ve deployment yapılandırması mevcuttur.

## 🐛 Sorun Giderme

### Yaygın Hatalar ve Çözümleri

**1. "SBERT_API_URL bulunamadı"**
- `.env` dosyasının proje kök dizininde olduğundan emin olun
- `pubspec.yaml` içinde `.env` dosyasının assets'e eklendiğini kontrol edin

**2. Google Maps görünmüyor**
- Android Manifest'te API key'in doğru eklendiğini kontrol edin
- Google Cloud Console'da Maps SDK'nın aktif olduğunu doğrulayın

**3. OneSignal bildirimleri çalışmıyor**
- ONESIGNAL_APP_ID'nin doğru girildiğini kontrol edin
- Cihazda bildirim izinlerinin verildiğini doğrulayın

**4. Supabase bağlantı hatası**
- Supabase URL ve Anon Key'in güncel olduğunu kontrol edin
- RLS (Row Level Security) politikalarının doğru yapılandırıldığından emin olun

**5. Build hatası: "Execution failed for task ':app:processReleaseResources'"**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

## 📄 Lisans

Bu proje özel bir projedir. Ticari kullanım için izin gereklidir.

## 👥 Katkıda Bulunanlar

- **Hatice Akgül** - Proje Sahibi & Geliştirici

## 📞 İletişim

Sorularınız veya önerileriniz için:
- Email: haticeakgul.dev@gmail.com


---

**Not**: Bu projeyi çalıştırmadan önce tüm API anahtarlarını ve yapılandırma değişkenlerini güncel tuttuğunuzdan emin olun. Eksik yapılandırma, uygulamanın çalışmamasına neden olabilir.

🌿 **Uğrak ile her köşe başı bir keşif!**
