package com.example.amenpay_cashir_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.util.Base64
import android.util.Log
import com.leshun.support.baseline.BaseLine
import com.leshun.support.shunpalm.ShunPalm
import com.leshun.support.shunpalm.ls2.ShunPalmWorker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.nio.charset.Charset
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

class MainActivity : FlutterActivity() {
    private val palmInitLock = Any()
    private var palmInitialized = false
    private val noopCallback =
            object : BaseLine.Callback {
                override fun onResult(res: BaseLine.Result) {}
            }

    private val qrLock = Any()
    private var qrDevicePath = "/dev/ttyHSL3"
    private val qrReaderRunning = AtomicBoolean(false)
    private var qrEventSink: EventChannel.EventSink? = null
    private var qrReaderThread: Thread? = null
    private var qrInputStream: FileInputStream? = null
    private var lastQrPayload: String? = null
    private var lastQrAtMs: Long = 0L
    private val qrBroadcastRegistered = AtomicBoolean(false)
    private var qrBroadcastReceiver: BroadcastReceiver? = null
    private var lastBroadcastPayload: String? = null
    private var lastBroadcastAction: String? = null
    private val lastBroadcastAtMs = AtomicLong(0L)
    private val qrBroadcastFramesTotal = AtomicLong(0L)
    private var scanOnceLatch: CountDownLatch? = null
    private var scanOnceValue: AtomicReference<String?>? = null
    private val qrTerminators = setOf('\n', '\r', '\u0003', '\u0004')
    private val qrReaderStartElapsedMs = AtomicLong(0L)
    private val qrReaderBytesTotal = AtomicLong(0L)
    private val qrReaderFramesTotal = AtomicLong(0L)
    private val qrReaderLastByteElapsedMs = AtomicLong(0L)
    private val qrReaderLastLogElapsedMs = AtomicLong(0L)
    private val qrReaderLastTerminatorElapsedMs = AtomicLong(0L)

    private fun redactForLog(value: String?, head: Int = 6, tail: Int = 4): String {
        val trimmed = value?.trim().orEmpty()
        if (trimmed.isEmpty()) return ""
        if (trimmed.length <= head + tail) return "*".repeat(trimmed.length)
        return trimmed.substring(0, head) + "..." + trimmed.substring(trimmed.length - tail)
    }

    private fun logD(message: String) {
        Log.d("PalmEnroll", message)
    }

    private fun logE(message: String, t: Throwable? = null) {
        Log.e("PalmEnroll", message, t)
    }

    private fun qrDeviceSnapshot(): String {
        val path = synchronized(qrLock) { qrDevicePath }
        val f = File(path)
        return "path=$path exists=${f.exists()} canRead=${f.canRead()} canWrite=${f.canWrite()}"
    }

    private fun listQrDeviceCandidates(): List<Map<String, Any>> {
        val devDir = File("/dev")
        val files =
                try {
                    devDir.listFiles()?.toList().orEmpty()
                } catch (_: Exception) {
                    emptyList()
                }

        val candidates =
                files
                        .map { it.name }
                        .filter {
                            it.startsWith("ttyHSL") ||
                                    it.startsWith("ttyHS") ||
                                    it.startsWith("ttyS") ||
                                    it.startsWith("ttyUSB") ||
                                    it.startsWith("ttyACM")
                        }
                        .sorted()
                        .map { name ->
                            val path = "/dev/$name"
                            val f = File(path)
                            mapOf(
                                    "path" to path,
                                    "exists" to f.exists(),
                                    "can_read" to f.canRead(),
                                    "can_write" to f.canWrite(),
                            )
                        }

        val current =
                mapOf(
                        "path" to (synchronized(qrLock) { qrDevicePath }),
                        "exists" to File(synchronized(qrLock) { qrDevicePath }).exists(),
                        "can_read" to File(synchronized(qrLock) { qrDevicePath }).canRead(),
                        "can_write" to File(synchronized(qrLock) { qrDevicePath }).canWrite(),
                )

        return listOf(current) + candidates.filterNot { it["path"] == current["path"] }
    }

    private fun setQrDevicePath(next: String) {
        val trimmed = next.trim()
        if (trimmed.isEmpty()) throw IllegalArgumentException("qr_device_path is required")
        synchronized(qrLock) { qrDevicePath = trimmed }
        val prefs = getSharedPreferences("amenpay_pos_device", Context.MODE_PRIVATE)
        prefs.edit().putString("qr_device_path", trimmed).apply()
        stopQrReader()
        if (qrEventSink != null) startQrReaderIfNeeded()
    }

    private fun maybeLogQrBytes(readBytes: Int, buffer: ByteArray, offset: Int) {
        val now = SystemClock.elapsedRealtime()
        qrReaderLastByteElapsedMs.set(now)
        val lastLog = qrReaderLastLogElapsedMs.get()
        if (now - lastLog < 2000L) return
        if (!qrReaderLastLogElapsedMs.compareAndSet(lastLog, now)) return

        val bytesTotal = qrReaderBytesTotal.get()
        val framesTotal = qrReaderFramesTotal.get()
        val start = qrReaderStartElapsedMs.get()
        val uptimeMs = if (start > 0L) now - start else -1L

        var terminatorSeen = false
        val end = (offset + readBytes).coerceAtMost(buffer.size)
        var i = offset
        while (i < end) {
            val b = buffer[i].toInt() and 0xFF
            if (b == 0x0A || b == 0x0D || b == 0x03 || b == 0x04) {
                terminatorSeen = true
                break
            }
            i++
        }

        logD(
                "qrScanner/reader bytes read=$readBytes total=$bytesTotal frames=$framesTotal uptime_ms=$uptimeMs terminator_in_chunk=$terminatorSeen"
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val prefs = getSharedPreferences("amenpay_pos_device", Context.MODE_PRIVATE)
        val savedQrPath = prefs.getString("qr_device_path", null)
        if (!savedQrPath.isNullOrBlank()) {
            synchronized(qrLock) { qrDevicePath = savedQrPath.trim() }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "posDevice/methods")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getDeviceId" -> {
                            val androidId =
                                    Settings.Secure.getString(
                                            contentResolver,
                                            Settings.Secure.ANDROID_ID
                                    )
                            result.success(androidId)
                        }
                        "getDeviceApiKey" -> {
                            val prefs =
                                    getSharedPreferences("amenpay_pos_device", Context.MODE_PRIVATE)
                            result.success(prefs.getString("device_api_key", null))
                        }
                        "setDeviceApiKey" -> {
                            val args = call.arguments
                            val apiKey =
                                    when (args) {
                                        is String -> args
                                        is Map<*, *> -> args["api_key"]?.toString()
                                        else -> null
                                    }
                            if (apiKey.isNullOrBlank()) {
                                result.error("INVALID_ARGUMENT", "api_key is required", null)
                                return@setMethodCallHandler
                            }
                            val prefs =
                                    getSharedPreferences("amenpay_pos_device", Context.MODE_PRIVATE)
                            prefs.edit().putString("device_api_key", apiKey).apply()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "qrScanner/events")
                .setStreamHandler(
                        object : EventChannel.StreamHandler {
                            override fun onListen(
                                    arguments: Any?,
                                    events: EventChannel.EventSink?
                            ) {
                                qrEventSink = events
                                logD(
                                        "qrScanner/events listen, starting reader (${qrDeviceSnapshot()})"
                                )
                                startQrReaderIfNeeded()
                                startQrBroadcastIfNeeded()
                            }

                            override fun onCancel(arguments: Any?) {
                                qrEventSink = null
                                logD("qrScanner/events cancel, stopping reader")
                                stopQrReader()
                                stopQrBroadcast()
                            }
                        }
                )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qrScanner/methods")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getQrDevicePath" -> {
                            result.success(synchronized(qrLock) { qrDevicePath })
                        }
                        "setQrDevicePath" -> {
                            val args = call.arguments
                            val nextPath =
                                    when (args) {
                                        is String -> args
                                        is Map<*, *> -> args["qr_device_path"]?.toString()
                                        else -> null
                                    }
                            if (nextPath.isNullOrBlank()) {
                                result.error("INVALID_ARGUMENT", "qr_device_path is required", null)
                                return@setMethodCallHandler
                            }
                            try {
                                setQrDevicePath(nextPath)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("QR_DEVICE_PATH_FAILED", e.message, null)
                            }
                        }
                        "listQrDeviceCandidates" -> {
                            result.success(listQrDeviceCandidates())
                        }
                        "getQrNativeDiagnostics" -> {
                            result.success(qrNativeDiagnostics())
                        }
                        "scanQrOnce" -> {
                            val timeoutMs =
                                    (call.arguments as? Map<*, *>)
                                            ?.get("timeout_ms")
                                            ?.toString()
                                            ?.toLongOrNull()
                                            ?: 15000L

                            Thread {
                                        try {
                                            logD(
                                                    "scanQrOnce start timeoutMs=$timeoutMs reader_running=${qrReaderRunning.get()} (${qrDeviceSnapshot()})"
                                            )
                                            val payload =
                                                    try {
                                                        scanQrOnceBlocking(timeoutMs)
                                                    } catch (e: Exception) {
                                                        scanQrOnceWithProbeOnTimeout(timeoutMs, e)
                                                    }
                                            logD(
                                                    "scanQrOnce success qr_data=" +
                                                            redactForLog(payload)
                                            )
                                            runOnUiThread { result.success(payload) }
                                        } catch (e: Exception) {
                                            logE("scanQrOnce failed: ${e.message}", e)
                                            runOnUiThread {
                                                result.error("QR_SCAN_FAILED", e.message, null)
                                            }
                                        }
                                    }
                                    .start()
                        }
                        else -> result.notImplemented()
                    }
                }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "palmEnrollment/methods")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "startEnrollment" -> {
                            Thread {
                                        try {
                                            logD("palmEnrollment start")
                                            val payload = startPalmEnrollmentBlocking()
                                            val tpl = payload["template_id"]?.toString()
                                            val err = payload["error_code"]?.toString()
                                            logD(
                                                    "palmEnrollment done template_id=" +
                                                            redactForLog(tpl) +
                                                            " error_code=" +
                                                            err.orEmpty()
                                            )
                                            runOnUiThread { result.success(payload) }
                                        } catch (e: Exception) {
                                            logE("palmEnrollment failed: ${e.message}", e)
                                            runOnUiThread {
                                                result.error(
                                                        "PALM_ENROLLMENT_FAILED",
                                                        e.message,
                                                        null
                                                )
                                            }
                                        }
                                    }
                                    .start()
                        }
                        else -> result.notImplemented()
                    }
                }
    }

    private fun startQrReaderIfNeeded() {
        synchronized(qrLock) {
            if (qrReaderRunning.get()) return
            qrReaderRunning.set(true)

            qrReaderThread =
                    Thread {
                        qrReaderStartElapsedMs.set(SystemClock.elapsedRealtime())
                        qrReaderBytesTotal.set(0L)
                        qrReaderFramesTotal.set(0L)
                        qrReaderLastByteElapsedMs.set(0L)
                        qrReaderLastTerminatorElapsedMs.set(0L)
                        qrReaderLastLogElapsedMs.set(0L)

                        logD("qrScanner/reader start (${qrDeviceSnapshot()})")
                        val devicePath = synchronized(qrLock) { qrDevicePath }
                        val input =
                                try {
                                    FileInputStream(devicePath)
                                } catch (e: Exception) {
                                    emitQrError("QR_OPEN_FAILED", e.message)
                                    qrReaderRunning.set(false)
                                    return@Thread
                                }

                        qrInputStream = input
                        logD("qrScanner/reader opened ok (${qrDeviceSnapshot()})")

                        val buffer = ByteArray(256)
                        val sb = StringBuilder()
                        val charset = Charset.forName("UTF-8")

                        try {
                            while (qrReaderRunning.get()) {
                                val read =
                                        try {
                                            input.read(buffer)
                                        } catch (e: Exception) {
                                            emitQrError("QR_READ_FAILED", e.message)
                                            break
                                        }

                                if (read <= 0) continue
                                qrReaderBytesTotal.addAndGet(read.toLong())
                                maybeLogQrBytes(read, buffer, 0)

                                val chunk = String(buffer, 0, read, charset)
                                for (ch in chunk) {
                                    if (qrTerminators.contains(ch)) {
                                        qrReaderLastTerminatorElapsedMs.set(
                                                SystemClock.elapsedRealtime()
                                        )
                                        val payload = sb.toString().trim()
                                        sb.setLength(0)
                                        emitQrPayloadIfNew(payload)
                                    } else {
                                        sb.append(ch)
                                    }
                                }
                            }
                        } finally {
                            try {
                                input.close()
                            } catch (_: Exception) {}
                            qrInputStream = null
                            qrReaderRunning.set(false)
                            logD(
                                    "qrScanner/reader stopped bytes_total=${qrReaderBytesTotal.get()} frames_total=${qrReaderFramesTotal.get()}"
                            )
                        }
                    }
                            .apply { name = "qr-scanner-reader" }

            qrReaderThread?.start()
        }
    }

    private fun stopQrReader() {
        synchronized(qrLock) {
            qrReaderRunning.set(false)
            try {
                qrInputStream?.close()
            } catch (_: Exception) {}
            qrInputStream = null
            qrReaderThread = null
        }
    }

    private fun startQrBroadcastIfNeeded() {
        if (qrBroadcastRegistered.get()) return
        qrBroadcastRegistered.set(true)

        val filter = IntentFilter()
        val actions =
                listOf(
                        "com.symbol.datawedge.datawedge_scanner_input",
                        "com.symbol.datawedge.api.RESULT_ACTION",
                        "com.honeywell.aidc.action.BARCODE_DATA",
                        "com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED",
                        "nlscan.action.SCANNER_RESULT",
                        "com.datalogic.decodewedge.decode_action",
                        "scan.rcv.message",
                        "android.intent.ACTION_DECODE_DATA",
                )
        for (action in actions) {
            filter.addAction(action)
        }

        val receiver =
                object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        if (intent == null) return
                        val extracted = extractQrPayloadFromIntent(intent)
                        val action = intent.action.orEmpty()
                        if (extracted == null) {
                            val keys =
                                    try {
                                        intent.extras?.keySet()?.joinToString(",").orEmpty()
                                    } catch (_: Exception) {
                                        ""
                                    }
                            logD("qrScanner/broadcast action=$action no_payload extras=[$keys]")
                            return
                        }
                        val payload = extracted.first
                        val meta = extracted.second
                        lastBroadcastPayload = payload
                        lastBroadcastAction = action
                        lastBroadcastAtMs.set(System.currentTimeMillis())
                        logD("qrScanner/broadcast action=$action payload=" + redactForLog(payload))
                        emitQrPayloadFromSource(
                                payload = payload,
                                source = "broadcast",
                                meta =
                                        HashMap<String, Any?>().apply {
                                            put("action", action)
                                            putAll(meta)
                                        },
                        )
                    }
                }

        qrBroadcastReceiver = receiver
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("DEPRECATION") registerReceiver(receiver, filter)
            }
            logD("qrScanner/broadcast registered actions=${actions.size}")
        } catch (e: Exception) {
            qrBroadcastReceiver = null
            qrBroadcastRegistered.set(false)
            logE("qrScanner/broadcast register failed: ${e.message}", e)
        }
    }

    private fun stopQrBroadcast() {
        if (!qrBroadcastRegistered.get()) return
        qrBroadcastRegistered.set(false)
        val receiver = qrBroadcastReceiver
        qrBroadcastReceiver = null
        if (receiver != null) {
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {}
        }
        logD("qrScanner/broadcast unregistered")
    }

    private fun extractQrPayloadFromIntent(intent: Intent): Pair<String, Map<String, Any?>>? {
        val extras =
                try {
                    intent.extras
                } catch (_: Exception) {
                    null
                } ?: return null

        val preferredKeys =
                listOf(
                        "com.symbol.datawedge.data_string",
                        "com.symbol.datawedge.data_string_utf8",
                        "data",
                        "barcode",
                        "barcode_data",
                        "scan_result",
                        "SCAN_RESULT",
                        "decode_data",
                        "result",
                        "payload",
                        Intent.EXTRA_TEXT,
                )

        for (key in preferredKeys) {
            val value = extras.get(key)
            if (value is String) {
                val trimmed = value.trim()
                if (trimmed.isNotEmpty()) {
                    return trimmed to mapOf("extra_key" to key)
                }
            }
            if (value is ByteArray) {
                val decoded =
                        try {
                            String(value, Charset.forName("UTF-8")).trim()
                        } catch (_: Exception) {
                            ""
                        }
                if (decoded.isNotEmpty()) {
                    return decoded to mapOf("extra_key" to key, "extra_type" to "byte_array")
                }
            }
        }

        var bestKey: String? = null
        var bestValue = ""
        for (key in extras.keySet()) {
            val v = extras.get(key)
            if (v is String) {
                val trimmed = v.trim()
                if (trimmed.isNotEmpty() && trimmed.length > bestValue.length) {
                    bestKey = key
                    bestValue = trimmed
                }
            }
        }
        if (bestValue.isNotEmpty() && bestKey != null) {
            return bestValue to mapOf("extra_key" to bestKey, "extra_type" to "string_fallback")
        }
        return null
    }

    private fun qrNativeDiagnostics(): Map<String, Any?> {
        val path = synchronized(qrLock) { qrDevicePath }
        val file = File(path)
        val now = System.currentTimeMillis()
        val lastAt = lastQrAtMs
        val ageMs = if (lastAt <= 0L) -1L else (now - lastAt)
        val lastBroadcastAt = lastBroadcastAtMs.get()
        val broadcastAgeMs = if (lastBroadcastAt <= 0L) -1L else (now - lastBroadcastAt)

        return mapOf(
                "uptime_ms" to SystemClock.elapsedRealtime(),
                "qr_device_path" to path,
                "qr_device_exists" to file.exists(),
                "qr_device_can_read" to file.canRead(),
                "qr_device_can_write" to file.canWrite(),
                "qr_reader_running" to qrReaderRunning.get(),
                "qr_reader_bytes_total" to qrReaderBytesTotal.get(),
                "qr_serial_frames_total" to qrReaderFramesTotal.get(),
                "qr_broadcast_frames_total" to qrBroadcastFramesTotal.get(),
                "qr_last_payload_redacted" to redactForLog(lastQrPayload),
                "qr_last_scan_age_ms" to ageMs,
                "qr_last_byte_age_ms" to
                        if (qrReaderLastByteElapsedMs.get() <= 0L) -1L
                        else SystemClock.elapsedRealtime() - qrReaderLastByteElapsedMs.get(),
                "qr_last_terminator_age_ms" to
                        if (qrReaderLastTerminatorElapsedMs.get() <= 0L) -1L
                        else SystemClock.elapsedRealtime() - qrReaderLastTerminatorElapsedMs.get(),
                "broadcast_registered" to qrBroadcastRegistered.get(),
                "broadcast_last_action" to (lastBroadcastAction ?: ""),
                "broadcast_last_payload_redacted" to redactForLog(lastBroadcastPayload),
                "broadcast_last_age_ms" to broadcastAgeMs,
        )
    }

    private fun emitQrPayloadIfNew(payload: String) {
        emitQrPayloadFromSource(
                payload = payload,
                source = "serial",
                meta =
                        mapOf(
                                "device_path" to synchronized(qrLock) { qrDevicePath },
                        ),
        )
    }

    private fun emitQrPayloadFromSource(
            payload: String,
            source: String,
            meta: Map<String, Any?> = emptyMap(),
    ) {
        if (payload.isEmpty()) return

        val now = System.currentTimeMillis()
        val lastPayloadSnapshot = lastQrPayload
        val lastAtSnapshot = lastQrAtMs

        if (lastPayloadSnapshot == payload && now - lastAtSnapshot < 500L) return

        lastQrPayload = payload
        lastQrAtMs = now
        if (source == "serial") {
            qrReaderFramesTotal.incrementAndGet()
        } else if (source == "broadcast") {
            qrBroadcastFramesTotal.incrementAndGet()
        }

        val latch = scanOnceLatch
        val valueRef = scanOnceValue
        if (latch != null && valueRef != null && latch.count > 0) {
            valueRef.set(payload)
            latch.countDown()
        }

        emitQrSuccess(payload, source, meta)
    }

    private fun emitQrSuccess(payload: String, source: String, meta: Map<String, Any?>) {
        logD("qrScanner/events source=$source payload=" + redactForLog(payload))
        val out =
                HashMap<String, Any?>().apply {
                    put("payload", payload)
                    put("source", source)
                    putAll(meta)
                }
        runOnUiThread { qrEventSink?.success(out) }
    }

    private fun emitQrError(code: String, message: String?) {
        logE("qrScanner/events error code=$code message=${message.orEmpty()}")
        runOnUiThread { qrEventSink?.error(code, message, null) }
    }

    private fun scanOnceFromDevicePath(devicePath: String, timeoutMs: Long): String? {
        val latch = CountDownLatch(1)
        val ref = AtomicReference<String?>()
        val streamRef = AtomicReference<FileInputStream?>()
        val bytesRead = AtomicInteger(0)

        Thread {
                    val input =
                            try {
                                FileInputStream(devicePath)
                            } catch (_: Exception) {
                                latch.countDown()
                                return@Thread
                            }

                    streamRef.set(input)
                    val buffer = ByteArray(256)
                    val sb = StringBuilder()
                    val charset = Charset.forName("UTF-8")

                    try {
                        while (latch.count > 0) {
                            val read =
                                    try {
                                        input.read(buffer)
                                    } catch (_: Exception) {
                                        break
                                    }
                            if (read <= 0) continue
                            bytesRead.addAndGet(read)
                            val chunk = String(buffer, 0, read, charset)
                            for (ch in chunk) {
                                if (qrTerminators.contains(ch)) {
                                    val payload = sb.toString().trim()
                                    sb.setLength(0)
                                    if (payload.isNotEmpty()) {
                                        ref.set(payload)
                                        latch.countDown()
                                        return@Thread
                                    }
                                } else {
                                    sb.append(ch)
                                }
                            }
                        }
                    } finally {
                        try {
                            input.close()
                        } catch (_: Exception) {}
                        streamRef.set(null)
                    }
                }
                .apply { name = "qr-scan-once-$devicePath" }
                .start()

        val ok = latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        if (!ok) {
            try {
                streamRef.get()?.close()
            } catch (_: Exception) {}
        }

        val payload = ref.get()?.trim().orEmpty()
        logD(
                "qrScanner/probe path=$devicePath timeoutMs=$timeoutMs ok=$ok bytes_read=${bytesRead.get()} payload_len=${payload.length}"
        )
        return payload.ifEmpty { null }
    }

    private fun scanQrOnceWithProbeOnTimeout(timeoutMs: Long, error: Exception): String {
        val msg = error.message.orEmpty()
        val shouldProbe =
                msg.contains("Timed out waiting for QR payload") &&
                        msg.contains("bytes_total=0") &&
                        msg.contains("last_byte_age_ms=-1")
        if (!shouldProbe) throw error

        val candidates = listQrDeviceCandidates()
        val currentPath = synchronized(qrLock) { qrDevicePath }
        val readablePaths =
                candidates
                        .filter { it["can_read"] == true }
                        .mapNotNull { it["path"]?.toString()?.trim() }
                        .filter { it.isNotEmpty() }
                        .distinct()

        val fallbackPaths = readablePaths.filterNot { it == currentPath }
        if (fallbackPaths.isEmpty()) throw error

        val perPathMs = (timeoutMs / (fallbackPaths.size + 1)).coerceIn(3000L, 8000L)
        logD(
                "qrScanner/probe starting current=$currentPath perPathMs=$perPathMs candidates=${fallbackPaths.size}"
        )

        for (path in fallbackPaths) {
            val payload = scanOnceFromDevicePath(path, perPathMs)
            if (!payload.isNullOrBlank()) {
                logD("qrScanner/probe success path=$path qr_data=" + redactForLog(payload))
                try {
                    setQrDevicePath(path)
                } catch (_: Exception) {}
                return payload
            }
        }

        throw error
    }

    private fun scanQrOnceBlocking(timeoutMs: Long): String {
        val existingReaderRunning = qrReaderRunning.get()
        if (existingReaderRunning) {
            val latch = CountDownLatch(1)
            val ref = AtomicReference<String?>()
            synchronized(qrLock) {
                scanOnceLatch = latch
                scanOnceValue = ref
            }
            try {
                val ok = latch.await(timeoutMs, TimeUnit.MILLISECONDS)
                if (!ok) {
                    val ageMs =
                            if (lastQrAtMs > 0L) System.currentTimeMillis() - lastQrAtMs else -1L
                    val nowElapsed = SystemClock.elapsedRealtime()
                    val lastByteAgeMs =
                            qrReaderLastByteElapsedMs.get().let { t ->
                                if (t > 0L) nowElapsed - t else -1L
                            }
                    val lastTerminatorAgeMs =
                            qrReaderLastTerminatorElapsedMs.get().let { t ->
                                if (t > 0L) nowElapsed - t else -1L
                            }
                    val bytesTotal = qrReaderBytesTotal.get()
                    val framesTotal = qrReaderFramesTotal.get()
                    throw IllegalStateException(
                            "Timed out waiting for QR payload. Reader is running, but no new scan arrived within ${timeoutMs}ms (last_scan_age_ms=$ageMs, bytes_total=$bytesTotal, frames_total=$framesTotal, last_byte_age_ms=$lastByteAgeMs, last_terminator_age_ms=$lastTerminatorAgeMs, ${qrDeviceSnapshot()})."
                    )
                }
                val payload = ref.get()
                if (payload.isNullOrBlank()) throw IllegalStateException("No QR payload received.")
                return payload
            } finally {
                synchronized(qrLock) {
                    if (scanOnceLatch === latch) scanOnceLatch = null
                    if (scanOnceValue === ref) scanOnceValue = null
                }
            }
        }

        val latch = CountDownLatch(1)
        val ref = AtomicReference<String?>()
        val streamRef = AtomicReference<FileInputStream?>()
        val bytesRead = AtomicInteger(0)

        val t =
                Thread {
                    logD(
                            "qrScanner/scanOnce thread start timeoutMs=$timeoutMs (${qrDeviceSnapshot()})"
                    )
                    val devicePath = synchronized(qrLock) { qrDevicePath }
                    val input =
                            try {
                                FileInputStream(devicePath)
                            } catch (e: Exception) {
                                ref.set(null)
                                latch.countDown()
                                return@Thread
                            }

                    streamRef.set(input)
                    val buffer = ByteArray(256)
                    val sb = StringBuilder()
                    val charset = Charset.forName("UTF-8")

                    try {
                        while (latch.count > 0) {
                            val read =
                                    try {
                                        input.read(buffer)
                                    } catch (_: Exception) {
                                        break
                                    }
                            if (read <= 0) continue
                            bytesRead.addAndGet(read)
                            maybeLogQrBytes(read, buffer, 0)
                            val chunk = String(buffer, 0, read, charset)
                            for (ch in chunk) {
                                if (qrTerminators.contains(ch)) {
                                    val payload = sb.toString().trim()
                                    sb.setLength(0)
                                    if (payload.isNotEmpty()) {
                                        ref.set(payload)
                                        latch.countDown()
                                        return@Thread
                                    }
                                } else {
                                    sb.append(ch)
                                }
                            }
                        }
                    } finally {
                        try {
                            input.close()
                        } catch (_: Exception) {}
                        streamRef.set(null)
                    }
                }
                        .apply { name = "qr-scan-once" }

        t.start()

        val ok = latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        if (!ok) {
            try {
                streamRef.get()?.close()
            } catch (_: Exception) {}
            val hint =
                    if (bytesRead.get() == 0) {
                        "No bytes were read from ${synchronized(qrLock) { qrDevicePath }}."
                    } else {
                        "Read ${bytesRead.get()} bytes from ${synchronized(qrLock) { qrDevicePath }} but did not complete a payload (expected a terminator such as CR/LF)."
                    }
            throw IllegalStateException("Timed out waiting for QR payload. $hint")
        }

        val payload = ref.get()
        if (payload.isNullOrBlank()) {
            throw IllegalStateException("No QR payload received.")
        }

        return payload
    }

    private fun ensurePalmInitialized() {
        synchronized(palmInitLock) {
            if (palmInitialized) return

            val helper =
                    object : BaseLine.Helper {
                        override fun context() = applicationContext
                    }

            ShunPalm.init(ShunPalmWorker(helper))
            palmInitialized = true
        }
    }

    private fun awaitFinalResult(
            timeoutMs: Long,
            start: (callback: BaseLine.Callback) -> Unit,
    ): BaseLine.Result {
        val latch = CountDownLatch(1)
        val ref = AtomicReference<BaseLine.Result?>()

        val callback =
                object : BaseLine.Callback {
                    override fun onResult(res: BaseLine.Result) {
                        if (res.code() == BaseLine.Code.WAITING) return
                        ref.set(res)
                        latch.countDown()
                    }
                }

        start(callback)

        val ok = latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        if (!ok) throw IllegalStateException("Timed out waiting for palm SDK result.")
        return ref.get() ?: throw IllegalStateException("Palm SDK returned empty result.")
    }

    private fun startPalmEnrollmentBlocking(): Map<String, Any?> {
        ensurePalmInitialized()
        logD("palmEnrollment engineBuild start")

        val engineRes =
                awaitFinalResult(
                        timeoutMs = 60000,
                ) { cb -> ShunPalm.engineBuild(BaseLine.Params(), cb) }
        logD("palmEnrollment engineBuild res code=${engineRes.code()} hint=${engineRes.hint()}")
        if (engineRes.code() != BaseLine.Code.SUCCEED) {
            return mapOf(
                    "error_code" to "ENGINE_BUILD_FAILED",
                    "error_message" to engineRes.hint(),
            )
        }

        logD("palmEnrollment previewStart start")
        val previewRes =
                awaitFinalResult(
                        timeoutMs = 15000,
                ) { cb -> ShunPalm.previewStart(BaseLine.Params(), cb) }
        logD("palmEnrollment previewStart res code=${previewRes.code()} hint=${previewRes.hint()}")
        if (previewRes.code() != BaseLine.Code.SUCCEED) {
            try {
                ShunPalm.engineClear(noopCallback)
            } catch (_: Exception) {}
            return mapOf(
                    "error_code" to "PREVIEW_START_FAILED",
                    "error_message" to previewRes.hint(),
            )
        }

        logD("palmEnrollment collectStart start")
        val collectRes =
                awaitFinalResult(
                        timeoutMs = 30000,
                ) { cb -> ShunPalm.collectStart(BaseLine.Params(), cb) }
        logD("palmEnrollment collectStart res code=${collectRes.code()} hint=${collectRes.hint()}")

        try {
            ShunPalm.previewCease(noopCallback)
        } catch (_: Exception) {}
        try {
            ShunPalm.engineClear(noopCallback)
        } catch (_: Exception) {}

        if (collectRes.code() != BaseLine.Code.SUCCEED) {
            return mapOf(
                    "error_code" to "PALM_CAPTURE_FAILED",
                    "error_message" to collectRes.hint(),
            )
        }

        val nirFeature = collectRes.get("feature_nir") as? ByteArray
        val rgbFeature = collectRes.get("feature_rgb") as? ByteArray
        val score = collectRes.get("score") as? Float

        val featureBytes = nirFeature ?: rgbFeature
        logD(
                "palmEnrollment feature bytes nir=" +
                        (nirFeature?.size ?: 0) +
                        " rgb=" +
                        (rgbFeature?.size ?: 0)
        )
        if (featureBytes == null || featureBytes.isEmpty()) {
            return mapOf(
                    "error_code" to "MISSING_FEATURE",
                    "error_message" to "Palm capture succeeded but no feature bytes were returned.",
            )
        }

        val templateId =
                try {
                            ShunPalm.featureConversion(featureBytes)
                        } catch (_: Exception) {
                            null
                        }
                        ?.trim()
                        .orEmpty()
                        .ifEmpty { Base64.encodeToString(featureBytes, Base64.NO_WRAP) }
        logD("palmEnrollment template_id=" + redactForLog(templateId))

        val qualityScore: Int? =
                score?.let { s ->
                    val normalized = if (s <= 1.0f) (s * 100.0f) else s
                    normalized.toInt().coerceIn(0, 100)
                }
        logD("palmEnrollment quality_score=${qualityScore?.toString().orEmpty()}")

        return mapOf(
                "template_id" to templateId,
                "quality_score" to qualityScore,
        )
    }
}
