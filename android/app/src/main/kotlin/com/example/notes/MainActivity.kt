package com.example.notes

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "safeshake/sms"
    private val TILE_CHANNEL = "safeshake/tile"
    private var tileChannel: MethodChannel? = null
    private var pendingEmergencyTrigger = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkEmergencyIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkEmergencyIntent(intent)
    }

    private fun checkEmergencyIntent(intent: Intent?) {
        if (intent?.action == "ACTION_TRIGGER_EMERGENCY" || intent?.getBooleanExtra("trigger_emergency", false) == true) {
            intent.removeExtra("trigger_emergency")
            intent.action = null
            if (tileChannel != null) {
                tileChannel?.invokeMethod("triggerFromTile", null)
            } else {
                pendingEmergencyTrigger = true
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Existing Native SMS Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendDirectSms") {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")
                if (phone != null && message != null) {
                    val sent = sendDirectSms(phone, message)
                    result.success(sent)
                } else {
                    result.error("INVALID_ARGS", "Missing phone or message", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Quick Settings Tile Channel
        tileChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TILE_CHANNEL)
        tileChannel?.setMethodCallHandler { call, result ->
            if (call.method == "checkPendingTrigger") {
                val shouldTrigger = pendingEmergencyTrigger
                pendingEmergencyTrigger = false
                result.success(shouldTrigger)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sendDirectSms(phone: String, message: String): Boolean {
        return try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                applicationContext.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, null, null)
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}