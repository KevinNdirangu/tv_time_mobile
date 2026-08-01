package com.example.tv_time_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class UpNextWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val showTitle = widgetData.getString("widget_show_title", "No shows up next")
                setTextViewText(R.id.widget_show_title, showTitle)

                val episodeTitle = widgetData.getString("widget_episode_title", "Open app to sync")
                setTextViewText(R.id.widget_episode_title, episodeTitle)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
