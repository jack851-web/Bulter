package com.bulter.bulter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * MainActivity（Step 10）—— Flutter 宿主。
 *
 * **职责**：
 * 1. 启动 Flutter engine（系统默认）
 * 2. attach [BulterPlatformPlugin] —— 浮窗 + 截图 + Dart 通信
 * 3. 注册 [AppEventBus] 回调 —— 响应前台服务"显示悬浮球"请求
 *
 * **不**直接持有浮窗 view / service 引用——通过 [BulterPlatformPlugin] 协调。
 */
class MainActivity : FlutterActivity() {

    private var platformPlugin: BulterPlatformPlugin? = null

    private val showListener = object : AppEventBus.ShowFloatingBallListener {
        override fun onShowFloatingBall() {
            platformPlugin?.showFloatingBallFromService()
        }
    }

    private val stopListener = object : AppEventBus.StopFloatingBallListener {
        override fun onStopFloatingBall() {
            platformPlugin?.stopFloatingBallFromService()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册 Bulter 平台插件（Step 10）
        val plugin = BulterPlatformPlugin(this)
        platformPlugin = plugin
        plugin.onAttachedToEngine(flutterEngine)
        // 注册 AppEventBus 回调
        AppEventBus.registerShowFloatingBall(showListener)
        AppEventBus.registerStopFloatingBall(stopListener)
    }

    override fun onDestroy() {
        AppEventBus.unregisterShowFloatingBall(showListener)
        AppEventBus.unregisterStopFloatingBall(stopListener)
        platformPlugin?.onDetachedFromEngine()
        platformPlugin?.hideFloatingBall()
        platformPlugin = null
        super.onDestroy()
    }
}
