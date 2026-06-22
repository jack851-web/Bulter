package com.bulter.bulter

import android.os.Handler
import android.os.Looper
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Activity ↔ Service 单向通信总线（Step 10）。
 *
 * **设计**：
 * - Kotlin `object` 单例 + 回调列表
 * - 主线程 Handler 保证回调在 UI 线程执行
 * - `CopyOnWriteArrayList` 防并发读写崩溃
 */
object AppEventBus {

    /** 服务请求 Activity 显示悬浮球。 */
    interface ShowFloatingBallListener {
        fun onShowFloatingBall()
    }

    /** Activity 通知服务停止。 */
    interface StopFloatingBallListener {
        fun onStopFloatingBall()
    }

    private val showListeners = CopyOnWriteArrayList<ShowFloatingBallListener>()
    private val stopListeners = CopyOnWriteArrayList<StopFloatingBallListener>()

    private val mainHandler = Handler(Looper.getMainLooper())

    @JvmStatic
    fun registerShowFloatingBall(l: ShowFloatingBallListener) {
        showListeners.add(l)
    }

    @JvmStatic
    fun unregisterShowFloatingBall(l: ShowFloatingBallListener) {
        showListeners.remove(l)
    }

    @JvmStatic
    fun registerStopFloatingBall(l: StopFloatingBallListener) {
        stopListeners.add(l)
    }

    @JvmStatic
    fun unregisterStopFloatingBall(l: StopFloatingBallListener) {
        stopListeners.remove(l)
    }

    /** 前台服务请求 Activity 显示悬浮球（在主线程执行）。 */
    @JvmStatic
    fun requestShowFloatingBall() {
        mainHandler.post {
            for (l in showListeners) l.onShowFloatingBall()
        }
    }

    /** Activity 通知服务停止（在主线程执行）。 */
    @JvmStatic
    fun requestStopFloatingBall() {
        mainHandler.post {
            for (l in stopListeners) l.onStopFloatingBall()
        }
    }
}
