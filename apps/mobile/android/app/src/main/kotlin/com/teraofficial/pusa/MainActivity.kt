package com.teraofficial.pusa

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.Locale
import java.util.regex.Pattern

private const val PUSA_CHANNEL = "pusa/mobile_money"
private const val PREFS = "pusa_money_detection"
private const val EVENTS_KEY = "events"
private const val NOTIFICATION_CHANNEL = "pusa_money_activity"
private const val SMS_PERMISSION_REQUEST = 7402

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PUSA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasNotificationAccess" -> result.success(isNotificationAccessEnabled())
                    "openNotificationAccess" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(true)
                    }
                    "hasSmsPermission" -> result.success(hasSmsPermission())
                    "requestSmsPermission" -> {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
                            SMS_PERMISSION_REQUEST
                        )
                        result.success(true)
                    }
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7403)
                        }
                        result.success(true)
                    }
                    "setPreferences" -> {
                        val values = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                        prefs.putBoolean("enabled", values["enabled"] as? Boolean ?: false)
                        prefs.putBoolean("mtn", values["mtn"] as? Boolean ?: true)
                        prefs.putBoolean("orange", values["orange"] as? Boolean ?: true)
                        prefs.putBoolean("sms", values["sms"] as? Boolean ?: false)
                        prefs.apply()
                        result.success(true)
                    }
                    "getPreferences" -> {
                        val p = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                        result.success(mapOf(
                            "enabled" to p.getBoolean("enabled", false),
                            "mtn" to p.getBoolean("mtn", true),
                            "orange" to p.getBoolean("orange", true),
                            "sms" to p.getBoolean("sms", false)
                        ))
                    }
                    "readSmsHistory" -> {
                        if (!hasSmsPermission()) {
                            result.error("sms_permission", "SMS access has not been granted.", null)
                        } else {
                            readSmsHistory()
                            result.success(loadEvents())
                        }
                    }
                    "getEvents" -> result.success(loadEvents())
                    "markReviewed" -> {
                        val eventId = call.argument<String>("eventId")
                        if (eventId != null) updateEventReviewed(eventId)
                        result.success(true)
                    }
                    "clearReviewed" -> {
                        clearReviewedEvents()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isNotificationAccessEnabled(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return enabled.split(":").any { it.equals(componentName.flattenToString(), true) }
    }

    private fun hasSmsPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED &&
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED

    private fun readSmsHistory() {
        if (!getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("sms", false)) return
        val uri = Uri.parse("content://sms")
        val cursor: Cursor? = contentResolver.query(uri, arrayOf("_id", "address", "body", "date", "type"), null, null, "date DESC")
        cursor?.use {
            var read = 0
            while (it.moveToNext() && read < 250) {
                read++
                val address = it.getString(1) ?: ""
                val body = it.getString(2) ?: ""
                val date = it.getLong(3)
                val type = it.getInt(4)
                val provider = MobileMoneyParser.provider(address + " " + body) ?: continue
                val direction = if (type == Telephony.TextBasedSmsColumns.MESSAGE_TYPE_INBOX) "incoming"
                    else if (type == Telephony.TextBasedSmsColumns.MESSAGE_TYPE_SENT) "outgoing" else continue
                MobileMoneyParser.parse(provider, direction, body, "sms", address, date)?.let { event ->
                    saveEvent(event, notify = false)
                }
            }
        }
    }

    private fun loadEvents(): List<Map<String, Any?>> {
        val json = getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(EVENTS_KEY, "[]") ?: "[]"
        val array = JSONArray(json)
        return (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            item.toMap()
        }
    }

    private fun updateEventReviewed(id: String) {
        val array = JSONArray(getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(EVENTS_KEY, "[]"))
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            if (item.optString("id") == id) item.put("reviewed", true)
        }
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(EVENTS_KEY, array.toString()).apply()
        cancelReminder(this, id)
    }

    private fun clearReviewedEvents() {
        val old = JSONArray(getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(EVENTS_KEY, "[]"))
        val next = JSONArray()
        for (i in 0 until old.length()) {
            val item = old.optJSONObject(i) ?: continue
            if (!item.optBoolean("reviewed")) next.put(item)
        }
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(EVENTS_KEY, next.toString()).apply()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(NOTIFICATION_CHANNEL, "Money activity and saving reminders", NotificationManager.IMPORTANCE_DEFAULT)
            channel.description = "Private on-device transaction detection and allocation reminders."
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}

class PusaMobileMoneyListener : android.service.notification.NotificationListenerService() {
    override fun onNotificationPosted(sbn: android.service.notification.StatusBarNotification) {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false)) return
        val provider = MobileMoneyParser.provider(sbn.packageName + " " + sbn.notification.extras.getCharSequence(Notification.EXTRA_TITLE).orEmpty()) ?: return
        if (provider == "MTN" && !prefs.getBoolean("mtn", true)) return
        if (provider == "Orange" && !prefs.getBoolean("orange", true)) return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val joined = (title + " " + text).trim()
        MobileMoneyParser.parse(provider, "unknown", joined, "notification", sbn.packageName, sbn.postTime)?.let {
            saveEvent(it, notify = true)
        }
    }
}

class PusaIncomingSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false) || !prefs.getBoolean("sms", false)) return
        val incomingIntent = intent ?: return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(incomingIntent) ?: return
        for (message in messages) {
            val address = message.originatingAddress.orEmpty()
            val body = message.messageBody.orEmpty()
            val provider = MobileMoneyParser.provider(address + " " + body) ?: continue
            if (provider == "MTN" && !prefs.getBoolean("mtn", true)) continue
            if (provider == "Orange" && !prefs.getBoolean("orange", true)) continue
            MobileMoneyParser.parse(provider, "incoming", body, "sms", address, message.timestampMillis)?.let { saveEvent(it, notify = true) }
        }
    }
}

class PusaMoneyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val provider = intent?.getStringExtra("provider") ?: "Mobile Money"
        val amount = intent?.getLongExtra("amount", 0L) ?: 0L
        val eventId = intent?.getStringExtra("eventId") ?: return
        val stored = JSONArray(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(EVENTS_KEY, "[]"))
        for (i in 0 until stored.length()) {
            val event = stored.optJSONObject(i) ?: continue
            if (event.optString("id") == eventId && event.optBoolean("reviewed")) return
        }
        showPusaNotification(context, "A saving reminder", "You received " + amount + " XAF earlier. Would you like to review your allocation plan?")
    }
}

private fun saveEvent(event: JSONObject, notify: Boolean) {
    val context = PusaApplicationContext.current ?: return
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    val old = JSONArray(prefs.getString(EVENTS_KEY, "[]"))
    val id = event.optString("id")
    for (i in 0 until old.length()) {
        if (old.optJSONObject(i)?.optString("id") == id) return
    }
    val next = JSONArray()
    next.put(event)
    for (i in 0 until old.length() && i < 99; i++) next.put(old.getJSONObject(i))
    prefs.edit().putString(EVENTS_KEY, next.toString()).apply()
    if (notify) {
        val provider = event.optString("provider")
        val amount = event.optLong("amountXaf")
        if (event.optString("direction") == "incoming") {
            showPusaNotification(context, "Money received detected", "You may have received ${amount} XAF via $provider. Want to split it in Pusa?")
            scheduleReminder(context, event)
        } else if (event.optString("direction") == "outgoing") {
            val prior = JSONArray(prefs.getString(EVENTS_KEY, "[]"))
            val now = System.currentTimeMillis()
            var matchedIndex = -1
            for (index in 0 until prior.length()) {
                val candidate = prior.optJSONObject(index) ?: continue
                val age = now - candidate.optLong("timestamp")
                if (candidate.optString("direction") == "incoming" &&
                    !candidate.optBoolean("reviewed") &&
                    !candidate.optBoolean("spendNudgeSent") &&
                    age in 0..(24 * 60 * 60 * 1000L)) {
                    candidate.put("spendNudgeSent", true)
                    matchedIndex = index
                    break
                }
            }
            if (matchedIndex >= 0) {
                prefs.edit().putString(EVENTS_KEY, prior.toString()).apply()
                showPusaNotification(context, "Saving reminder", "You may be using money received earlier. Want to review your allocation plan?")
            }
        }
    }
}

private fun scheduleReminder(context: Context, event: JSONObject) {
    val intent = Intent(context, PusaMoneyReminderReceiver::class.java).apply {
        putExtra("provider", event.optString("provider"))
        putExtra("amount", event.optLong("amountXaf"))
        putExtra("eventId", event.optString("id"))
    }
    val id = event.optString("id").hashCode()
    val pending = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + 60 * 60 * 1000L, pending)
}

private fun cancelReminder(context: Context, eventId: String) {
    val intent = Intent(context, PusaMoneyReminderReceiver::class.java).putExtra("eventId", eventId)
    val pending = PendingIntent.getBroadcast(context, eventId.hashCode(), intent, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
    if (pending != null) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending)
        pending.cancel()
    }
}

private fun showPusaNotification(context: Context, title: String, body: String) {
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= 33 &&
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
    ) return
    val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
    val pending = launch?.let {
        PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    val notification = if (Build.VERSION.SDK_INT >= 26) {
        Notification.Builder(context, NOTIFICATION_CHANNEL)
    } else {
        @Suppress("DEPRECATION")
        Notification.Builder(context)
    }.setSmallIcon(android.R.drawable.ic_dialog_info)
        .setContentTitle(title).setContentText(body).setAutoCancel(true)
        .apply { if (pending != null) setContentIntent(pending) }
        .build()
    manager.notify((title + body).hashCode(), notification)
}

private object MobileMoneyParser {
    fun provider(text: String): String? {
        val value = text.lowercase(Locale.ROOT)
        return when {
            value.contains("mtn") || value.contains("momo") || value.contains("mobilemoney.mtn") -> "MTN"
            value.contains("orange") -> "Orange"
            else -> null
        }
    }

    fun parse(provider: String, requestedDirection: String, body: String, source: String, sender: String, timestamp: Long): JSONObject? {
        val direction = when {
            Regex("(?i)\\b(received|reçu|recu|credit|credited|deposit|depot|dépôt|incoming)\\b").containsMatchIn(body) -> "incoming"
            Regex("(?i)\\b(sent|paid|payment|payé|paye|debit|debited|withdraw|retrait|purchase|achat|outgoing)\\b").containsMatchIn(body) -> "outgoing"
            requestedDirection != "unknown" -> requestedDirection
            else -> return null
        }
        val amountMatch = Regex("(?i)(?:amount|montant|received|reçu|recu|paid|payé|paye|debit|withdrawn|retrait|transfer|transfert)[^0-9]{0,30}([0-9][0-9 .,’',]{1,})|([0-9][0-9 .,’',]{1,})\\s*(?:XAF|FCFA|CFA)").find(body)
        val rawAmount = amountMatch?.groups?.get(1)?.value ?: amountMatch?.groups?.get(2)?.value ?: return null
        val amount = rawAmount.replace(Regex("[^0-9]"), "").toLongOrNull() ?: return null
        if (amount <= 0 || amount > 100_000_000) return null
        val ref = Regex("(?i)(?:ref(?:erence)?|transaction(?:\\s*(?:id|ref))?|id)\\s*[:#-]?\\s*([A-Z0-9-]{5,})").find(body)?.groupValues?.get(1)
        val stable = ref?.let { "$provider:$it" } ?: "$provider:$direction:$amount:${body.lowercase(Locale.ROOT).replace(Regex("\\s+"), " ").trim()}"
        val digest = MessageDigest.getInstance("SHA-256").digest(stable.toByteArray()).take(12).joinToString("") { "%02x".format(it) }
        val displayParty = sender.take(3).let { if (it.length > 0) "$it•••" else "" }
        return JSONObject().apply {
            put("id", digest)
            put("provider", provider)
            put("direction", direction)
            put("amountXaf", amount)
            put("reference", ref ?: JSONObject.NULL)
            put("counterpartyHint", displayParty)
            put("timestamp", timestamp)
            put("source", source)
            put("reviewed", false)
        }
    }
}

private fun JSONObject.toMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    val keys = keys()
    while (keys.hasNext()) {
        val key = keys.next()
        val value = opt(key)
        map[key] = if (value == JSONObject.NULL) null else value
    }
    return map
}

/** Keeps a process context reference for the listener's helper functions. */
class PusaApplicationContext : android.app.Application() {
    override fun onCreate() {
        super.onCreate()
        current = this
    }
    companion object { var current: Context? = null }
}
