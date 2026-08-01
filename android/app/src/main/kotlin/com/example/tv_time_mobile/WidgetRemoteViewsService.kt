package com.example.tv_time_mobile

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class WidgetRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WidgetRemoteViewsFactory(this.applicationContext, intent)
    }
}

class WidgetRemoteViewsFactory(private val context: Context, private val intent: Intent) : RemoteViewsService.RemoteViewsFactory {
    private var widgetDataList = ArrayList<WidgetListItem>()
    private val widgetType = intent.getStringExtra("WIDGET_TYPE") ?: "up_next" // "up_next" or "calendar"

    override fun onCreate() {}

    override fun onDataSetChanged() {
        widgetDataList.clear()
        val prefs = HomeWidgetPlugin.getData(context)
        val jsonString = prefs.getString("${widgetType}_list_data", "[]") ?: "[]"
        
        try {
            val jsonArray = JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                widgetDataList.add(WidgetListItem(
                    title = obj.getString("title"),
                    subtitle = obj.getString("subtitle"),
                    imagePath = obj.optString("image_path", null),
                    id = obj.optString("id", ""),
                    tmdbId = obj.optString("tmdb_id", ""),
                    type = obj.optString("type", "")
                ))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        widgetDataList.clear()
    }

    override fun getCount(): Int = widgetDataList.size

    override fun getViewAt(position: Int): RemoteViews {
        val item = widgetDataList[position]
        val views = RemoteViews(context.packageName, R.layout.widget_list_item)
        
        views.setTextViewText(R.id.item_title, item.title)
        views.setTextViewText(R.id.item_subtitle, item.subtitle)

        if (!item.imagePath.isNullOrEmpty()) {
            val bitmap = BitmapFactory.decodeFile(item.imagePath)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.item_poster, bitmap)
            } else {
                views.setImageViewResource(R.id.item_poster, android.R.color.transparent)
            }
        } else {
            views.setImageViewResource(R.id.item_poster, android.R.color.transparent)
        }

        if (item.tmdbId.isNotEmpty() && item.type.isNotEmpty()) {
            val fillInIntent = Intent().apply {
                data = android.net.Uri.parse("tvtime://show/${item.tmdbId}/${item.type}")
            }
            views.setOnClickFillInIntent(R.id.widget_list_item_root, fillInIntent)
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}

data class WidgetListItem(
    val title: String,
    val subtitle: String,
    val imagePath: String?,
    val id: String,
    val tmdbId: String,
    val type: String
)
