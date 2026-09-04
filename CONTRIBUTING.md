# Katkıda bulunma

VPS Gözcü, kişisel SSH yapılandırmasını kullanan yerel bir macOS uygulamasıdır. Katkılar memnuniyetle karşılanır; güvenlik sınırları projenin temel parçasıdır.

## Geliştirme

1. macOS 14 veya daha yeni bir Mac'te projeyi açın.
2. Değişiklikten önce `swift test` çalıştırın.
3. Release derlemesini `swift build -c release` ile doğrulayın.
4. Gerçek sunucu adlarını, adreslerini, loglarını veya kimlik bilgilerini commit etmeyin.

## Pull request kontrol listesi

- [ ] Salt-okunur izleme kapsamı korunuyor.
- [ ] Keyfi uzak shell komutu eklenmedi.
- [ ] Host key doğrulaması devre dışı bırakılmadı.
- [ ] SSH private key, parola, token veya production profili eklenmedi.
- [ ] Testler ve release derlemesi başarılı.
- [ ] Kullanıcıya görünen davranış ve güvenlik etkisi README/docs içinde anlatıldı.

## Hata bildirimi

Güvenlik sorunlarını public issue'a production logu veya sunucu bilgisi eklemeden özel GitHub Security Advisory olarak bildirin. Genel hata raporlarında macOS sürümü, uygulama sürümü ve anonimleştirilmiş hata çıktısı yeterlidir.
