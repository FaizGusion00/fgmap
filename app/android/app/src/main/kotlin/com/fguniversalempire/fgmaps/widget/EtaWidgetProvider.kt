package com.fguniversalempire.fgmaps.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.fguniversalempire.fgmaps.R
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget skrin utama: ETA ke Rumah dan Kerja. Data ditulis oleh Dart (`EtaWidgetUpdater` melalui
 * home_widget); kelas ini hanya membaca dan melukis, tanpa rangkaian atau GPS (jimat bateri).
 * Kunci mesti sama dengan `eta_widget_payload.dart`.
 */
class EtaWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.eta_widget)
            bindRow(
                views,
                widgetData,
                labelId = R.id.eta_home_label,
                valueId = R.id.eta_home_value,
                labelKey = "eta_home_label",
                valueKey = "eta_home_value",
                setKey = "eta_home_set",
                defaultLabel = "Home",
            )
            bindRow(
                views,
                widgetData,
                labelId = R.id.eta_work_label,
                valueId = R.id.eta_work_value,
                labelKey = "eta_work_label",
                valueKey = "eta_work_value",
                setKey = "eta_work_set",
                defaultLabel = "Work",
            )
            // Ketik di mana-mana sahaja membuka app (untuk tetapkan tempat atau lihat laluan).
            views.setOnClickPendingIntent(R.id.eta_widget_root, launchIntent(context))
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun bindRow(
        views: RemoteViews,
        data: SharedPreferences,
        labelId: Int,
        valueId: Int,
        labelKey: String,
        valueKey: String,
        setKey: String,
        defaultLabel: String,
    ) {
        views.setTextViewText(labelId, data.getString(labelKey, null) ?: defaultLabel)
        val value = data.getString(valueKey, null)
        // Belum pernah dikemas kini: tunjuk sempang supaya tidak kosong.
        views.setTextViewText(valueId, value ?: "—")
        // Tempat belum ditetapkan (CTA) dipaparkan lebih halus daripada ETA sebenar.
        val isSet = data.getBoolean(setKey, false)
        views.setFloat(valueId, "setAlpha", if (isSet) 1f else 0.7f)
        views.setViewVisibility(valueId, View.VISIBLE)
    }

    private fun launchIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent()
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flags = flags or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(context, 0, intent, flags)
    }
}
