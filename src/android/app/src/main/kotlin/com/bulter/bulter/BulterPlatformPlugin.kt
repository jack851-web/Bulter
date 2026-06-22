package com.bulter.bulter

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.AnimationUtils
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformPlugin

/**
 * Bulter 浮窗 + 截图 + Dart 通信插件（Step 10）。
 *
 * **三组件架构（完全照搬参考项目）**：
 * - MainActivity（FlutterActivity）作为宿主
 * - FloatingBallService（前台服务空壳）
 * - ScreenshotAccessibilityService（无障碍服务做系统级截图）
 *
 * **本类是协调者**——在 MainActivity 内 attach，负责：
 * 1. WindowManager 浮窗挂载 + 触摸事件分发
 * 2. 调 ScreenshotAccessibilityService.capture() 截图
 * 3. 3s 冷却 + 错误码映射
 * 4. 通过 dartChannel.invokeMethod("onScreenshotReady", path) 推 Dart
 * 5. 协议版本协商 PROTOCOL_VERSION = 1
 */
class BulterPlatformPlugin(private val activity: android.app.Activity) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val PROTOCOL_VERSION = 1
        const val ENGINE_ID = "bulter_engine"
        const val CHANNEL_NAME = "bulter/ball"
        const val LONG_PRESS_MS = 500L
        const val COOLDOWN_MS = 3000L
    }

    private var channel: MethodChannel? = null
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var params: WindowManager.LayoutParams? = null
    private var currentStatus = BALL_STATUS_IDLE
    private var lastScreenshotAt = 0L
    private var screenshotBusy = java.util.concurrent.atomic.AtomicBoolean(false)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val touchSlop = ViewConfiguration.get(activity).scaledTouchSlop
    private val dp = { v: Int -> TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), activity.resources.displayMetrics
    ).toInt() }

    /** FlutterEngine 启动后绑定到 FlutterEngineCache，供 Service 反查。 */
    fun onAttachedToEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    fun onDetachedFromEngine() {
        channel?.setMethodCallHandler(null)
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "negotiateProtocol" -> result.success(PROTOCOL_VERSION)
                "showFloatingBall" -> {
                    showFloatingBall()
                    result.success(null)
                }
                "hideFloatingBall" -> {
                    hideFloatingBall()
                    result.success(null)
                }
                "isFloatingBallVisible" -> result.success(floatingView != null)
                "stopFloatingService" -> {
                    FloatingBallService.stop(activity)
                    result.success(null)
                }
                "startFloatingService" -> {
                    FloatingBallService.start(activity)
                    result.success(null)
                }
                "getCurrentContactId" -> result.success(null)  // Bulter 不使用
                "ping" -> result.success("pong")
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("BULTER_ERROR", e.message, null)
        }
    }

    /** 主 Activity 显示悬浮球（响应 AppEventBus）。 */
    fun showFloatingBallFromService() {
        mainHandler.post { showFloatingBall() }
    }

    fun stopFloatingBallFromService() {
        mainHandler.post { hideFloatingBall() }
    }

    fun showFloatingBall() {
        if (floatingView != null) return
        val wm = activity.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = wm
        val view = LayoutInflater.from(activity).inflate(R.layout.bulter_floating_button, null)
        floatingView = view
        val p = WindowManager.LayoutParams(
            dp(48), dp(48),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(24)
            y = dp(200)
        }
        params = p
        try {
            wm.addView(view, p)
        } catch (e: Exception) {
            // 无浮窗权限——回退到主 App 内显示
            debugPrint("Failed to addView: ${e.message}")
            floatingView = null
            params = null
            return
        }
        attachTouchHandler(view)
        updateBallStatus(BALL_STATUS_IDLE)
    }

    fun hideFloatingBall() {
        val v = floatingView ?: return
        try {
            windowManager?.removeView(v)
        } catch (_: Exception) { }
        floatingView = null
        params = null
        windowManager = null
    }

    private fun attachTouchHandler(view: View) {
        var initX = 0
        var initY = 0
        var touchStartTime = 0L
        var longPressFired = false
        view.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    initX = params?.x ?: 0
                    initY = params?.y ?: 0
                    touchStartTime = System.currentTimeMillis()
                    longPressFired = false
                    updateBallStatus(BALL_STATUS_HOVERED)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val p = params ?: return@setOnTouchListener false
                    p.x = initX + e.rawX.toInt() - dp(24)
                    p.y = initY + e.rawY.toInt() - dp(24)
                    try {
                        windowManager?.updateViewLayout(view, p)
                    } catch (_: Exception) { }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val duration = System.currentTimeMillis() - touchStartTime
                    val dx = e.rawX.toInt() - (initX + dp(24))
                    val dy = e.rawY.toInt() - (initY + dp(24))
                    val moved = kotlin.math.abs(dx) > touchSlop || kotlin.math.abs(dy) > touchSlop
                    when {
                        longPressFired -> { /* 长按已触发，松手不做事 */ }
                        moved -> { /* 拖动，松开只更新位置 */ }
                        duration < LONG_PRESS_MS -> triggerScreenshot()
                    }
                    updateBallStatus(BALL_STATUS_IDLE)
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    updateBallStatus(BALL_STATUS_IDLE)
                    true
                }
                else -> false
            }
        }
        // 长按检测：500ms 后触发
        mainHandler.postDelayed({
            if (floatingView != null && !longPressFired) {
                longPressFired = true
                triggerLongPress()
            }
        }, LONG_PRESS_MS)
    }

    private fun triggerLongPress() {
        updateBallStatus(BALL_STATUS_LOADING)
        channel?.invokeMethod("onLongPressStart", null)
        // 1.5s 后自动结束（如果用户没松手）
        mainHandler.postDelayed({
            if (floatingView != null) {
                channel?.invokeMethod("onLongPressEnd", null)
                updateBallStatus(BALL_STATUS_IDLE)
            }
        }, 1500)
    }

    private fun triggerScreenshot() {
        // 3s 冷却
        val now = System.currentTimeMillis()
        if (now - lastScreenshotAt < COOLDOWN_MS) {
            channel?.invokeMethod("onToast", "截图太频繁，请稍后再试")
            return
        }
        if (!screenshotBusy.compareAndSet(false, true)) return
        lastScreenshotAt = now
        updateBallStatus(BALL_STATUS_LOADING)
        // 调用 ScreenshotAccessibilityService
        try {
            val service = ScreenshotAccessibilityService.instance
            if (service == null) {
                screenshotBusy.set(false)
                updateBallStatus(BALL_STATUS_ERROR)
                channel?.invokeMethod("onScreenshotError", "NO_ACCESSIBILITY_ACCESS")
                channel?.invokeMethod("onToast", "请先在系统设置中开启 Bulter 无障碍服务")
                mainHandler.postDelayed({ updateBallStatus(BALL_STATUS_IDLE) }, 1500)
                return
            }
            service.capture(object : ScreenshotAccessibilityService.CaptureCallback {
                override fun onSuccess(path: String) {
                    mainHandler.post {
                        screenshotBusy.set(false)
                        updateBallStatus(BALL_STATUS_SUCCESS)
                        channel?.invokeMethod("onScreenshotReady", path)
                        mainHandler.postDelayed({ updateBallStatus(BALL_STATUS_IDLE) }, 1500)
                    }
                }
                override fun onError(errorCode: Int, message: String) {
                    mainHandler.post {
                        screenshotBusy.set(false)
                        updateBallStatus(BALL_STATUS_ERROR)
                        val dartError = when (errorCode) {
                            ScreenshotAccessibilityService.ERROR_INTERNAL -> "INTERNAL_ERROR"
                            ScreenshotAccessibilityService.ERROR_INTERVAL_TOO_SHORT -> "INTERVAL_TIME_SHORT"
                            ScreenshotAccessibilityService.ERROR_NO_ACCESSIBILITY -> "NO_ACCESSIBILITY_ACCESS"
                            ScreenshotAccessibilityService.ERROR_SECURE_WINDOW -> "SECURE_WINDOW"
                            else -> "UNKNOWN"
                        }
                        channel?.invokeMethod("onScreenshotError", dartError)
                        channel?.invokeMethod("onToast", message)
                        mainHandler.postDelayed({ updateBallStatus(BALL_STATUS_IDLE) }, 1500)
                    }
                }
            })
        } catch (e: Exception) {
            screenshotBusy.set(false)
            updateBallStatus(BALL_STATUS_ERROR)
            channel?.invokeMethod("onScreenshotError", "EXCEPTION:${e.message}")
            mainHandler.postDelayed({ updateBallStatus(BALL_STATUS_IDLE) }, 1500)
        }
    }

    private fun updateBallStatus(status: Int) {
        currentStatus = status
        val v = floatingView ?: return
        val iconView = v.findViewById<View>(R.id.ball_icon)
        val loadingView = v.findViewById<View>(R.id.ball_loading_bar)
        when (status) {
            BALL_STATUS_IDLE, BALL_STATUS_HOVERED -> {
                iconView?.visibility = View.VISIBLE
                loadingView?.visibility = View.GONE
                val alpha = if (status == BALL_STATUS_HOVERED) 0.9f else 0.3f
                v.alpha = alpha
            }
            BALL_STATUS_LOADING -> {
                iconView?.visibility = View.GONE
                loadingView?.visibility = View.VISIBLE
                v.alpha = 0.9f
            }
            BALL_STATUS_SUCCESS -> {
                iconView?.visibility = View.VISIBLE
                loadingView?.visibility = View.GONE
                v.alpha = 0.9f
            }
            BALL_STATUS_ERROR -> {
                iconView?.visibility = View.VISIBLE
                loadingView?.visibility = View.GONE
                v.alpha = 0.9f
            }
        }
    }

    private fun debugPrint(msg: String) {
        android.util.Log.d("BulterBall", msg)
    }

    companion object Status {
        const val BALL_STATUS_IDLE = 0
        const val BALL_STATUS_HOVERED = 1
        const val BALL_STATUS_LOADING = 2
        const val BALL_STATUS_SUCCESS = 3
        const val BALL_STATUS_ERROR = 4
    }
}
