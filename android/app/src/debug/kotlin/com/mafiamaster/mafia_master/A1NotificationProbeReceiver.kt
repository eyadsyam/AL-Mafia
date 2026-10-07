package com.mafiamaster.mafia_master

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat

/** Debug-build-only notification probe; never packaged in release builds. */
class A1NotificationProbeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return

        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "A1 notification verification",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }

        val open = Intent(Intent.ACTION_VIEW, Uri.parse("mafiamaster://online/join/A1B2C3"), context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pending = PendingIntent.getActivity(
            context,
            6103,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        manager.notify(
            6103,
            NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_mafia)
                .setContentTitle("A1 closed-app notification")
                .setContentText("Tap to open the invite route")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pending)
                .build(),
        )
    }

    companion object {
        private const val ACTION = "com.mafiamaster.mafia_master.A1_NOTIFICATION_PROBE"
        private const val CHANNEL = "a1_notification_probe"
    }
}
