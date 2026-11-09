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
    val noResults
        get() = if (malay) "Tiada hasil. Semak sambungan internet." else "No results. Check your internet connection."
    val cruise get() = if (malay) "Memandu bebas" else "Free driving"
    val cannotStart get() = if (malay) "Tidak dapat mulakan laluan" else "Couldn't start the route"
    val tollsOnRoute
        get() = if (malay) "Tiada laluan tanpa tol. Laluan ini ada tol." else "No toll-free route. This route has tolls."
    val place get() = if (malay) "Tempat" else "Place"
    val arrived get() = if (malay) "Anda telah tiba" else "You have arrived"
}
