# Persediaan CarPlay (FGMaps)

Kod CarPlay sudah ada dalam repo (`app/ios/Runner/CarPlay/`), tetapi CarPlay **tidak aktif** sehingga
binari ditandatangani dengan entitlement navigasi daripada Apple. Tanpa entitlement, iOS tidak pernah
mencipta adegan CarPlay, jadi app biasa (simulator, build dev, CI) berjalan seperti sebelumnya.

Keputusan reka bentuk: [ADR 0013](adr/0013-along-route-cameras-widgets-carplay.md).

## Apa yang dibina

| Fail | Peranan |
| --- | --- |
| `app/ios/Runner/CarPlay/CarBridge.swift` | Cermin `CarBridge.kt`. MethodChannel `com.fguniversalempire.fgmaps/car`; menyimpan gambar sesi (`session`) dan laluan terakhir; memanggil Flutter `search`, `openPlace`, `endNavigation`, `recenter`, `pan`. |
| `app/ios/Runner/CarPlay/CarPlaySceneDelegate.swift` | `CPTemplateApplicationSceneDelegate`. `CPMapTemplate` + `CPNavigationSession` (teks manuver, jarak, ETA, butang **Tamat**); mod browse: butang **Cari** (`CPSearchTemplate`) dan **Pusatkan**. |
| `app/ios/Runner/AppDelegate.swift` | Memasang `CarBridge` pada enjin Flutter (`didInitializeImplicitFlutterEngine`). |
| `app/ios/Runner/Info.plist` | Konfigurasi adegan `CPTemplateApplicationSceneSessionRoleApplication` dan `UIApplicationSupportsMultipleScenes = true`. |
| `app/test/features/navigation/carplay_channel_test.dart` | Kontrak nama saluran/kaedah Dart <-> Kotlin <-> Swift. |

Had semasa (susulan): peta tidak dilukis pada skrin CarPlay (hanya panel templat + warna jenama);
memerlukan lapisan MapLibre native pada `CPWindow`. Adegan CarPlay juga mengandaikan enjin Flutter
sudah hidup; jika CarPlay disambung ketika app tidak berjalan, skrin kereta memaparkan
"Buka FGMaps pada iPhone" sehingga telefon melancarkan app.

## Senarai semak entitlement (Apple Developer)

1. **Mohon entitlement** di <https://developer.apple.com/contact/carplay/> sebagai *Navigation* app
   (`com.apple.developer.carplay-maps`). Perlu akaun Apple Developer Program berbayar; kelulusan boleh
   mengambil masa beberapa minggu. Sediakan penerangan app, bundle ID `com.fguniversalempire.fgmaps`
   dan butiran kawasan liputan (Malaysia).
2. Selepas diluluskan, di *Certificates, Identifiers & Profiles* > *Identifiers* > App ID FGMaps:
   semak **CarPlay Navigation App** (atau capability yang tertera) sudah diaktifkan.
3. **Jana semula provisioning profile** (Development dan App Store/Distribution) untuk App ID itu;
   profil lama tidak mengandungi entitlement baru. Muat turun / biar Xcode urus automatik.
4. Dalam Xcode: target **Runner** > *Signing & Capabilities* > tambah **CarPlay** (jika tersenarai) atau
   cipta `app/ios/Runner/Runner.entitlements` dengan:

   ```xml
   <key>com.apple.developer.carplay-maps</key>
   <true/>
   ```

   dan tetapkan *Code Signing Entitlements* = `Runner/Runner.entitlements` untuk konfigurasi Debug,
   Profile dan Release. **Jangan** komit fail entitlement ini sebelum Apple meluluskan: build tanpa
   profil yang sepadan akan gagal menandatangani.
5. Info.plist (sudah ditambah dalam repo, semak jika ada pertukaran Xcode):
   - `UIApplicationSceneManifest` > `UIApplicationSupportsMultipleScenes` = `true`.
   - `UISceneConfigurations` > `CPTemplateApplicationSceneSessionRoleApplication` > item dengan
     `UISceneClassName` = `CPTemplateApplicationScene`, `UISceneConfigurationName` = `CarPlay`,
     `UISceneDelegateClassName` = `$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate`.
   - Adegan telefon kekal `UIWindowSceneSessionRoleApplication` > `SceneDelegate` (Flutter).
6. Fail projek: `CarBridge.swift` dan `CarPlaySceneDelegate.swift` sudah didaftarkan dalam
   `Runner.xcodeproj` (kumpulan *CarPlay*).
7. `UIBackgroundModes` sedia ada (`location`, `audio`) memadai untuk navigasi + arahan suara.

## Ujian

- **Simulator**: *I/O > External Displays > CarPlay* dalam Simulator. Tanpa entitlement, adegan tidak
  muncul (ini normal). Dengan entitlement pada profil dev, ikon FGMaps muncul pada skrin CarPlay.
- Mula navigasi pada telefon: skrin CarPlay memaparkan manuver, jarak ke manuver, ETA dan **Tamat**.
- Tekan **Tamat** pada CarPlay: telefon menamatkan navigasi (`endNavigation`).
- Mod browse: **Cari** > taip > pilih tempat memulakan laluan (`search` + `openPlace`).
- Pastikan app masih dilancarkan seperti biasa di iPhone tanpa CarPlay (regresi).

## Android Auto

Tidak berubah. Saluran dan bentuk muatan sama; `STORE_BUILD` masih mengunci hos Android Auto sahaja.
