package com.kg.yibiao

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object Remind {
    fun schedule(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(ctx, 7, Intent(ctx, RemindReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val c = Calendar.getInstance()
        c.set(Calendar.HOUR_OF_DAY, 8); c.set(Calendar.MINUTE, 30); c.set(Calendar.SECOND, 0)
        if (c.timeInMillis <= System.currentTimeMillis()) c.add(Calendar.DAY_OF_YEAR, 1)
        am.setInexactRepeating(AlarmManager.RTC_WAKEUP, c.timeInMillis, AlarmManager.INTERVAL_DAY, pi)
    }

    fun check(ctx: Context) {
        val s = ctx.getSharedPreferences("zs", Context.MODE_PRIVATE).getString("due", null) ?: return
        val o = JSONObject(s)
        val warn = o.optInt("warn", 30)
        val arr = o.optJSONArray("dates") ?: return
        val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val today = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }.timeInMillis
        var over = 0; var soon = 0; var first: String? = null
        for (i in 0 until arr.length()) {
            val d = try { fmt.parse(arr.getString(i))?.time } catch (e: Exception) { null } ?: continue
            val days = ((d - today) / 86400000L).toInt()
            if (days < 0) over++ else if (days <= warn) { soon++; if (first == null || arr.getString(i) < first) first = arr.getString(i) }
        }
        if (over == 0 && soon == 0) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel("due", "校验到期提醒", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val text = (if (over > 0) "已过期 $over 台；" else "") + (if (soon > 0) "${warn}天内到期 $soon 台（最早 $first）" else "")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, "due") else Notification.Builder(ctx)
        b.setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle("仪表校验到期提醒").setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text)).setContentIntent(open).setAutoCancel(true)
        try { nm.notify(1, b.build()) } catch (e: SecurityException) {}
    }
}

class RemindReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) { Remind.schedule(ctx); return }
        Remind.check(ctx)
    }
}
