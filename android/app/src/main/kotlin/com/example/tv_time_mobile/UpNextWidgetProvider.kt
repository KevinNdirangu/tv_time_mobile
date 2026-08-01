package com.example.tv_time_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class UpNextWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = "es.antonborri.home_widget.action.LAUNCH"
                data = Uri.parse("tvtime://home")
            }
            val pendingIntent = android.app.PendingIntent.getActivity(context, 0, launchIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE)
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)

            val templateIntent = Intent(context, MainActivity::class.java).apply {
                action = "es.antonborri.home_widget.action.LAUNCH"
            }
            val pendingTemplate = android.app.PendingIntent.getActivity(context, 1, templateIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE)
            views.setPendingIntentTemplate(R.id.widget_list_view, pendingTemplate)

            val serviceIntent = Intent(context, WidgetRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                putExtra("WIDGET_TYPE", "up_next")
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }

            views.setRemoteAdapter(R.id.widget_list_view, serviceIntent)
            views.setEmptyView(R.id.widget_list_view, R.id.widget_list_view) // Optional empty view

            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list_view)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
