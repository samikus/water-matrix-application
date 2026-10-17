# WaterMatrix 💧🎨

> **Günlük su takibini ortak bir piksel tuvaline dönüştürün.**  
> Her yudumu kaydedin, arkadaşlarınızla gerçek zamanlı renkleri karıştırın ve günün tüm saatlerini birlikte boyayın.

---

## 📌 Genel Bakış

**WaterMatrix**, **Flutter** ve **Firebase** kullanılarak geliştirilmiş oyunlaştırılmış ve sosyal bir alışkanlık takip mobil uygulamasıdır.

Geleneksel ilerleme çubukları veya mililitre sayaçları yerine su tüketimi, saatlik sekmelere bölünmüş dinamik bir **zaman matrisi** (24 saat × 60 dakika) üzerinde izlenir. Kullanıcılar tek başlarına ya da ekipleriyle birlikte günün tüm dakikalarını boyamaya çalışır. Birden fazla kişi aynı dakikada su içtiğinde, kullanıcıların renkleri matematiksel olarak karışarak yeni bir ton oluşturur ve sağlıklı bir alışkanlığı ortak bir dijital sanat eserine dönüştürür.

---

## ✨ Öne Çıkan Özellikler

- **Saat Bazlı Sekmeli Zaman Çizelgesi:** Günün 24 saatini ayrı sekmelere bölen, her saatin 60 dakikasını detaylı ve odaklı şekilde incelemeyi sağlayan modüler arayüz.
- **Dinamik Renk Karışımı:** Her kullanıcıya özel renk ataması. Aynı dakikada yapılan kayıtlar RGB karışım formülüyle birleşerek ortak içilen anları görselleştirir.
- **Gerçek Zamanlı Senkronizasyon:** Firebase Firestore reaktif veri akışlarıyla tüm ekip üyeleri arasında anlık veri senkronizasyonu.
- **Bireysel ve Takım Meydan Okumaları:** Özel odalar kurma, serileri takip etme ve ister tek günde ister bir haftalık süreçte boş dakikaları tamamlama imkanı.
- **Akıcı ve Optimize Performans:** Düşük bellek tüketimi ve hızlı sekme geçişleri sağlayan optimize widget mimarisi.

---

## 🛠️ Teknolojiler ve Mimari

- **Arayüz & Çatı:** [Flutter](https://flutter.dev/) (Dart)
- **Durum Yönetimi:** [Riverpod](https://riverpod.dev/)
- **Arka Plan & Veritabanı:** [Firebase Firestore](https://firebase.google.com/products/firestore) & Firebase Authentication
- **Renk Sentezi:** Özel renk karışım hesaplamaları ve dinamik durum yönetimi

---

## 🚀 Kurulum

### Gereksinimler

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.x`)
- [Dart SDK](https://dart.dev/get-dart)
- Yapılandırılmış bir [Firebase Projesi](https://console.firebase.google.com/)

### Adımlar

1. **Depoyu klonlayın:**
   ```bash
   git clone https://github.com/kullanici-adi/water-matrix.git
   cd water-matrix
   ```

2. **Bağımlılıkları yükleyin:**
   ```bash
   flutter pub get
   ```

3. **Firebase yapılandırmasını tamamlayın:**
   FlutterFire CLI kullanarak proje ayarlarınızı bağlayın:
   ```bash
   flutterfire configure
   ```

4. **Uygulamayı çalıştırın:**
   ```bash
   flutter run
   ```

---

## 📐 Renk Karışım Mekanizması

İki veya daha fazla kullanıcı $t$ dakikasında su kaydı girdiğinde, kullanıcıların RGB vektörleri ağırlıklı toplamsal ortalama yöntemiyle birleştirilir:

$$\mathbf{C}_{\text{sonuç}} = \left( \frac{R_1 + R_2}{2}, \frac{G_1 + G_2}{2}, \frac{B_1 + B_2}{2} \right)$$

Bu yaklaşım, eşzamanlı tüketilen anlarda tuval üzerinde özgün ara renklerin ortaya çıkmasını sağlar.

---

## 📄 Lisans

Bu proje [MIT Lisansı](LICENSE) kapsamında lisanslanmıştır.