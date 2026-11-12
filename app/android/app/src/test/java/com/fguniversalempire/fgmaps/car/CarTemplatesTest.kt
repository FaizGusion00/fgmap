@file:Suppress("DEPRECATION")

package com.fguniversalempire.fgmaps.car

import androidx.car.app.HandshakeInfo
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.SearchTemplate
import androidx.car.app.navigation.model.MessageInfo
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.PlaceListNavigationTemplate
import androidx.car.app.navigation.model.RoutePreviewNavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.testing.TestCarContext
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Templat skrin kereta dibina dengan data contoh, melalui pengesahan sebenar Car App Library
 * (had tindakan, span jarak/masa wajib, baris boleh dipilih...). Setiap skrin jatuh ke mesej ringkas
 * bila templat ditolak, jadi ujian ini memastikan templat SEBENAR yang dipaparkan, bukan sandaran.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CarTemplatesTest {
    private lateinit var context: TestCarContext

    private val place = mapOf(
        "name" to "Petronas Jalan Ampang",
        "subtitle" to "1.2 km · Ampang",
        "lat" to 3.16,
        "lng" to 101.72,
        "meters" to 1234.0,
        "area" to "Ampang",
    )

    @Before
    fun setUp() {
        context = TestCarContext.createCarContext(RuntimeEnvironment.getApplication())
    }

    @After
    fun tearDown() {
        CarTemplateErrors.clear()
        CarBridge.testReplies = null
        CarBridge.setSessionForTest(emptyMap())
    }

    private fun reply(vararg pairs: Pair<String, Any?>) {
        val map = pairs.toMap()
        CarBridge.testReplies = { method, _ -> map[method] }
    }

    @Test
    fun tempat_ialah_grid_dengan_rumah_dan_kerja() {
        reply(
            "places" to mapOf(
                "home" to place + ("name" to "Rumah"),
                "work" to null,
                "favorites" to listOf(place),
                "recents" to emptyList<Any>(),
            ),
        )
        val template = FgMapPlacesHubScreen(context).onGetTemplate()
        assertTrue("dapat ${template.javaClass.simpleName}: ${CarTemplateErrors.last}", template is GridTemplate)
        val items = (template as GridTemplate).singleList!!.items
        assertTrue(items.size >= 6)
    }

    @Test
    fun senarai_tempat_atas_peta_bernombor_dengan_jarak() {
        val places = listOf(
            CarPlace("A", "1.2 km · Ampang", 3.16, 101.72, meters = 1234.0, area = "Ampang"),
            CarPlace("B", "300 m", 3.15, 101.71, meters = 300.0, area = ""),
        )
        val template = FgMapPlaceListScreen(context, "Minyak", places).onGetTemplate()
        assertTrue("dapat ${template.javaClass.simpleName}: ${CarTemplateErrors.last}", template is PlaceListNavigationTemplate)
        assertEquals(2, (template as PlaceListNavigationTemplate).itemList!!.items.size)
    }

    @Test
    fun senarai_tempat_tanpa_lokasi_jatuh_ke_senarai_biasa() {
        val places = listOf(CarPlace("A", "Ampang", 3.16, 101.72))
        val template = FgMapPlaceListScreen(context, "Kegemaran", places).onGetTemplate()
        assertTrue("dapat ${template.javaClass.simpleName}: ${CarTemplateErrors.last}", template is ListTemplate)
    }

    @Test
    fun berdekatan_dimuat_melalui_jambatan() {
        reply("nearby" to listOf(place, place + ("name" to "Shell")))
        val screen = FgMapPlaceListScreen(context, "Minyak") { done -> CarBridge.nearby("fuel", done) }
        val template = screen.onGetTemplate()
        assertTrue("dapat ${template.javaClass.simpleName}: ${CarTemplateErrors.last}", template is PlaceListNavigationTemplate)
    }

    @Test
    fun pilihan_laluan_dengan_masa_jarak_dan_tol() {
        reply(
            "preview" to listOf(
                mapOf(
                    "durationS" to 1500,
                    "distanceM" to 18200,
                    "title" to "Disyorkan",
                    "detail" to "18.2 km · RM 2.50",
                    "points" to listOf(listOf(3.1, 101.6), listOf(3.16, 101.72)),
                ),
                mapOf(
                    "durationS" to 1800,
                    "distanceM" to 16000,
                    "title" to "Tanpa tol",
                    "detail" to "16.0 km · Tiada tol",
                    "points" to listOf(listOf(3.1, 101.6), listOf(3.16, 101.72)),
                ),
            ),
        )
        val screen = FgMapRoutePreviewScreen(context, CarPlace("KLCC", "", 3.158, 101.711))
        val template = screen.onGetTemplate()
        assertTrue("dapat ${template.javaClass.simpleName}: ${CarTemplateErrors.last}", template is RoutePreviewNavigationTemplate)
        val preview = template as RoutePreviewNavigationTemplate
        assertEquals(2, preview.itemList!!.items.size)
        assertNotNull(preview.navigateAction)
    }

    @Test
    fun tiada_laluan_beri_mesej_dan_cuba_lagi() {
        reply("preview" to CarFailure.NO_ROUTE)
        val template = FgMapRoutePreviewScreen(context, CarPlace("X", "", 3.0, 101.0)).onGetTemplate()
        assertTrue("dapat ${template.javaClass.simpleName}: ${CarTemplateErrors.last}", template is MessageTemplate)
        assertEquals(1, (template as MessageTemplate).actions.size)
    }

    @Test
    fun lapor_ialah_grid_jenis_laporan() {
        reply(
            "reportTypes" to listOf(
                "police", "accident", "hazard", "traffic_jam", "road_closed", "broken_down", "flood",
            ).map { mapOf("id" to it, "label" to it) },
        )
        val template = FgMapReportScreen(context).onGetTemplate()
        assertTrue("dapat ${template.javaClass.simpleName}: ${CarTemplateErrors.last}", template is GridTemplate)
        assertTrue((template as GridTemplate).singleList!!.items.size >= 6)
    }

    @Test
    fun tetapan_ialah_suis() {
        reply(
            "settings" to mapOf(
                "voice" to true,
                "avoidTolls" to false,
                "cameras" to true,
                "satellite" to false,
            ),
        )
        val template = FgMapSettingsScreen(context).onGetTemplate()
        assertTrue("dapat ${template.javaClass.simpleName}: ${CarTemplateErrors.last}", template is ListTemplate)
        val rows = (template as ListTemplate).singleList!!.items
        assertEquals(4, rows.size)
    }

    @Test
    fun berdekatan_kategori_dengan_ikon() {
        reply("nearbyCategories" to listOf(mapOf("id" to "fuel", "label" to "Stesen minyak")))
        val template = FgMapNearbyScreen(context).onGetTemplate()
        assertTrue("dapat ${template.javaClass.simpleName}: ${CarTemplateErrors.last}", template is ListTemplate)
    }

    @Test
    fun carian_ialah_templat_carian() {
        assertTrue(FgMapSearchScreen(context).onGetTemplate() is SearchTemplate)
    }

    @Test
    fun skrin_utama_hos_lama_api_1() = mainScreen(1)

    @Test
    fun skrin_utama_hos_baharu_api_7() = mainScreen(7)

    private fun mainScreen(api: Int) {
        @Suppress("RestrictedApi")
        context.updateHandshakeInfo(HandshakeInfo("com.google.android.projection.gearhead", api))
        CarBridge.setSessionForTest(
            mapOf("mode" to "browse", "prayerLine" to "Asar 16:28", "airAqi" to "IPU 42 · Baik"),
        )
        val browse = FgMapNavScreen(context, attachMap = false).onGetTemplate() as NavigationTemplate
        assertTrue("ralat: ${CarTemplateErrors.last}", browse.navigationInfo is MessageInfo)
        // Cari + Tempat + Lapor (templat sandaran hanya ada satu butang).
        assertEquals(3, browse.actionStrip!!.actions.size)

        CarBridge.setSessionForTest(
            mapOf(
                "mode" to "navigating",
                "maneuver" to "Belok kanan ke Jalan Ampang",
                "maneuverKind" to "right",
                "distanceToManeuverM" to 420.0,
                "remainingM" to 12500.0,
                "remainingS" to 1300,
                "etaEpochMs" to System.currentTimeMillis() + 1_300_000L,
                "voice" to true,
            ),
        )
        val nav = FgMapNavScreen(context, attachMap = false).onGetTemplate() as NavigationTemplate
        assertTrue("ralat: ${CarTemplateErrors.last}", nav.navigationInfo is RoutingInfo)
        assertEquals(4, nav.actionStrip!!.actions.size)
        // Pan + pusatkan + senyap pada API 4+; pan sahaja pada API 2-3; tiada jalur pada API 1.
        val mapActions = nav.mapActionStrip?.actions?.size ?: 0
        assertEquals(if (api >= 4) 3 else if (api >= 2) 1 else 0, mapActions)
    }
}
