# Ugrak Mekan App

Kafe keşif ve paylaşım platformu - Flutter ile geliştirilmiş mobil uygulama.

## 🚀 Hızlı Başlangıç

### Kurulum

```bash
# 1. Dependencies yükle
flutter pub get

# 2. Git hooks kur (otomatik testler için)
setup-hooks.bat  # Windows
bash setup-hooks.sh  # Linux/macOS

# 3. Uygulamayı çalıştır
flutter run
```

## 🧪 Test Sistemi

### İstatistikler
- **206 unit test** - %100 başarılı
- **Execution time**: < 10 saniye
- **Coverage**: ~1% (Internal logic focus - Supabase mocklanmadı)

### Test Çalıştırma

```bash
# Testleri çalıştır
flutter test

# Coverage ile
flutter test --coverage

# Makefile ile
make test
make test-coverage
```

### Otomatik Test Sistemi

#### ✅ Local (Git Hooks)
- **Pre-commit**: Her `git commit` öncesi testler çalışır
- **Pre-push**: Her `git push` öncesi analysis + testler çalışır
- **Bypass**: `git commit --no-verify` veya `git push --no-verify`

#### ✅ GitHub Actions (CI/CD)
- **Push to main/develop**: Full pipeline (test + build + coverage)
- **Pull Request**: Test + build + PR'a otomatik yorum
- **Artifacts**: Test results, coverage, APK (30 gün)

### Test Dağılımı

| Kategori | Test Sayısı | Dosyalar |
|----------|-------------|----------|
| **Models** | 9 | `test/models/cafe_model_test.dart` |
| **Services** | 79 | `test/services/*.dart` (6 dosya) |
| **Utilities** | 77 | `test/utils/*.dart` (2 dosya) |
| **Helpers** | 41 | `test/test_helpers.dart` |

## 🛠️ Geliştirme

### Makefile Komutları

```bash
make help              # Tüm komutları listele
make setup             # Dependencies + hooks kur
make test              # Testleri çalıştır
make test-coverage     # Coverage ile test
make analyze           # Code analysis
make format            # Kodu formatla
make build-android     # Android APK build (testlerle)
make build-ios         # iOS build (testlerle)
make clean             # Temizlik
make ci                # CI checks (analyze + test)
```

### VS Code Kısayolları

- `Ctrl+Shift+T` → Run Tests
- `Ctrl+Shift+B` → Build APK (önce testler çalışır)
- `Ctrl+Shift+P` → "Tasks: Run Task" → Diğer tasks

## 📁 Proje Yapısı

```
ugrak_mekan_app/
├── lib/
│   ├── models/            # Data models
│   ├── services/          # Business logic
│   ├── views/             # UI screens
│   ├── widgets/           # Reusable widgets
│   └── controllers/       # State management
├── test/
│   ├── models/            # Model tests (9 tests)
│   ├── services/          # Service tests (79 tests)
│   ├── utils/             # Utility tests (77 tests)
│   └── test_helpers.dart  # Test utilities (41 tests)
├── .github/workflows/     # CI/CD pipelines
│   └── flutter-test.yml   # Test & build pipeline
├── .githooks/             # Git hooks
│   ├── pre-commit         # Commit öncesi testler
│   └── pre-push           # Push öncesi analysis + testler
└── coverage/              # Coverage reports
```

## 🔧 Teknolojiler

- **Flutter** 3.32.1
- **Dart** 3.x
- **Supabase** - Backend
- **Google Maps** - Harita entegrasyonu
- **GitHub Actions** - CI/CD

## 🤝 Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun: `git checkout -b feature/amazing-feature`
3. Değişikliklerinizi commit edin: `git commit -m 'feat: add amazing feature'`
4. Branch'inizi push edin: `git push origin feature/amazing-feature`
5. Pull Request oluşturun

**Not**: Her commit ve push'ta testler otomatik çalışır!

### Commit Mesajları

Conventional Commits formatı kullanın:

```
feat: yeni özellik
fix: hata düzeltme
docs: dokümantasyon
test: test ekleme/düzeltme
refactor: kod iyileştirme
style: format değişiklikleri
chore: build/config değişiklikleri
```

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

**Tetikleyiciler**:
- Push to `main`, `develop`, `master`
- Pull requests
- Manuel tetikleme

**Pipeline Adımları**:
1. **Test Job**
   - Flutter 3.32.1 kurulumu
   - Dependencies yükleme
   - Code analysis (`flutter analyze`)
   - 206 test çalıştırma
   - Coverage raporu oluşturma
   - Artifacts saklama

2. **Build Android Job** (test başarılıysa)
   - Release APK build
   - APK artifact olarak saklama

3. **Build iOS Job** (sadece main branch)
   - iOS build (codesign olmadan)

### Git Hooks Kurulumu

```bash
# Windows
setup-hooks.bat

# Linux/macOS
bash setup-hooks.sh
```

**Ne yapar?**
- `.githooks/` içindeki hook'ları `.git/hooks/` dizinine kopyalar
- Executable yapar
- Her commit/push'ta otomatik test çalıştırır

## 🐛 Sorun Giderme

### Hook'lar çalışmıyor
```bash
# Yeniden kur
setup-hooks.bat  # Windows
bash setup-hooks.sh  # Linux/macOS
```

### Testler başarısız
```bash
flutter clean
flutter pub get
flutter test
```

### Build hatası
```bash
flutter clean
flutter pub get
flutter build apk
```

### CI/CD başarısız
```bash
# Local'de aynı komutları çalıştır
flutter analyze
flutter test --coverage

# Hataları düzelt ve tekrar push et
```

## 📊 Test Coverage Detayları

### Neden Coverage Düşük?

Coverage %1 olmasının nedeni **dış bağımlılıkları mocklamama** stratejisidir:
- ❌ Supabase mocklaması YOK
- ❌ HTTP client mocklaması YOK
- ❌ Database mocklaması YOK

Bu yaklaşım **internal logic testing**'e odaklanır.

### Neyi Test Ediyoruz ✅

1. **Data Models** - JSON serialization, transformations
2. **Business Logic** - Calculations, algorithms, validations
3. **Utility Functions** - Distance calculations (Haversine), time range checks
4. **Internal Logic** - Filtering, sorting, state management

### Neyi Test Etmiyoruz ❌

1. **External Dependencies** - Supabase, HTTP, Auth
2. **UI Components** - Widgets, interactions
3. **Integration Points** - Database, API calls

### Coverage Dağılımı

- **cafe_model.dart**: 100% (35/35 lines)
- **Utilities**: 100% (standalone implementations)
- **Services**: ~0% (Supabase gerektirir)
- **Views**: ~0% (Widget testing gerektirir)

## 💡 Best Practices

### ✅ Yapılması Gerekenler

1. **Her commit öncesi test**
   ```bash
   make test
   ```

2. **Anlamlı commit mesajları**
   ```bash
   git commit -m "feat: add user authentication"
   ```

3. **PR öncesi CI/CD kontrolü**
   - GitHub Actions'ın başarılı olmasını bekle

4. **Hook'ları sadece acil durumlarda atla**
   ```bash
   git commit --no-verify  # Sadece acil durumlar
   ```

### ❌ Yapılmaması Gerekenler

1. Hook'ları sürekli atlama
2. Başarısız testlerle commit
3. Coverage'ı görmezden gelme

## 🎯 Workflow Örnekleri

### Normal Development

```bash
# 1. Feature branch oluştur
git checkout -b feature/new-feature

# 2. Kod yaz ve test et
make test

# 3. Commit (otomatik test çalışır)
git add .
git commit -m "feat: add new feature"

# 4. Push (otomatik analysis + test çalışır)
git push origin feature/new-feature

# 5. PR oluştur (CI/CD otomatik çalışır)
```

### Hızlı Fix

```bash
# 1. Fix yap ve test et
make test

# 2. Commit (hook'ları atla)
git commit --no-verify -m "fix: emergency"

# 3. Push (CI/CD yine de çalışır)
git push
```

### Build Öncesi Test

```bash
# Makefile ile (otomatik test çalışır)
make build-android

# veya manuel
flutter test && flutter build apk --release
```

## 📞 İletişim

Sorularınız için issue açabilirsiniz.

## 📄 Lisans

Bu proje özel bir projedir.

---

**Test Durumu**: ✅ 206/206 passing  
**CI/CD**: ✅ Aktif  
**Son Güncelleme**: 2026-05-07
