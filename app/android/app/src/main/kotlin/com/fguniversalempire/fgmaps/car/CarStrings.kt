package com.fguniversalempire.fgmaps.car

import java.util.Locale

/**
 * Teks skrin kereta: Melayu jika bahasa peranti Melayu, selainnya Inggeris (sama seperti `CarText` dalam
 * CarPlaySceneDelegate.swift). Kata-kata di skrin kereta mesti ringkas; pemandu hanya sempat membaca sekilas.
 */
object CarStrings {
    private val malay: Boolean
        get() = Locale.getDefault().language == "ms"

    val search get() = if (malay) "Cari" else "Search"
    val nearby get() = if (malay) "Berdekatan" else "Nearby"
    val end get() = if (malay) "Tamat" else "End"
    val searchHint get() = if (malay) "Cari destinasi" else "Search destination"
    val typeDestination get() = if (malay) "Taip atau sebut destinasi" else "Type or say a destination"
    val searching get() = if (malay) "Mencari…" else "Searching…"
    val noResults get() = if (malay) "Tiada hasil. Cuba nama lain." else "No results. Try another name."
    val starting get() = if (malay) "Memulakan FGMaps…" else "Starting FGMaps…"
    val startingRetry
        get() = if (malay) "FGMaps sedang dimulakan. Cuba lagi sebentar." else "FGMaps is starting. Try again in a moment."
    val noLocation
        get() = if (malay) "Lokasi belum tersedia. Pastikan GPS telefon hidup." else "Location not available yet. Make sure phone GPS is on."
    val searchFailed
        get() = if (malay) "Carian gagal. Semak internet dan cuba lagi." else "Search failed. Check internet and try again."

    /**
     * Mesej senarai kosong ikut sebab sebenar. Dahulu setiap senarai kosong berkata "semak internet",
     * termasuk bila enjin app belum bermula atau GPS belum ada.
     */
    fun emptyMessage(failure: CarFailure?): String = when (failure) {
        null -> noResults
        CarFailure.STARTING -> startingRetry
        CarFailure.NO_LOCATION -> noLocation
        CarFailure.FAILED -> searchFailed
        CarFailure.NO_ROUTE -> noRoute
    }

    val places get() = if (malay) "Tempat" else "Places"
    val home get() = if (malay) "Rumah" else "Home"
    val work get() = if (malay) "Kerja" else "Work"
    val favorites get() = if (malay) "Kegemaran" else "Favourites"
    val recents get() = if (malay) "Terkini" else "Recent"
    val report get() = if (malay) "Lapor" else "Report"
    val settings get() = if (malay) "Tetapan" else "Settings"
    val go get() = if (malay) "Mula" else "Go"
    val retry get() = if (malay) "Cuba lagi" else "Retry"
    val notSet get() = if (malay) "Belum ditetapkan" else "Not set"
    val homeNotSet
        get() = if (malay) "Tetapkan Rumah dalam app FGMaps di telefon" else "Set Home in the FGMaps phone app"
    val workNotSet
        get() = if (malay) "Tetapkan Kerja dalam app FGMaps di telefon" else "Set Work in the FGMaps phone app"
    val noFavorites
        get() = if (malay) "Tiada kegemaran. Simpan tempat dalam app telefon." else "No favourites. Save places in the phone app."
    val noRecents get() = if (malay) "Tiada carian terkini." else "No recent searches."
    val noRoute get() = if (malay) "Tiada laluan ditemui. Cuba lagi." else "No route found. Try again."
    val reportWhat get() = if (malay) "Apa yang berlaku?" else "What's happening?"
    val reportSent get() = if (malay) "Terima kasih. Laporan dihantar." else "Thanks. Report sent."
    val reportConfirmed get() = if (malay) "Laporan disahkan. Terima kasih." else "Report confirmed. Thanks."
    val reportFailed get() = if (malay) "Laporan gagal. Cuba lagi." else "Report failed. Try again."
    val voice get() = if (malay) "Suara panduan" else "Voice guidance"
    val avoidTolls get() = if (malay) "Elak tol" else "Avoid tolls"
    val avoidTollsHint get() = if (malay) "Untuk laluan seterusnya" else "For your next route"
    val cameras get() = if (malay) "Amaran kamera laju" else "Speed camera alerts"
    val satellite get() = if (malay) "Peta satelit" else "Satellite map"
    val voiceOn get() = if (malay) "Suara dihidupkan" else "Voice on"
    val voiceOff get() = if (malay) "Suara dimatikan" else "Voice muted"
    val cruise get() = if (malay) "Memandu bebas" else "Free driving"
    val cannotStart get() = if (malay) "Tidak dapat mulakan laluan" else "Couldn't start the route"
    val tollsOnRoute
        get() = if (malay) "Tiada laluan tanpa tol. Laluan ini ada tol." else "No toll-free route. This route has tolls."
    val place get() = if (malay) "Tempat" else "Place"
    val arrived get() = if (malay) "Anda telah tiba" else "You have arrived"
}
