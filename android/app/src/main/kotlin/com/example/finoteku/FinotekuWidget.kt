package id.ridhoarmand.finoteku

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Home-screen widget: balance, today's spending, how long since the last record,
 * and "+ Catat". The app writes the data (lib/services/home_widget_service.dart);
 * "last recorded" is worked out here so it keeps ageing without opening the app.
 */
class FinotekuWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views(context, widgetData))
        }
    }

    private fun views(context: Context, data: SharedPreferences) =
        RemoteViews(context.packageName, R.layout.finoteku_widget).apply {
            fun label(key: String, fallback: String) = data.getString(key, null) ?: fallback
            val today = LocalDate.now()

            setOnClickPendingIntent(R.id.widget_root, launch(context, null, 0))
            setOnClickPendingIntent(R.id.widget_add, launch(context, Uri.parse("finoteku://add"), 1))
            setTextViewText(R.id.widget_add, "+ " + label("w_add", "Catat"))

            if (!data.getBoolean("signed_in", false)) {
                setTextViewText(R.id.widget_balance, "")
                setTextViewText(R.id.widget_today, "Finoteku")
                setTextViewText(R.id.widget_last, "Buka app untuk masuk")
                setTextColor(R.id.widget_last, context.getColor(R.color.widget_muted))
                return@apply
            }

            setTextViewText(R.id.widget_balance_label, label("w_balance", "Saldo"))
            setTextViewText(R.id.widget_balance, data.getString("balance", "") ?: "")
            setTextViewText(R.id.widget_today_label, label("w_today", "Keluar hari ini"))
            // a snapshot from another day says nothing about today
            val sameDay = data.getString("snapshot_day", null) == today.toString()
            setTextViewText(R.id.widget_today, if (sameDay) data.getString("today_expense", "Rp 0") else "Rp 0")

            val last = data.getString("last_entry_day", "")?.takeIf { it.isNotEmpty() }?.let(LocalDate::parse)
            val days = last?.let { ChronoUnit.DAYS.between(it, today) }
            val ago = when {
                days == null -> label("w_last_never", "belum ada")
                days <= 0 -> label("w_last_today", "hari ini")
                days == 1L -> label("w_last_yesterday", "kemarin")
                else -> label("w_last_days", "{n} hari lalu").replace("{n}", days.toString())
            }
            setTextViewText(R.id.widget_last, label("w_last", "Terakhir dicatat") + ": " + ago)
            // two days or more without a record: show it in the warning colour
            val stale = days == null || days >= 2
            setTextColor(R.id.widget_last, context.getColor(if (stale) R.color.widget_expense else R.color.widget_muted))
        }

    /** Opens MainActivity; with [uri], home_widget hands it to Flutter (widgetClicked). */
    private fun launch(context: Context, uri: Uri?, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            if (uri != null) {
                action = "es.antonborri.home_widget.action.LAUNCH"
                data = uri
            }
        }
        return PendingIntent.getActivity(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
