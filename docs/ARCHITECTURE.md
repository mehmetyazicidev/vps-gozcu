# Mimari

## Hedef

VPS Gözcü, küçük sayıdaki farklı VPS'leri ek sunucu maliyeti yaratmadan tek Mac üzerinden izler. Uygulama kapalıyken izleme yapılmaması bilinçli bir ürün sınırıdır.

## Akış

```text
SwiftUI arayüzü
    -> AppModel / zamanlayıcı
        -> /usr/bin/ssh
            -> salt-okunur Linux komutları
        -> ProbeParser
            -> ServerSnapshot
                -> kartlar, grafikler, olaylar ve yerel bildirimler
```

## Güvenlik modeli

- Uygulama sistemdeki SSH config, agent ve anahtar zincirini kullanır.
- Private key içeriğini okumaz veya kopyalamaz.
- Bilinmeyen host key'lerini otomatik kabul etmez.
- Remote probe komutları kaynak kodda sabittir; kullanıcıdan keyfi shell komutu alınmaz.
- App path, backup path ve health URL değerleri shell argümanı olmadan önce tek tırnak güvenli biçimde quote edilir.
- Gelecekteki bakım eylemleri izleme kullanıcısından ayrılır ve dar `sudoers` komut listesi kullanır.
- `MaintenancePlanner` güncelleme/reboot gereksinimini ve yedek tazeliğini değerlendirir.
- `MaintenanceExecutor` yalnızca plan hazırsa ve kullanıcı açık onay verirse sabit paket güncelleme veya reboot komutunu çalıştırır; `sudo -n` parola istemez ve yedek yaşını uzakta yeniden kontrol eder.
- `MaintenancePlanner` güncelleme/reboot gereksinimini ve yedek tazeliğini değerlendirir; gerçek yazma işlemi yapmaz.

## Güncelleme politikası

- Okuma: bekleyen paketler, güvenlik paketleri, çalışan kernel, reboot-required, Docker/Compose sürümleri.
- Otomatik: mevcut sunucu unattended-upgrades politikasının sonucu yalnızca görüntülenir.
- Manuel bakım: Docker, PostgreSQL, Caddy, kernel reboot ve uygulama deploy işlemleri.
- Her yazma işlemi için ayrı kullanıcı onayı, güncel yedek, sağlık kontrolü ve geri dönüş kaydı gerekir.

## Veri modeli

- `ServerProfile`: SSH hedefi ve sunucuya özgü yollar.
- `ServerSnapshot`: tek sorgu anındaki normalize durum.
- `HealthCheck`: her salt-okunur kontrolün ayrı sağlık seviyesi ve kullanıcıya gösterilen gerekçesi.
- `MetricSample`: grafik geçmişi.
- `MonitorEvent`: kullanıcı tarafından okunabilir olay akışı.

## Güvenilirlik kuralları

- Eksik veya ayrıştırılamayan sayısal değerler `0` kabul edilmez; `Bilinmiyor` durumuna dönüşür.
- Genel sağlık seviyesi tek tek `HealthCheck` sonuçlarından türetilir.
- Öncelik sırası kritik, uyarı, bilinmiyor ve sağlıklı şeklindedir.
- Aynı sağlık seviyesinde uyarı nedeni değişirse yeni olay kaydı üretilir.
- Son başarılı tarama, bağlantı hatası oluşsa bile kullanıcıya ayrıca gösterilir.
- SSH sorgusu geçici ağ hatalarını azaltmak için en fazla iki kez denenir.
- Yedek yaşı klasör adından tahmin edilmez; sunucudaki gerçek değiştirilme zamanından hesaplanır.
- HTTPS profillerinde sertifika bitiş tarihi OpenSSL ile salt-okunur alınır; HTTP sağlık kontrolü sertifika doğrulamasını ayrıca sürdürür.
- Varsayılan yedek eşikleri 26 saat uyarı ve 48 saat kritik; TLS eşikleri 30 gün uyarı ve 7 gün kritiktir.

## Maliyet

İlk sürüm yalnızca macOS ve VPS'lerde zaten bulunan SSH/Linux araçlarını kullanır. Harici abonelik, ajan veya merkezi sunucu yoktur.
