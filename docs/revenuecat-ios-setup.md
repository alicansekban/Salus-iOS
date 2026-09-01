# iOS RevenueCat + App Store Connect Kurulum Rehberi

iOS uygulamasının `SalusPremium` paketi, `SalusApp.configureRevenueCat()`, `Secrets.xcconfig` bağı ve `RevenueCatPurchasesGateway` adapter'ı M9'dan beri shipped ve testlerle kaplı. Geriye kalan **dış dashboard yapılandırması** — App Store Connect ürünleri ve RevenueCat iOS app + offering — plus anahtarı taşıyan tek local dosya. Bu rehber sırayı anlatır.

## Önkoşullar

- Apple Developer hesabı + `com.alicansekban.salus` App ID (M0'dan beri mevcut).
- RevenueCat hesabı (Android uygulamasının da üzerinde olduğu aynı proje).
- Android referans: `salus-android/local.properties` → `salus.revenuecat.apiKey=test_gjePwySSFbNnmNJwVlinZzFFBTa`. iOS'un kendi anahtarı aynı RevenueCat projesinde ayrı bir app olarak tanımlanmalı.

## Adım 1 — App Store Connect: abonelik grubu + ürünler

1. **App Store Connect → My Apps → Salus → Monetization → Subscriptions** sayfasına git.
2. **Subscription Group** oluştur (ad: "Premium").
3. Üç abonelik ürünü ekle:

| Referans Ad | Product ID | Süre | Fiyat |
|---|---|---|---|
| Premium Aylık | `com.alicansekban.salus.premium.monthly` | 1 Ay | ₺129,99 |
| Premium 6 Aylık | `com.alicansekban.salus.premium.sixmonth` | 6 Ay | ₺519,99 |
| Premium Yıllık | `com.alicansekban.salus.premium.annual` | 1 Yıl | ₺789,99 |

> **Not — vergi (tax):** Google Play vitrinde gösterilen fiyatlar %20 KDV dahil olabilir; Apple App Store Connect'te fiyat tier olarak girilir ve Apple vergiyi kendisi yönetir. Fiyatları App Store Connect'te tier seçerek gir — Apple'ın tier tablosundaki en yakın değeri seç. Net tutar Apple tarafından hesaplanır ve storefront'a göre gösterilir.

4. Her ürün için:
   - Fiyat tier'ı seç (TRY).
   - Türkçe ve İngilizce **yerelleştirilmiş açıklama** ekle.
   - 1024×1024 **abonelik ikonu** yükle.
   - 6 aylık ve yıllık ürüne **7 günlük ücretsiz deneme (free trial)** ekle — paywall'daki "7 gün ücretsiz dene" CTA'nın çalışması için.
5. Subscription group için **App Store Localizations** (TR + EN) ayarla.
6. Kaydet. Apple sandbox'ta birkaç dakika içinde propagasyon yapar.

> **Product ID'ler RevenueCat'te tam olarak eşleşmeli.** Android Play Console'daki product ID'ler farklı (`premium_monthly`, `premium_six_month`, `premium_annual`), RevenueCat her iki platformu aynı `premium` entitlement'a mapler — iOS product ID'leri RevenueCat'in iOS paketlerine girilir.

## Adım 2 — RevenueCat: iOS app ekle

1. **RevenueCat Dashboard → Project Settings → Apps** sayfasına git.
2. **+ New App → iOS** tıkla.
3. Doldur:
   - **App name:** Salus
   - **Bundle ID:** `com.alicansekban.salus`
   - **App Store Connect API Key:** (opsiyonel — sandbox test için RevenueCat ürünleri otomatik senkronlar)
4. Kaydet. RevenueCat `appl_` prefix'li **iOS App-Specific API Key** üretir.
5. O anahtarı kopyala — `Secrets.local.xcconfig`'a gireceğiz.

## Adım 3 — RevenueCat: ürünleri ve entitlement bağla

1. **Product Catalog → Products** sayfasına git.
2. Adım 1'deki üç iOS product ID'yi ekle:
   - `com.alicansekban.salus.premium.monthly` — App: iOS
   - `com.alicansekban.salus.premium.sixmonth` — App: iOS
   - `com.alicansekban.salus.premium.annual` — App: iOS
3. **Entitlements** sayfasına git. `premium` entitlement zaten mevcut (Android kullanıyor). Üç iOS ürününü de mevcut Android ürünlerinin yanına ekle.
4. **Offerings → Current Offering** sayfasına git. Üç iOS ürününü paket olarak ekle:
   - `$rc_monthly` → iOS aylık ürün
   - `$rc_six_month` → iOS 6 aylık ürün
   - `$rc_annual` → iOS yıllık ürün
5. Offering'i kaydet. Artık hem Android hem iOS paketlerini içermeli.

## Adım 4 — Local: API anahtarını gir

```bash
printf 'SALUS_REVENUECAT_API_KEY = appl_ANAHTARIN_BURAYA\n' > App/Secrets.local.xcconfig
```

Dosya `.gitignore`'da (`*.local.xcconfig`). Commit'lenen `App/Secrets.xcconfig` `#include? "Secrets.local.xcconfig"` ile opsiyonel include yapıyor — anahtarsız fresh clone yine build olur ve uygulama tamamen free modda çalışır (çökmez).

## Adım 5 — Xcode project'i yeniden üret ve build al

```bash
cd salus-ios
xcodegen generate
scripts/build-app.sh
```

## Adım 6 — Sandbox satın alma testi

1. **App Store Connect → Users → Sandbox → Testers**'da Sandbox Tester oluştur.
2. Simulator'da: Settings → Developer → Sandbox Account → sandbox tester ile giriş yap.
3. Uygulamayı build et ve çalıştır (`scripts/build-app.sh` sonra Xcode'da run).
4. `scripts/m9-manual-qa.md` matrisini koş:
   - §1.3: paywall üç plan kartı gösterir (yıllık first, free trial rozeti + "7 gün ücretsiz dene" CTA).
   - §1.7: CTA'ya basınca store sheet açılır, satın alma başarılı, paywall kapanır.
   - §3.1: premium tema satın alma sonrası anında açılır.
   - §3.2: sandbox'ta aboneliği iptal et → grace period → tema classic'e döner.
   - §3.3: satın almaları geri yükle entitlement'ı bulur.
   - §3.4: entitlement olmadan restore → restore hata metni gösterir.
   - §3.5: offline relaunch cached entitlement'ı korur.
5. `scripts/m11-manual-qa.md` §1 (free user kilitli önizleme) ve §2 (premium user dört kart) koş.

## Adım 7 — Commit

Anahtar asla git'e girmez. Bu rehber ve QA matrisleri dışında kodda değişiklik yok — kod zaten `main`'de.

## Referans

- Android `local.properties`: `salus.revenuecat.apiKey=test_gjePwySSFbNnmNJwVlinZzFFBTa` (Android anahtarı, iOS'de kullanılamaz)
- iOS bağı: `App/Secrets.xcconfig` (commit'li, boş default) + `App/Secrets.local.xcconfig` (git-ignored, gerçek anahtar)
- iOS gateway: `Packages/SalusPremium/Sources/SalusPremium/RevenueCatPurchasesGateway.swift`
- iOS yapılandırma: `App/SalusApp.swift:59` — `configureRevenueCat()`
- Entitlement ID: `"premium"` (`RevenueCatPurchasesGateway.swift:117`'de hardcoded)
- QA matrisi: `scripts/m9-manual-qa.md` (premium lifecycle) + `scripts/m11-manual-qa.md` (trends)

## Abonelik fiyatları

| Plan | Fiyat | Para Birimi | Not |
|---|---|---|---|
| Aylık | 129,99 | TRY | Google Play'de %20 KDV dahil olabilir |
| 6 Aylık | 519,99 | TRY | 7 gün ücretsiz deneme (free trial) · Google Play'de %20 KDV dahil olabilir |
| Yıllık | 789,99 | TRY | 7 gün ücretsiz deneme (free trial) · Google Play'de %20 KDV dahil olabilir |

> Apple App Store Connect fiyat tier olarak girilir; Apple vergiyi kendisi yönetir. Storefront'a göre gösterim Apple tarafından yapılır. Google Play'deki tax-dahil fiyatlar Apple'de tier karşılığına maplenir — küsuratlı fark olabilir.