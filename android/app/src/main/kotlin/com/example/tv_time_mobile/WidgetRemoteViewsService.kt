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
                    type = obj.optString("type", ""),
                    network = obj.optString("network", null),
                    airDate = obj.optString("air_date", null),
                    airTime = obj.optString("air_time", null),
                    unwatchedCount = obj.optString("unwatched_count", null)
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
        val rv = RemoteViews(context.packageName, R.layout.widget_list_item)
        
        rv.setTextViewText(R.id.item_title, item.title)
        rv.setTextViewText(R.id.item_subtitle, item.subtitle)

        // Handle Upcoming (Calendar) Fields
        if (!item.network.isNullOrEmpty()) {
            rv.setTextViewText(R.id.item_network_badge, item.network)
            rv.setViewVisibility(R.id.item_network_badge, android.view.View.VISIBLE)
        } else {
            rv.setViewVisibility(R.id.item_network_badge, android.view.View.GONE)
        }

        if (item.airDate.isNullOrEmpty() && item.airTime.isNullOrEmpty()) {
            rv.setViewVisibility(R.id.item_right_container, android.view.View.GONE)
        } else {
            rv.setViewVisibility(R.id.item_right_container, android.view.View.VISIBLE)
            if (item.airDate.isNullOrEmpty()) {
                rv.setViewVisibility(R.id.item_air_date, android.view.View.GONE)
            } else {
                rv.setTextViewText(R.id.item_air_date, item.airDate)
                rv.setViewVisibility(R.id.item_air_date, android.view.View.VISIBLE)
            }
            if (item.airTime.isNullOrEmpty()) {
                rv.setViewVisibility(R.id.item_air_time, android.view.View.GONE)
            } else {
                rv.setTextViewText(R.id.item_air_time, item.airTime)
                rv.setViewVisibility(R.id.item_air_time, android.view.View.VISIBLE)
            }
        }

        // Handle Watch List (Up Next) Fields
        if (!item.unwatchedCount.isNullOrEmpty()) {
            rv.setTextViewText(R.id.item_unwatched_count, item.unwatchedCount)
            rv.setViewVisibility(R.id.item_unwatched_count, android.view.View.VISIBLE)
        } else {
            rv.setViewVisibility(R.id.item_unwatched_count, android.view.View.GONE)
        }

        if (!item.imagePath.isNullOrEmpty()) {
            val bitmap = BitmapFactory.decodeFile(item.imagePath)
            if (bitmap != null) {
                rv.setImageViewBitmap(R.id.item_poster, bitmap)
            } else {
                rv.setImageViewResource(R.id.item_poster, android.R.color.transparent)
            }
        } else {
            rv.setImageViewResource(R.id.item_poster, android.R.color.transparent)
        }

        if (item.tmdbId.isNotEmpty() && item.type.isNotEmpty()) {
            val fillInIntent = Intent().apply {
                data = android.net.Uri.parse("tvtime://show/${item.tmdbId}/${item.type}")
            }
            rv.setOnClickFillInIntent(R.id.widget_list_item_root, fillInIntent)
        }

        return rv
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
    val type: String,
    val network: String?,
    val airDate: String?,
    val airTime: String?,
    val unwatchedCount: String?
)
