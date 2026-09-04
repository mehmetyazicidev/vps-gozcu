# VPS Gözcü macOS dağıtımı

## 1. Yerel paket

```bash
./scripts/build-app.sh
open "dist/VPS Gözcü.app"
```

Varsayılan çıktı ad-hoc imzalıdır. Geliştirme ve aynı Mac üzerindeki kabul testi için uygundur; başka kullanıcılara güvenilir dağıtım yerine geçmez.

## 2. Developer ID ile imzalama

Developer ID sertifikası ve private key geliştiricinin kendi macOS Keychain'inde tutulur:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh
```

İmza hardened runtime ve güvenilir timestamp ile üretilir. Sertifika adı, Team ID, private key veya Apple kimlik bilgileri kaynak depoya yazılmaz.

## 3. Notarization

App Store Connect API anahtarı ya da uygulamaya özel parola ile kimlik bilgilerini bir kez Keychain profiline kaydedin:

```bash
xcrun notarytool store-credentials "vpsgozcu-notary"
```

Sonra imzalı paketi gönderin:

```bash
NOTARY_PROFILE="vpsgozcu-notary" ./scripts/notarize-app.sh
```

Script Apple doğrulamasını bekler, bileti `.app` paketine stapler ile ekler ve Gatekeeper kontrolü yapar.

## 4. İmzalı paketi GitHub'da yayınlama

İmzalı `.app` kaynak kodun parçası değildir. Her değişen binary için yeni Developer ID imzası ve yeni notarization gerekir. İmza sizin geliştirici kimliğinize bağlı olduğu için:

1. `dist/` çıktısını commit etmeyin (`.gitignore` kapsamındadır).
2. Kaynak kodu ve sentetik ekran görüntülerini public repository'ye gönderin.
3. İmzalı/notarized `.zip` veya `.dmg` dosyasını GitHub Release asset'i olarak ekleyin.
4. Release'e SHA-256 checksum ve sürüm notu koyun.
5. Kullanıcıya indirme adresinin resmî repository ve release sayfası olduğunu açıkça belirtin.

İmzalı paketi yayınlamak teknik olarak sorun değildir; ancak sertifikanızın süresi, Apple hesabınız ve bundle identifier'ınızla ilişkili bir resmî dağıtım taahhüdüdür. Paketi yalnızca kendi ürettiğiniz, notarization sonucu doğrulanmış binary olarak paylaşın. Yeni ikon veya Swift kodu gibi küçük bir değişiklik bile önceki notarization sonucunu geçersiz kılar.

Örnek doğrulama:

```bash
codesign --verify --deep --strict "VPS Gözcü.app"
spctl --assess --type execute --verbose=4 "VPS Gözcü.app"
shasum -a 256 "VPS Gözcü.zip"
```

## 5. Public depo güvenliği

- `servers.json`, SSH anahtarları, `.env` dosyaları, sertifikalar ve notarization kimlik bilgileri commit edilmemelidir.
- `servers.example.json` yalnızca yer tutucu değerler içerir; gerçek hedefleri bu dosyaya yazmayın.
- GitHub Actions yalnızca test ve release derlemesi çalıştırır; üretim sunucularına erişim için tasarlanmamıştır.
- Public release ekran görüntüleri yalnızca demo/sentetik veriler içermelidir.
