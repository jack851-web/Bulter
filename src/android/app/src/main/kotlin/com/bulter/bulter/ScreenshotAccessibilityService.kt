package com.bulter.bulter

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.graphics.ColorSpace
import android.graphics.HardwareBuffer
import android.os.Build
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.Executor

/**
 * Bulter 无障碍服务（Step 10）—— **系统级截图**。
 *
 * **完全参考另一 Android 项目的截图实现**：
 * - 用 `AccessibilityService.takeScreenshot()`（Android 11+ API 30+），**不**用 MediaProjection
 * - `HardwareBuffer → Bitmap.wrapHardwareBuffer → copy(ARGB_8888)` 复用 GPU
 * - `MainThreadExecutor` 把回调投递回主线程
 * - 错误码映射 4 种
 *
 * **重要**：**不要在 `onServiceConnected` 调用 `setServiceInfo()`**，会清空 XML 标志。
 */
class ScreenshotAccessibilityService : AccessibilityService() {

    interface CaptureCallback {
        fun onSuccess(path: String)
        fun onError(errorCode: Int, message: String)
    }

    private val mainThreadExecutor = Executor { command -> command?.run() }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onInterrupt() {}

    fun capture(callback: CaptureCallback) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            callback.onError(ERROR_NO_ACCESSIBILITY, "需要 Android 11 (API 30) 及以上")
            return
        }
        try {
            takeScreenshot(
                android.view.Display.DEFAULT_DISPLAY,
                mainThreadExecutor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(result: ScreenshotResult) {
                        try {
                            val hwBuffer = result.hardwareBuffer
                            val bitmap = hardwareBufferToBitmap(hwBuffer)
                            hwBuffer.close()
                            val path = savePng(bitmap)
                            bitmap.recycle()
                            callback.onSuccess(path)
                        } catch (e: Exception) {
                            callback.onError(ERROR_INTERNAL, "保存截图失败: ${e.message}")
                        }
                    }
                    override fun onError(errorCode: Int) {
                        val (mapped, msg) = mapError(errorCode)
                        callback.onError(mapped, msg)
                    }
                }
            )
        } catch (e: Exception) {
            callback.onError(ERROR_INTERNAL, "takeScreenshot 异常: ${e.message}")
        }
    }

    private fun hardwareBufferToBitmap(hwBuffer: HardwareBuffer): Bitmap {
        val raw = Bitmap.wrapHardwareBuffer(hwBuffer, ColorSpace.get(ColorSpace.Named.SRGB))
            ?: throw IllegalStateException("wrapHardwareBuffer returned null")
        val copy = raw.copy(Bitmap.Config.ARGB_8888, false)
        raw.recycle()
        return copy
    }

    private fun savePng(bitmap: Bitmap): String {
        val dir = File(filesDir, "screenshots").apply { mkdirs() }
        val id = UUID.randomUUID().toString()
        val file = File(dir, "$id.png")
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        return file.absolutePath
    }

    private fun mapError(errorCode: Int): Pair<Int, String> {
        return when (errorCode) {
            ERROR_INTERNAL -> ERROR_INTERNAL to "系统内部错误"
            ERROR_INTERVAL_TOO_SHORT -> ERROR_INTERVAL_TOO_SHORT to "截图太频繁（系统限流）"
            ERROR_NO_ACCESSIBILITY -> ERROR_NO_ACCESSIBILITY to "无障碍未授权"
            ERROR_SECURE_WINDOW -> ERROR_SECURE_WINDOW to "当前是 FLAG_SECURE 窗口（如银行 App）"
            else -> ERROR_INTERNAL to "未知错误 (code=$errorCode)"
        }
    }

    companion object {
        @Volatile
        var instance: ScreenshotAccessibilityService? = null
            private set

        // 系统错误码（来自 android.accessibilityservice.AccessibilityService）
        const val ERROR_INTERNAL = 1
        const val ERROR_INTERVAL_TOO_SHORT = 2
        const val ERROR_NO_ACCESSIBILITY = 3
        const val ERROR_SECURE_WINDOW = 4
    }
}
