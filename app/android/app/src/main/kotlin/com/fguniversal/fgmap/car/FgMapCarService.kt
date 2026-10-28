package com.fguniversal.fgmap.car

import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

/**
 * Hos Android Auto. Flutter kekal otak sesi; skrin kereta hanya memaparkan gambar sesi itu.
 */
class FgMapCarService : CarAppService() {
    override fun createHostValidator(): HostValidator {
        val debuggable =
            applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        if (debuggable) return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        return HostValidator.Builder(applicationContext)
            .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist)
            .build()
    }

    override fun onCreateSession(): Session = FgMapSession()
}
