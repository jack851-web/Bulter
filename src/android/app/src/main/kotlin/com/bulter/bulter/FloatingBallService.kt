package com.bulter.bulter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * Bulter 浮窗前台服务（Step 10）—— **空壳保活**。
 *
 * **完全参考另一项目的"前台服务空壳"模式**：
 * - 启动前台服务保持进程存活
 * - 通过 `AppEventBus.requestShowFloatingBall()` 回调 MainActivity 真正 `addView`
 * - **不持有 Activity 引用**——避免泄漏
 * - 划掉卡片时 `onTaskRemoved()` → `stopSelf()`
 * - 无权限时 `START_NOT_STICKY` 避免"重启失败被杀"循环
 */
class FloatingBallService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        AppEventBus.requestShowFloatingBall()
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        stopSelf()
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    "Bulter 浮窗",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "长按浮窗可截图 / 语音输入"
                    setShowBadge(false)
                }
                nm.createNotificationChannel(ch)
            }
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Bulter 浮窗运行中")
            .setContentText("长按浮窗可截图 / 语音输入")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .build()
    }

    companion object {
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "bulter_floating"

        @JvmStatic
        fun start(context: Context) {
            val intent = Intent(context, FloatingBallService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        @JvmStatic
        fun stop(context: Context) {
            context.stopService(Intent(context, FloatingBallService::class.java))
        }
    }
}
