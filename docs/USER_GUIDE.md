# VPS Gözcü kullanım rehberi

Bu rehber, ilk kez kullanan bir kişinin public release paketinden başlayarak kendi VPS'ini eklemesi için hazırlanmıştır.

## Kurulum

### Resmî release paketi

1. GitHub repository'sinin **Releases** sayfasından imzalı ve notarize edilmiş `.zip` dosyasını indirin.
2. Release notundaki SHA-256 değerini doğrulayın.
3. `.zip` dosyasını açıp `VPS Gözcü.app` paketini **Applications** klasörüne taşıyın.
4. Uygulamayı açın. macOS ilk çalıştırmada geliştirici doğrulaması gösterebilir; yalnızca resmî release kaynağından indirdiğiniz pakette devam edin.

İmzalı paket kaynak depoya konmaz. Kaynak koddan derlemek isteyenler için aşağıdaki alternatif kullanılabilir.

### Kaynak koddan

```bash
git clone https://github.com/mehmetyazicidev/vps-gozcu.git
cd vps-gozcu
swift test
swift run VPSGozcu
```

macOS 14+ ve Xcode Command Line Tools gerekir. Xcode ile geliştirmek için `Package.swift` dosyasını açın.

## İlk açılış

Uygulama merkezi bir hesaba veya telemetri servisine bağlanmaz. İlk açılışta **Sunucu Ekle** ile yerel bir profil oluşturun. Boş kurulumdaki `Örnek VPS` profili yalnızca arayüzü göstermek içindir ve devre dışıdır.

### Profil alanları

| Alan | Ne girilmeli? |
| --- | --- |
| Görünen ad | Uygulamada gösterilecek kısa ad, ör. `Atlas Edge` |
| SSH hedefi / alias | `~/.ssh/config` içindeki alias, ör. `atlas-edge` |
| Uygulama dizini | Uygulamanın uzak sunucudaki dizini |
| Health URL | İsteğe bağlı HTTPS sağlık adresi |
| Full/Data backup kökü | İsteğe bağlı yedek klasörleri |
| İzlemeyi etkinleştir | Profilin periyodik taramaya dahil edilmesi |

Uygulama SSH parolası veya private key istemez ve bunları kaydetmez. Önce Terminal'de bağlantıyı test edin:

```bash
ssh atlas-edge true
```

SSH config'te `StrictHostKeyChecking` değerini gevşetmeyin. İlk host key kabulünü Terminal'de, hedefi doğruladıktan sonra yapın.

## İzleme ekranı

**Şimdi Tara** düğmesi etkin profilleri tek seferde sorgular. Uygulama açık olduğu sürece periyodik tarama yapılır; Mac uyurken veya kapalıyken geçmişe veri eklenmez.

Kontroller şunları kapsar:

- CPU, RAM, disk, load, kernel ve genel uptime
- Bekleyen paket/güvenlik güncellemeleri ve reboot gereksinimi
- Docker container'ları ve kritik systemd servisleri
- Health URL HTTP yanıtı
- Full/data backup yaşları
- HTTPS profillerinde TLS sertifikası kalan günleri

Sağlık seviyesi `Kritik`, `Uyarı`, `Bilinmiyor` veya `Sağlıklı` olur. Bir ölçüm okunamıyorsa `0` varsayılmaz; `Bilinmiyor` gösterilir. Eşikler profil düzenleme ekranından sunucuya göre değiştirilebilir. Varsayılanlar disk için `%80/%90`, backup için `26/48 saat`, TLS için `30/7 gün` uyarı/kritik değerleridir.

## Menü çubuğu

Menü çubuğu simgesi genel durumu hızlı gösterir. Açılan panelde sunucu özetini, **Ana Pencereyi Aç** ve **Şimdi Tara** eylemlerini bulabilirsiniz. Bildirimler yalnızca yeni kritik durumlarda yerel olarak gösterilir.

## Olay akışı ve geçmiş

Olay akışı varsayılan olarak son üç kaydı gösterir. **Tüm olayları göster** ile geçmiş liste açılır; kayıtlar silinmez. Grafik geçmişi ve olaylar yalnızca Mac'te yerel tutulur.

## Bakım işlemleri

Güncelleme, reboot, Docker yeniden oluşturma ve deploy izleme taramasından ayrıdır. Bakım planı önce yedek tazeliğini, hedefi ve ön koşulları kontrol eder; gerçek işlem yalnızca açık kullanıcı onayından sonra ve sabit komutlarla çalışır. Uygulama parola istemek için `sudo` etkileşimli terminali açmaz.

## Sorun giderme

- **SSH erişilemiyor:** `ssh -v alias true` ile Terminal bağlantısını kontrol edin; alias ve host key eşleşmesini doğrulayın.
- **Bilinmiyor:** Son taramanın zamanını ve ilgili kontrolün açıklamasını inceleyin. Uzak komutun ölçüm döndürmemesi güvenli biçimde bilinmiyor sayılır.
- **Disk/backup kritik:** Eşik değerini düşürmek yerine önce uzak sunucudaki gerçek kullanım ve yedek zamanını doğrulayın.
- **Uygulama açılmıyor:** Kaynak koddan çalıştırmada `swift test` ve `swift build -c release` çıktısını alın. Release paketinde checksum, imza ve notarization durumunu kontrol edin.

## Kaldırma ve yerel veriyi temizleme

Uygulamayı kapatıp `VPS Gözcü.app` paketini Applications klasöründen taşıyın. Yerel profilleri ve geçmişi de kaldırmak isterseniz şu klasörü ayrıca silin:

```text
~/Library/Application Support/VPSGozcu/
```

Bu klasörü silmek yalnızca Mac'teki yerel profilleri, metrik geçmişini ve olayları kaldırır; VPS üzerinde herhangi bir işlem yapmaz.
