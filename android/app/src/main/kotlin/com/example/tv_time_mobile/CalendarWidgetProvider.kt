package com.example.tv_time_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class CalendarWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.calendar_widget_layout).apply {
                val item1 = widgetData.getString("widget_cal_item_1", "No upcoming shows")
                setTextViewText(R.id.widget_cal_item_1, item1)

                val item2 = widgetData.getString("widget_cal_item_2", "")
                setTextViewText(R.id.widget_cal_item_2, item2)
                
                val item3 = widgetData.getString("widget_cal_item_3", "")
                setTextViewText(R.id.widget_cal_item_3, item3)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
