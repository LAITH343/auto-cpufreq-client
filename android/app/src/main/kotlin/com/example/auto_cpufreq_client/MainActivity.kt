package com.example.auto_cpufreq_client

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "auto_cpufreq/mdns"
    private var lock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> { acquire(); result.success(null) }
                    "release" -> { release(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    // mDNS reception on Android needs a held multicast lock; without it the
    // socket never sees the group traffic and discovery silently returns empty.
    private fun acquire() {
        if (lock == null) {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            lock = wifi.createMulticastLock("auto_cpufreq_mdns").apply {
                setReferenceCounted(true)
            }
        }
        lock?.acquire()
    }

    private fun release() {
        lock?.let { if (it.isHeld) it.release() }
    }

    override fun onDestroy() {
        while (lock?.isHeld == true) lock?.release()
        super.onDestroy()
    }
}
