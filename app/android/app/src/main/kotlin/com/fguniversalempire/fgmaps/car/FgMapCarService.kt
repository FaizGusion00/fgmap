package com.fguniversalempire.fgmaps.car

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator
import com.fguniversalempire.fgmaps.BuildConfig

/**
 * Hos Android Auto. Flutter kekal otak sesi; skrin kereta hanya memaparkan gambar sesi itu.
 *
 * Senarai rasmi dalam car-app 1.7.0 hanya ada tiga sijil gearhead. Unit sebenar (termasuk
 * Proton X50) menolak hos yang ditandatangani dengan sijil Android Auto yang lebih baharu,
 * dan pelancar menyembunyikan aplikasi. Binaan kedai sahaja kekal pada senarai itu.
 */
class FgMapCarService : CarAppService() {
    override fun createHostValidator(): HostValidator {
        if (!BuildConfig.STORE_BUILD) return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        return HostValidator.Builder(applicationContext)
            .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
            .build()
    }

    override fun onCreateSession(): Session = FgMapSession()
}
