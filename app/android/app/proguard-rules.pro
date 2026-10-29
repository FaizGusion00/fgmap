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
