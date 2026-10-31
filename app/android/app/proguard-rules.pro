# Enjin laluan offline (valhalla-mobile): kod natif (libvalhalla-wrapper.so) memanggil balik dan mencipta
# kelas Kotlin/Java mengikut NAMA melalui JNI, jadi R8 tidak boleh mengaburkan atau membuangnya.
# Tanpa ini, build release boleh ranap (hanya pada release dan hanya apabila laluan ralat dicapai).
-keep class com.valhalla.valhalla.** { *; }

# Mana-mana kaedah `native` dan kelas yang memilikinya.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Android Auto dan MapLibre pada permukaan kereta.
-keep class androidx.car.app.** { *; }
-keep class com.fguniversalempire.fgmaps.car.** { *; }
-dontwarn androidx.car.app.**

# WorkManager (ditarik masuk oleh home_widget -> glance-appwidget -> work-runtime 2.7.1 -> room 2.2.5).
# Peraturan simpan Room lama hanya menyimpan nama kelas, bukan konstruktor kosongnya. R8 mod penuh
# membuang konstruktor itu, lalu Room gagal mencipta WorkDatabase_Impl melalui refleksi dan app ranap
# ketika bermula ("Failed to create an instance of androidx.work.impl.WorkDatabase"), sebelum Flutter
# sempat jalan. Hanya berlaku pada build release.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
