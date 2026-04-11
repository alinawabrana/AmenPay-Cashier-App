package com.example.amenpay_cashir_app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.app.ActivityManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.app.PendingIntent
import android.app.Presentation
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.content.pm.PackageManager
import android.provider.Settings
import android.util.Base64
import android.util.Log
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import android.print.pdf.PrintedPdfDocument
import android.view.InputDevice
import android.view.KeyEvent
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import com.leshun.hwinf.HWDataCallBack
import com.leshun.hwinf.LedAdapter
import com.leshun.hwinf.NFCAdapter
import com.leshun.hwinf.NFCInf
import com.leshun.hwinf.SerialPortAdapter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.math.BigInteger
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.charset.Charset
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

class MainActivity : FlutterActivity() {
    private val appBuildMarker = "amenpay-hwtest-r2026-03-03-19"
    private val crashPrefsName = "amenpay_crash_diag"
    private val crashHandlerLock = Any()
    private var crashHandlerInstalled = false
    private val ledLock = Any()
    private var ledAdapter: LedAdapter? = null
    private var testPresentation: Presentation? = null

    private val qrLock = Any()
    private var qrDevicePath = "/dev/ttyHSL3"
    private val qrReaderRunning = AtomicBoolean(false)
    private var qrEventSink: EventChannel.EventSink? = null
    private var qrReaderThread: Thread? = null
    private var qrInputStream: FileInputStream? = null
    private var qrSerialAdapter: SerialPortAdapter? = null
    private var qrSerialAdapterCallback: HWDataCallBack? = null
    private var qrSerialDriver: String = "raw"
    private var qrSerialAdapterLastInitError: String? = null
    private val qrSerialAdapterLastInitAtMs = AtomicLong(0L)
    private var lastQrPayload: String? = null
    private var lastQrAtMs: Long = 0L
    private val qrBroadcastRegistered = AtomicBoolean(false)
    private var qrBroadcastReceiver: BroadcastReceiver? = null
    private var lastBroadcastPayload: String? = null
    private var lastBroadcastAction: String? = null
    private val lastBroadcastAtMs = AtomicLong(0L)
    private val qrBroadcastFramesTotal = AtomicLong(0L)
    private val qrHidFramesTotal = AtomicLong(0L)
    private val hidLastKeyElapsedMs = AtomicLong(0L)
    private val hidLastDeviceId = AtomicInteger(-1)
    private var hidLastDeviceName: String = ""
    private val hidLastDeviceSources = AtomicInteger(0)
    private val hidLastScanAtMs = AtomicLong(0L)
    private val hidLastScanPayloadLen = AtomicInteger(0)
    private val hidBuffer = StringBuilder()
    private val hidFinalizeHandler = Handler(Looper.getMainLooper())
    private var hidFinalizeRunnable: Runnable? = null
    private var scanOnceLatch: CountDownLatch? = null
    private var scanOnceValue: AtomicReference<String?>? = null
    private val qrTerminators = setOf('\n', '\r', '\u0003', '\u0004')
    private val qrReaderStartElapsedMs = AtomicLong(0L)
    private val qrReaderBytesTotal = AtomicLong(0L)
    private val qrReaderFramesTotal = AtomicLong(0L)
    private val qrReaderLastByteElapsedMs = AtomicLong(0L)
    private val qrReaderLastLogElapsedMs = AtomicLong(0L)
    private val qrReaderLastTerminatorElapsedMs = AtomicLong(0L)
    private val qrSerialBufferLock = Any()
    private val qrSerialFrameBuffer = ByteArrayOutputStream()
    private var qrSerialFrameSource: String = "serial"
    private var qrSerialFrameMeta: Map<String, Any?> = emptyMap()
    private val qrSerialFrameSamplesLogged = AtomicInteger(0)
    private val qrSerialFinalizeHandler = Handler(Looper.getMainLooper())
    private var qrSerialFinalizeRunnable: Runnable? = null
    private var nfcEventSink: EventChannel.EventSink? = null
    private val nfcScanCount = AtomicLong(0L)
    private val nfcLastScanAtMs = AtomicLong(0L)
    private val nfcLastTagIdHex = AtomicReference<String>("")
    private val nfcLastTagIdDec = AtomicReference<String>("")
    private val nfcLastAction = AtomicReference<String>("")
    private val nfcLastTechList = AtomicReference<List<String>>(emptyList())
    private var nfcForegroundEnabled = false
    private val nfcVendorLock = Any()
    private var nfcVendorAdapter: NFCAdapter? = null
    private var nfcVendorCallback: HWDataCallBack? = null
    private val nfcVendorReading = AtomicBoolean(false)
    private val nfcVendorClassAvailable = AtomicBoolean(false)
    private val nfcVendorInitialized = AtomicBoolean(false)
    private val nfcVendorLastError = AtomicReference<String>("")
    private val nfcVendorInitCardType = AtomicReference<String>("")
    private val nfcVendorInitAttempts = AtomicReference<List<String>>(emptyList())
    private val nfcVendorAdapterClassName = AtomicReference<String>("")
    private val nfcVendorStartMethodName = AtomicReference<String>("")

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

    private fun crashPrefs() = getSharedPreferences(crashPrefsName, Context.MODE_PRIVATE)

    private fun stacktraceText(t: Throwable): String {
        return Log.getStackTraceString(t).orEmpty()
    }

    private fun installCrashDiagnosticsHandlerIfNeeded() {
        synchronized(crashHandlerLock) {
            if (crashHandlerInstalled) return
            val previous = Thread.getDefaultUncaughtExceptionHandler()
            Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
                try {
                    crashPrefs()
                            .edit()
                            .putLong("uncaught_at_ms", System.currentTimeMillis())
                            .putString("uncaught_thread", thread.name)
                            .putString("uncaught_type", throwable::class.java.name)
                            .putString("uncaught_message", throwable.message.orEmpty())
                            .putString("uncaught_stack", stacktraceText(throwable))
                            .putString("uncaught_build_marker", appBuildMarker)
                            .commit()
                } catch (_: Exception) {}
                previous?.uncaughtException(thread, throwable)
            }
            crashHandlerInstalled = true
        }
    }

    private fun crashDiagnostics(): Map<String, Any?> {
        val prefs = crashPrefs()
        val nowMs = System.currentTimeMillis()
        val stageAt = prefs.getLong("palm_last_stage_at_ms", -1L)
        val stageAge = if (stageAt > 0L) nowMs - stageAt else -1L
        val appStartedAt = prefs.getLong("app_last_started_at_ms", -1L)
        val appStartedAge = if (appStartedAt > 0L) nowMs - appStartedAt else -1L
        val errAt = prefs.getLong("palm_last_error_at_ms", -1L)
        val errAge = if (errAt > 0L) nowMs - errAt else -1L
        val uncaughtAt = prefs.getLong("uncaught_at_ms", -1L)
        val uncaughtAge = if (uncaughtAt > 0L) nowMs - uncaughtAt else -1L
        return mapOf(
                "report_schema_version" to "crash-diagnostic-v1",
                "app_build_info" to appBuildInfo(),
                "now_ms" to nowMs,
                "app_start" to
                        mapOf(
                                "at_ms" to appStartedAt,
                                "age_ms" to appStartedAge,
                                "build_marker" to
                                        prefs.getString("app_last_started_build_marker", "")
                                                .orEmpty(),
                        ),
                "palm_checkpoint" to
                        mapOf(
                                "stage" to prefs.getString("palm_last_stage", "").orEmpty(),
                                "detail" to prefs.getString("palm_last_detail", "").orEmpty(),
                                "at_ms" to stageAt,
                                "age_ms" to stageAge,
                                "build_marker" to
                                        prefs.getString("palm_last_build_marker", "").orEmpty(),
                        ),
                "palm_last_handled_error" to
                        mapOf(
                                "stage" to
                                        prefs.getString("palm_last_error_stage", "").orEmpty(),
                                "type" to prefs.getString("palm_last_error_type", "").orEmpty(),
                                "message" to
                                        prefs.getString("palm_last_error_message", "").orEmpty(),
                                "stack" to prefs.getString("palm_last_error_stack", "").orEmpty(),
                                "at_ms" to errAt,
                                "age_ms" to errAge,
                        ),
                "last_uncaught_exception" to
                        mapOf(
                                "thread" to prefs.getString("uncaught_thread", "").orEmpty(),
                                "type" to prefs.getString("uncaught_type", "").orEmpty(),
                                "message" to prefs.getString("uncaught_message", "").orEmpty(),
                                "stack" to prefs.getString("uncaught_stack", "").orEmpty(),
                                "at_ms" to uncaughtAt,
                                "age_ms" to uncaughtAge,
                                "build_marker" to
                                        prefs.getString("uncaught_build_marker", "").orEmpty(),
                        ),
                "process_exit_info" to recentProcessExitInfo(),
                "note" to
                        "If app dies in native code (SIGSEGV/abort), last checkpoint usually shows the last completed palm stage.",
        )
    }

    private fun clearCrashDiagnostics(): Boolean {
        crashPrefs().edit().clear().apply()
        return true
    }

    private fun markAppStarted() {
        crashPrefs()
                .edit()
                .putLong("app_last_started_at_ms", System.currentTimeMillis())
                .putString("app_last_started_build_marker", appBuildMarker)
                .commit()
    }

    private fun recentProcessExitInfo(): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return mapOf(
                    "available" to false,
                    "error" to "Requires Android 11+",
            )
        }
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val exits = am.getHistoricalProcessExitReasons(packageName, 0, 5)
            val items =
                    exits.map { info ->
                        val desc =
                                try {
                                    info.description
                                } catch (_: Exception) {
                                    ""
                                }
                        mapOf(
                                "timestamp_ms" to info.timestamp,
                                "reason" to info.reason,
                                "status" to info.status,
                                "importance" to info.importance,
                                "process_name" to info.processName,
                                "pid" to info.pid,
                                "description" to (desc ?: ""),
                        )
                    }
            mapOf(
                    "available" to true,
                    "count" to items.size,
                    "items" to items,
            )
        } catch (t: Throwable) {
            mapOf(
                    "available" to false,
                    "error" to (t.message ?: t::class.java.simpleName),
            )
        }
    }

    private fun qrDeviceSnapshot(): String {
        val path = synchronized(qrLock) { qrDevicePath }
        val f = File(path)
        return "path=$path exists=${f.exists()} canRead=${f.canRead()} canWrite=${f.canWrite()}"
    }

    private fun bytesToHex(bytes: ByteArray?): String {
        if (bytes == null || bytes.isEmpty()) return ""
        return bytes.joinToString("") { b -> String.format("%02X", b) }
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

    private fun scheduleSerialFinalizeLocked(delayMs: Long = 160L) {
        if (qrSerialFinalizeRunnable == null) {
            qrSerialFinalizeRunnable = Runnable { finalizeSerialFrame("idle_timeout") }
        }
        val pending = qrSerialFinalizeRunnable
        if (pending != null) {
            qrSerialFinalizeHandler.removeCallbacks(pending)
            qrSerialFinalizeHandler.postDelayed(pending, delayMs)
        }
    }

    private val qrSerialAssembleLock = Any()
    private val qrSerialPendingPayload = StringBuilder()
    private var qrSerialPendingMeta: Map<String, Any?> = emptyMap()
    private var qrSerialPendingSource: String = "serial"
    private var qrSerialPendingLastAtMs: Long = 0L
    private var qrSerialPendingRunnable: Runnable? = null

    private fun schedulePendingSerialEmit(delayMs: Long = 420L) {
        if (qrSerialPendingRunnable == null) {
            qrSerialPendingRunnable =
                    Runnable {
                        val now = SystemClock.elapsedRealtime()
                        var payload: String? = null
                        var source: String = "serial"
                        var meta: Map<String, Any?> = emptyMap()
                        synchronized(qrSerialAssembleLock) {
                            val age = now - qrSerialPendingLastAtMs
                            if (qrSerialPendingPayload.isNotEmpty() && age >= 360L) {
                                payload = qrSerialPendingPayload.toString()
                                qrSerialPendingPayload.setLength(0)
                                source = qrSerialPendingSource
                                meta = qrSerialPendingMeta
                            } else if (qrSerialPendingPayload.isNotEmpty()) {
                                // Not quiet long enough yet; reschedule.
                                schedulePendingSerialEmit(200L)
                            }
                        }
                        if (!payload.isNullOrEmpty()) {
                            emitQrPayloadFromSource(payload = payload!!, source = source, meta = meta)
                        }
                    }
        }
        val pending = qrSerialPendingRunnable
        if (pending != null) {
            qrSerialFinalizeHandler.removeCallbacks(pending)
            qrSerialFinalizeHandler.postDelayed(pending, delayMs)
        }
    }

    private fun normalizeSerialPayload(bytes: ByteArray): String {
        if (bytes.isEmpty()) return ""
        val utf =
                try {
                    String(bytes, Charsets.UTF_8)
                } catch (_: Exception) {
                    ""
                }
        if (utf.isNotEmpty()) {
            val clean =
                    utf
                            .map { ch ->
                                if (ch == '\t' || (ch.code in 32..126)) ch else ' '
                            }
                            .joinToString("")
                            .trim()
            if (clean.isNotEmpty()) return clean
        }
        return bytes.joinToString("") { b -> String.format("%02X", b) }
    }

    private fun finalizeSerialFrame(reason: String) {
        val payloadBytes: ByteArray
        val source: String
        val baseMeta: Map<String, Any?>
        synchronized(qrSerialBufferLock) {
            if (qrSerialFrameBuffer.size() <= 0) return
            payloadBytes = qrSerialFrameBuffer.toByteArray()
            qrSerialFrameBuffer.reset()
            source = qrSerialFrameSource
            baseMeta = qrSerialFrameMeta
        }
        emitSerialFrame(payloadBytes, reason, source, baseMeta)
    }

    private fun emitSerialFrame(
            payloadBytes: ByteArray,
            reason: String,
            source: String,
            baseMeta: Map<String, Any?>,
    ) {
        if (payloadBytes.isEmpty()) return
        val payload = normalizeSerialPayload(payloadBytes)
        if (payload.isBlank()) return
        val preview = bytesPreview(payloadBytes, payloadBytes.size)
        logD(
                "qrScanner/serial frame reason=$reason len=${payloadBytes.size} ascii=${preview["ascii_redacted"]} hex=${preview["hex_prefix"]}"
        )
        val meta = HashMap<String, Any?>()
        meta.putAll(baseMeta)
        meta["framing"] = reason
        meta["raw_len"] = payloadBytes.size
            meta["raw_hex_prefix"] = preview["hex_prefix"]
        if (reason == "terminator") {
            var merged = payload
            synchronized(qrSerialAssembleLock) {
                if (qrSerialPendingPayload.isNotEmpty()) {
                    merged = qrSerialPendingPayload.toString() + payload
                    qrSerialPendingPayload.setLength(0)
                }
            }
            emitQrPayloadFromSource(payload = merged, source = source, meta = meta)
            return
        }
        if (reason == "idle_timeout") {
            synchronized(qrSerialAssembleLock) {
                // If the pending buffer is stale, flush it first.
                val now = SystemClock.elapsedRealtime()
                if (qrSerialPendingPayload.isNotEmpty() && now - qrSerialPendingLastAtMs > 1500L) {
                    val stale = qrSerialPendingPayload.toString()
                    qrSerialPendingPayload.setLength(0)
                    emitQrPayloadFromSource(
                            payload = stale,
                            source = qrSerialPendingSource,
                            meta = qrSerialPendingMeta,
                    )
                }
                qrSerialPendingPayload.append(payload)
                qrSerialPendingSource = source
                qrSerialPendingMeta = meta
                qrSerialPendingLastAtMs = now
            }
            schedulePendingSerialEmit()
            return
        }
        emitQrPayloadFromSource(payload = payload, source = source, meta = meta)
    }

    private fun processSerialChunk(
            data: ByteArray,
            len: Int,
            source: String,
            meta: Map<String, Any?>,
    ) {
        if (len <= 0) return
        val safeLen = len.coerceAtMost(data.size).coerceAtLeast(0)
        if (safeLen <= 0) return
        if (qrSerialFrameSamplesLogged.get() < 3) {
            val next = qrSerialFrameSamplesLogged.incrementAndGet()
            if (next <= 3) {
                val preview = bytesPreview(data, safeLen)
                logD(
                        "qrScanner/serial sample#$next source=$source len=$safeLen ascii=${preview["ascii_redacted"]} hex=${preview["hex_prefix"]}"
                )
            }
        }
        val completedFrames = mutableListOf<ByteArray>()
        synchronized(qrSerialBufferLock) {
            qrSerialFrameSource = source
            qrSerialFrameMeta = meta
            for (i in 0 until safeLen) {
                val b = data[i].toInt() and 0xFF
                if (b == 0x0A || b == 0x0D || b == 0x03 || b == 0x04) {
                    qrReaderLastTerminatorElapsedMs.set(SystemClock.elapsedRealtime())
                    if (qrSerialFrameBuffer.size() > 0) {
                        completedFrames.add(qrSerialFrameBuffer.toByteArray())
                        qrSerialFrameBuffer.reset()
                    }
                    continue
                }
                if (qrSerialFrameBuffer.size() >= 4096) {
                    qrSerialFrameBuffer.reset()
                }
                qrSerialFrameBuffer.write(b)
            }
            scheduleSerialFinalizeLocked()
        }
        for (frame in completedFrames) {
            emitSerialFrame(frame, "terminator", source, meta)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            val now = SystemClock.elapsedRealtime()
            val lastAt = hidLastKeyElapsedMs.get()
            hidLastKeyElapsedMs.set(now)
            val inputDevice =
                    try {
                        InputDevice.getDevice(event.deviceId)
                    } catch (_: Exception) {
                        null
                    }
            if (inputDevice != null) {
                hidLastDeviceId.set(event.deviceId)
                hidLastDeviceName = inputDevice.name.orEmpty()
                hidLastDeviceSources.set(inputDevice.sources)
            }

            if (lastAt > 0L && now - lastAt > 750L) {
                if (inputDevice != null) {
                    logD(
                            "qrScanner/hid burst start device_id=${event.deviceId} device_name=${inputDevice.name.orEmpty()} sources=${inputDevice.sources}"
                    )
                } else {
                    logD("qrScanner/hid burst start device_id=${event.deviceId} device_name=unknown")
                }
                synchronized(hidBuffer) { hidBuffer.setLength(0) }
                val pending = hidFinalizeRunnable
                if (pending != null) {
                    hidFinalizeHandler.removeCallbacks(pending)
                }
            }

            val isTerminator =
                    event.keyCode == KeyEvent.KEYCODE_ENTER ||
                            event.keyCode == KeyEvent.KEYCODE_NUMPAD_ENTER ||
                            event.keyCode == KeyEvent.KEYCODE_TAB

            if (isTerminator) {
                val pending = hidFinalizeRunnable
                if (pending != null) {
                    hidFinalizeHandler.removeCallbacks(pending)
                }
                val payload =
                        synchronized(hidBuffer) {
                            val s = hidBuffer.toString().trim()
                            hidBuffer.setLength(0)
                            s
                        }
                if (payload.isNotEmpty()) {
                    hidLastScanAtMs.set(System.currentTimeMillis())
                    hidLastScanPayloadLen.set(payload.length)
                    logD(
                            "qrScanner/hid payload len=${payload.length} device_id=${hidLastDeviceId.get()} device_name=$hidLastDeviceName sources=${hidLastDeviceSources.get()}"
                    )
                    emitQrPayloadFromSource(
                            payload = payload,
                            source = "hid",
                            meta =
                                    mapOf(
                                            "keycode" to event.keyCode,
                                    ),
                    )
                }
                return super.dispatchKeyEvent(event)
            }

            val unicode = event.unicodeChar
            if (unicode != 0) {
                val ch = unicode.toChar()
                val shouldAppend = !Character.isISOControl(ch)
                if (shouldAppend) {
                    synchronized(hidBuffer) {
                        if (hidBuffer.length >= 2048) {
                            hidBuffer.setLength(0)
                        }
                        hidBuffer.append(ch)
                    }

                    if (hidFinalizeRunnable == null) {
                        hidFinalizeRunnable = Runnable {
                            val payload =
                                    synchronized(hidBuffer) {
                                        val s = hidBuffer.toString().trim()
                                        hidBuffer.setLength(0)
                                        s
                                    }
                            if (payload.isNotEmpty()) {
                                hidLastScanAtMs.set(System.currentTimeMillis())
                                hidLastScanPayloadLen.set(payload.length)
                                logD(
                                        "qrScanner/hid payload len=${payload.length} device_id=${hidLastDeviceId.get()} device_name=$hidLastDeviceName sources=${hidLastDeviceSources.get()} terminator=timeout"
                                )
                                emitQrPayloadFromSource(
                                        payload = payload,
                                        source = "hid",
                                        meta =
                                                mapOf(
                                                        "terminator" to "timeout",
                                                ),
                                )
                            }
                        }
                    }
                    val pending = hidFinalizeRunnable
                    if (pending != null) {
                        hidFinalizeHandler.removeCallbacks(pending)
                        hidFinalizeHandler.postDelayed(pending, 300L)
                    }
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        installCrashDiagnosticsHandlerIfNeeded()
        markAppStarted()

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
                        "getHardwareConfigReport" -> {
                            result.success(hardwareConfigReport())
                        }
                        "getAppBuildInfo" -> {
                            result.success(appBuildInfo())
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
                        "getScreenBrightness" -> {
                            val adapter = ensureLedAdapter()
                            if (adapter == null) {
                                result.error(
                                        "LED_ADAPTER_UNAVAILABLE",
                                        "LedAdapter init failed",
                                        null
                                )
                                return@setMethodCallHandler
                            }
                            val level = adapter.getScreenBrightness()
                            logD("posDevice/getScreenBrightness level=$level")
                            result.success(level)
                        }
                        "setScreenBrightness" -> {
                            val args = call.arguments
                            val levelRaw =
                                    when (args) {
                                        is Number -> args.toInt()
                                        is String -> args.toIntOrNull()
                                        is Map<*, *> -> args["level"]?.toString()?.toIntOrNull()
                                        else -> null
                                    }
                            if (levelRaw == null) {
                                result.error("INVALID_ARGUMENT", "level is required", null)
                                return@setMethodCallHandler
                            }
                            val level = levelRaw.coerceIn(0, 255)
                            val adapter = ensureLedAdapter()
                            if (adapter == null) {
                                result.error(
                                        "LED_ADAPTER_UNAVAILABLE",
                                        "LedAdapter init failed",
                                        null
                                )
                                return@setMethodCallHandler
                            }
                            val ok = adapter.setScreenBrightness(level)
                            logD("posDevice/setScreenBrightness level=$level ok=$ok")
                            result.success(ok)
                        }
                        "getDisplayDiagnostics" -> {
                            try {
                                val dm = getSystemService(Context.DISPLAY_SERVICE) as android.hardware.display.DisplayManager
                                val displays = dm.displays
                                val list =
                                        displays.map { d ->
                                            mapOf(
                                                    "id" to d.displayId,
                                                    "name" to d.name,
                                                    "state" to d.state,
                                                    "flags" to d.flags,
                                                    "width" to d.mode.physicalWidth,
                                                    "height" to d.mode.physicalHeight,
                                                    "refresh_rate" to d.mode.refreshRate,
                                                    "is_default" to (d.displayId == 0),
                                            )
                                        }
                                val out =
                                        mapOf(
                                                "default_display_id" to 0,
                                                "count" to displays.size,
                                                "displays" to list,
                                )
                                logD("posDevice/getDisplayDiagnostics count=${displays.size}")
                                result.success(out)
                            } catch (t: Throwable) {
                                result.error(
                                        "DISPLAY_DIAG_FAILED",
                                        t.message,
                                        null
                                )
                            }
                        }
                        "showTestPresentation" -> {
                            val args = call.arguments
                            val displayId =
                                    when (args) {
                                        is Number -> args.toInt()
                                        is String -> args.toIntOrNull()
                                        is Map<*, *> -> args["display_id"]?.toString()?.toIntOrNull()
                                        else -> null
                                    }
                            val ok = showTestPresentation(displayId)
                            logD("posDevice/showTestPresentation display_id=${displayId ?: -1} ok=$ok")
                            result.success(ok)
                        }
                        "dismissTestPresentation" -> {
                            dismissTestPresentation()
                            logD("posDevice/dismissTestPresentation ok=true")
                            result.success(true)
                        }
                        "rebootDevice" -> {
                            try {
                                logD("posDevice/rebootDevice requested")
                                val systemAdapter = com.leshun.hwinf.SystemAdapter()
                                if (!systemAdapter.init(this)) {
                                    result.error(
                                            "SYSTEM_ADAPTER_UNAVAILABLE",
                                            "SystemAdapter init failed",
                                            null
                                    )
                                    return@setMethodCallHandler
                                }
                                systemAdapter.reboot()
                                result.success(true)
                            } catch (t: Throwable) {
                                result.error("REBOOT_FAILED", t.message, null)
                            }
                        }
                        else -> result.notImplemented()
                    }
                }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "receiptPrinter/methods")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "printTextReceipt" -> {
                            val args = call.arguments as? Map<*, *>
                            val jobName =
                                    args?.get("job_name")?.toString()?.trim().orEmpty().ifEmpty {
                                        "AmenPay Receipt"
                                    }
                            val text = args?.get("text")?.toString()
                            if (text.isNullOrBlank()) {
                                result.error("INVALID_ARGUMENT", "text is required", null)
                                return@setMethodCallHandler
                            }
                            try {
                                printTextReceipt(jobName, text)
                                result.success(true)
                            } catch (t: Throwable) {
                                result.error("PRINT_FAILED", t.message, null)
                            }
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
                        "runSerialStartSequenceTest" -> {
                            val args = call.arguments as? Map<*, *>
                            val path =
                                    args?.get("path")?.toString()?.trim().orEmpty().ifEmpty {
                                        "/dev/ttyHSL3"
                                    }
                            val baud =
                                    args?.get("baud")?.toString()?.toIntOrNull() ?: 9600
                            val waitMs =
                                    args?.get("wait_ms")?.toString()?.toLongOrNull() ?: 3000L
                            Thread {
                                        try {
                                            val payload =
                                                    runSerialStartSequenceTest(path, baud, waitMs)
                                            runOnUiThread { result.success(payload) }
                                        } catch (e: Exception) {
                                            runOnUiThread {
                                                result.error(
                                                        "QR_SERIAL_SEQUENCE_TEST_FAILED",
                                                        e.message,
                                                        null
                                                )
                                            }
                                        }
                                    }
                                    .start()
                        }
                        "runFactoryParityScannerProbe" -> {
                            val args = call.arguments as? Map<*, *>
                            val path =
                                    args?.get("path")?.toString()?.trim().orEmpty().ifEmpty {
                                        "/dev/ttyHSL3"
                                    }
                            val baud =
                                    args?.get("baud")?.toString()?.toIntOrNull() ?: 9600
                            val waitMs =
                                    args?.get("wait_ms")?.toString()?.toLongOrNull() ?: 4000L
                            Thread {
                                        try {
                                            val payload = runFactoryParityScannerProbe(path, baud, waitMs)
                                            runOnUiThread { result.success(payload) }
                                        } catch (e: Exception) {
                                            runOnUiThread {
                                                result.error(
                                                        "QR_FACTORY_PARITY_PROBE_FAILED",
                                                        e.message,
                                                        null
                                                )
                                            }
                                        }
                                    }
                                    .start()
                        }
                        "runUsbTransportProbe" -> {
                            val args = call.arguments as? Map<*, *>
                            val vendorId =
                                    args?.get("vendor_id")?.toString()?.toIntOrNull()
                            val productId =
                                    args?.get("product_id")?.toString()?.toIntOrNull()
                            val readTimeoutMs =
                                    args?.get("read_timeout_ms")?.toString()?.toIntOrNull()
                                            ?: 1200
                            val readAttempts =
                                    args?.get("read_attempts")?.toString()?.toIntOrNull()
                                            ?: 3
                            Thread {
                                        try {
                                            val payload =
                                                    runUsbTransportProbe(
                                                            vendorId = vendorId,
                                                            productId = productId,
                                                            readTimeoutMs = readTimeoutMs,
                                                            readAttempts = readAttempts,
                                                    )
                                            runOnUiThread { result.success(payload) }
                                        } catch (e: Exception) {
                                            runOnUiThread {
                                                result.error(
                                                        "USB_TRANSPORT_PROBE_FAILED",
                                                        e.message,
                                                        null
                                                )
                                            }
                                        }
                                    }
                                    .start()
                        }
                        "runUsbSniffProbe" -> {
                            val args = call.arguments as? Map<*, *>
                            val vendorId =
                                    args?.get("vendor_id")?.toString()?.toIntOrNull()
                            val productId =
                                    args?.get("product_id")?.toString()?.toIntOrNull()
                            val durationMs =
                                    args?.get("duration_ms")?.toString()?.toIntOrNull()
                                            ?: 15000
                            val readTimeoutMs =
                                    args?.get("read_timeout_ms")?.toString()?.toIntOrNull()
                                            ?: 300
                            val triggerSweep =
                                    args?.get("trigger_sweep")?.toString()?.toBooleanStrictOrNull()
                                            ?: true
                            Thread {
                                        try {
                                            val payload =
                                                    runUsbSniffProbe(
                                                            vendorId = vendorId,
                                                            productId = productId,
                                                            durationMs = durationMs,
                                                            readTimeoutMs = readTimeoutMs,
                                                            triggerSweep = triggerSweep,
                                                    )
                                            runOnUiThread { result.success(payload) }
                                        } catch (e: Exception) {
                                            runOnUiThread {
                                                result.error(
                                                        "USB_SNIFF_PROBE_FAILED",
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

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "nfcScanner/events")
                .setStreamHandler(
                        object : EventChannel.StreamHandler {
                            override fun onListen(
                                    arguments: Any?,
                                    events: EventChannel.EventSink?,
                            ) {
                                nfcEventSink = events
                                enableNfcForegroundDispatchIfPossible()
                                startVendorNfcReadIfPossible()
                                resultNfcState()
                            }

                            override fun onCancel(arguments: Any?) {
                                nfcEventSink = null
                                stopVendorNfcReadIfNeeded()
                                disableNfcForegroundDispatchIfEnabled()
                            }
                        }
                )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nfcScanner/methods")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getNfcDiagnostics" -> {
                            result.success(nfcDiagnostics())
                        }
                        else -> result.notImplemented()
                    }
                }
    }

    private fun printTextReceipt(jobName: String, text: String) {
        val printManager = getSystemService(Context.PRINT_SERVICE) as? PrintManager
                ?: throw IllegalStateException("Print service unavailable")
        printManager.print(jobName, TextReceiptPrintAdapter(this, jobName, text), null)
    }

    private class TextReceiptPrintAdapter(
            private val context: Context,
            private val jobName: String,
            private val text: String
    ) : PrintDocumentAdapter() {
        private var pdfDocument: PrintedPdfDocument? = null

        override fun onLayout(
                oldAttributes: PrintAttributes?,
                newAttributes: PrintAttributes,
                cancellationSignal: android.os.CancellationSignal,
                callback: LayoutResultCallback,
                extras: android.os.Bundle?
        ) {
            pdfDocument?.close()
            pdfDocument = PrintedPdfDocument(context, newAttributes)
            if (cancellationSignal.isCanceled) {
                callback.onLayoutCancelled()
                return
            }
            val info =
                    PrintDocumentInfo.Builder("$jobName.pdf")
                            .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                            .setPageCount(1)
                            .build()
            callback.onLayoutFinished(info, true)
        }

        override fun onWrite(
                pages: Array<out PageRange>,
                destination: android.os.ParcelFileDescriptor,
                cancellationSignal: android.os.CancellationSignal,
                callback: WriteResultCallback
        ) {
            val document = pdfDocument ?: run {
                callback.onWriteFailed("Print document not initialized")
                return
            }
            try {
                val page = document.startPage(0)
                val canvas = page.canvas
                val paint =
                        Paint().apply {
                            color = Color.BLACK
                            textSize = 12f
                            typeface = Typeface.MONOSPACE
                            isAntiAlias = true
                        }
                val left = 36f
                val top = 48f
                val lineHeight = paint.fontSpacing + 4f
                val maxWidth = page.info.pageWidth - (left * 2)
                var y = top
                for (line in wrapReceiptText(text, paint, maxWidth)) {
                    if (cancellationSignal.isCanceled) {
                        document.close()
                        callback.onWriteCancelled()
                        return
                    }
                    canvas.drawText(line, left, y, paint)
                    y += lineHeight
                }
                document.finishPage(page)
                FileOutputStream(destination.fileDescriptor).use { output ->
                    document.writeTo(output)
                }
                callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
            } catch (t: Throwable) {
                callback.onWriteFailed(t.message)
            } finally {
                document.close()
                pdfDocument = null
            }
        }

        private fun wrapReceiptText(text: String, paint: Paint, maxWidth: Float): List<String> {
            val lines = mutableListOf<String>()
            val paragraphs = text.split('\n')
            for (paragraph in paragraphs) {
                if (paragraph.isEmpty()) {
                    lines += ""
                    continue
                }
                var remaining = paragraph.trim()
                while (remaining.isNotEmpty()) {
                    var count = paint.breakText(remaining, true, maxWidth, null)
                    if (count <= 0) {
                        count = remaining.length.coerceAtMost(1)
                    }
                    if (count < remaining.length) {
                        val lastSpace = remaining.substring(0, count).lastIndexOf(' ')
                        if (lastSpace > 0) {
                            count = lastSpace
                        }
                    }
                    val line = remaining.substring(0, count).trimEnd()
                    lines += line
                    remaining = remaining.substring(count).trimStart()
                }
            }
            return lines
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNfcIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        if (nfcEventSink != null) {
            enableNfcForegroundDispatchIfPossible()
            startVendorNfcReadIfPossible()
        }
        handleNfcIntent(intent)
    }

    override fun onPause() {
        stopVendorNfcReadIfNeeded()
        disableNfcForegroundDispatchIfEnabled()
        super.onPause()
    }

    private fun ensureLedAdapter(): LedAdapter? {
        synchronized(ledLock) {
            val existing = ledAdapter
            if (existing != null) return existing
            val adapter = LedAdapter()
            val ok = try {
                adapter.init(this)
            } catch (_: Exception) {
                false
            }
            if (!ok) {
                try {
                    adapter.deInit()
                } catch (_: Exception) {}
                return null
            }
            ledAdapter = adapter
            return adapter
        }
    }

    private fun showTestPresentation(displayId: Int?): Boolean {
        val dm = getSystemService(Context.DISPLAY_SERVICE) as android.hardware.display.DisplayManager
        val displays = dm.displays
        val target =
                if (displayId != null) displays.firstOrNull { it.displayId == displayId }
                else displays.firstOrNull { it.displayId != 0 }
        target ?: return false

        testPresentation?.dismiss()
        testPresentation =
                object : Presentation(this, target) {
                    override fun onCreate(savedInstanceState: android.os.Bundle?) {
                        super.onCreate(savedInstanceState)
                        val root =
                                FrameLayout(context).apply {
                                    setBackgroundColor(0xFF111827.toInt())
                                }
                        val label =
                                TextView(context).apply {
                                    text = "Display Test\nid=${target.displayId} ${target.name}"
                                    setTextColor(0xFFFFFFFF.toInt())
                                    textSize = 20f
                                    gravity = Gravity.CENTER
                                }
                        root.addView(
                                label,
                                FrameLayout.LayoutParams(
                                        FrameLayout.LayoutParams.MATCH_PARENT,
                                        FrameLayout.LayoutParams.MATCH_PARENT,
                                ),
                        )
                        setContentView(root)
                        window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION)
                    }
                }
        testPresentation?.show()
        return true
    }

    private fun dismissTestPresentation() {
        testPresentation?.dismiss()
        testPresentation = null
    }

    private fun resultNfcState() {
        nfcEventSink?.success(
                mapOf(
                        "type" to "state",
                        "diagnostics" to nfcDiagnostics(),
                )
        )
    }

    private fun enableNfcForegroundDispatchIfPossible() {
        val adapter = NfcAdapter.getDefaultAdapter(this) ?: return
        if (!adapter.isEnabled) return
        if (nfcForegroundEnabled) return
        try {
            val pendingIntent =
                    PendingIntent.getActivity(
                            this,
                            0,
                            Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                            } else {
                                PendingIntent.FLAG_UPDATE_CURRENT
                            },
                    )
            val filters =
                    arrayOf(
                            IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED),
                            IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED),
                            IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED),
                    )
            adapter.enableForegroundDispatch(this, pendingIntent, filters, null)
            nfcForegroundEnabled = true
        } catch (e: Exception) {
            logE("nfcScanner/enableForegroundDispatch failed: ${e.message}", e)
        }
    }

    private fun disableNfcForegroundDispatchIfEnabled() {
        if (!nfcForegroundEnabled) return
        val adapter = NfcAdapter.getDefaultAdapter(this) ?: return
        try {
            adapter.disableForegroundDispatch(this)
        } catch (e: Exception) {
            logE("nfcScanner/disableForegroundDispatch failed: ${e.message}", e)
        } finally {
            nfcForegroundEnabled = false
        }
    }

    private fun handleNfcIntent(intent: Intent?) {
        val action = intent?.action.orEmpty()
        if (action != NfcAdapter.ACTION_TAG_DISCOVERED &&
                        action != NfcAdapter.ACTION_TECH_DISCOVERED &&
                        action != NfcAdapter.ACTION_NDEF_DISCOVERED
        ) {
            return
        }
        val tag = intent?.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
        val idHex = bytesToHex(tag?.id)
        val techList = tag?.techList?.toList().orEmpty()
        val scanCount = nfcScanCount.incrementAndGet()
        val atMs = System.currentTimeMillis()
        nfcLastScanAtMs.set(atMs)
        nfcLastTagIdHex.set(idHex)
        nfcLastTagIdDec.set(bytesHexToDecString(idHex))
        nfcLastAction.set(action)
        nfcLastTechList.set(techList)
        logD(
                "nfcScanner/tag action=$action id=${if (idHex.isBlank()) "n/a" else idHex} techs=${techList.joinToString(",")}"
        )
        nfcEventSink?.success(
                mapOf(
                        "type" to "tag",
                        "action" to action,
                        "tag_id_hex" to idHex,
                        "tech_list" to techList,
                "scan_count" to scanCount,
                "scanned_at_ms" to atMs,
                "source" to "android_nfc",
                "tag_id_dec" to bytesHexToDecString(idHex),
                )
        )
    }

    private fun bytesHexToDecString(idHex: String): String {
        if (idHex.isBlank()) return ""
        return try {
            BigInteger(idHex, 16).toString(10)
        } catch (_: Exception) {
            ""
        }
    }

    private fun ensureVendorNfcInitialized(): Boolean {
        synchronized(nfcVendorLock) {
            if (nfcVendorAdapter != null && nfcVendorInitialized.get()) return true
            try {
                nfcVendorClassAvailable.set(true)
                val adapter = NFCAdapter.getInstance()
                if (adapter == null) {
                    nfcVendorLastError.set("NFCAdapter.getInstance returned null")
                    nfcVendorInitialized.set(false)
                    return false
                }

                val tryOrder =
                        listOf(
                                NFCInf.NFC_CARD_TYPE.CARD_TYPE_AUTO,
                                NFCInf.NFC_CARD_TYPE.CARD_TYPE_Mifare,
                                NFCInf.NFC_CARD_TYPE.CARD_TYPE_PlusCPU,
                                NFCInf.NFC_CARD_TYPE.CARD_TYPE_CPU,
                        )
                val attempts = mutableListOf<String>()
                var selectedType: NFCInf.NFC_CARD_TYPE? = null
                for (cardType in tryOrder) {
                    val ok =
                            try {
                                adapter.init(this, cardType)
                            } catch (t: Throwable) {
                                attempts.add("${cardType.name}:exception:${t.javaClass.simpleName}")
                                false
                            }
                    attempts.add("${cardType.name}:${if (ok) "ok" else "false"}")
                    if (ok) {
                        selectedType = cardType
                        break
                    }
                }

                nfcVendorInitAttempts.set(attempts)
                if (selectedType == null) {
                    nfcVendorInitCardType.set("")
                    try {
                        adapter.deInit()
                    } catch (_: Exception) {}
                    nfcVendorLastError.set(
                            "vendor NFC init returned false (attempts=${attempts.joinToString(",")})"
                    )
                    return false
                }

                nfcVendorInitCardType.set(selectedType.name)
                nfcVendorAdapterClassName.set("com.leshun.hwinf.NFCAdapter")
                nfcVendorStartMethodName.set("startRead(HWDataCallBack,boolean)")
                nfcVendorAdapter = adapter
                nfcVendorInitialized.set(true)
                nfcVendorLastError.set("")
                return true
            } catch (t: Throwable) {
                nfcVendorClassAvailable.set(t !is ClassNotFoundException && t !is NoClassDefFoundError)
                nfcVendorInitialized.set(false)
                nfcVendorInitCardType.set("")
                nfcVendorInitAttempts.set(emptyList())
                nfcVendorAdapterClassName.set("")
                nfcVendorStartMethodName.set("")
                nfcVendorLastError.set(
                        "${t.javaClass.simpleName}:${t.message ?: "vendor NFC init failed"}"
                )
                return false
            }
        }
    }

    private fun startVendorNfcReadIfPossible() {
        synchronized(nfcVendorLock) {
            if (nfcVendorReading.get()) return
            if (!ensureVendorNfcInitialized()) return
            val adapter = nfcVendorAdapter
            try {
                val callback =
                        object : HWDataCallBack {
                            override fun onDataReceived(bytes: ByteArray, len: Int) {
                                val safeLen = len.coerceIn(0, bytes.size)
                                val data = if (safeLen <= 0) ByteArray(0) else bytes.copyOf(safeLen)
                                val idHex = bytesToHex(data)
                                val idDec = try {
                                    if (idHex.isBlank()) "" else BigInteger(idHex, 16).toString(10)
                                } catch (_: Exception) {
                                    ""
                                }
                                val atMs = System.currentTimeMillis()
                                val scanCount = nfcScanCount.incrementAndGet()
                                nfcLastScanAtMs.set(atMs)
                                nfcLastTagIdHex.set(idHex)
                                nfcLastTagIdDec.set(idDec)
                                nfcLastAction.set("VENDOR_HW_NFC")
                                nfcLastTechList.set(emptyList())
                                logD(
                                        "nfcScanner/vendor id_hex=${if (idHex.isBlank()) "n/a" else idHex} id_dec=${if (idDec.isBlank()) "n/a" else idDec}"
                                )
                                runOnUiThread {
                                    nfcEventSink?.success(
                                            mapOf(
                                                    "type" to "tag",
                                                    "action" to "VENDOR_HW_NFC",
                                                    "tag_id_hex" to idHex,
                                                    "tag_id_dec" to idDec,
                                                    "tech_list" to emptyList<String>(),
                                                    "scan_count" to scanCount,
                                                    "scanned_at_ms" to atMs,
                                                    "source" to "vendor_hwinf",
                                            )
                                    )
                                }
                            }

                            override fun onError(s: String?) {
                                val err = s.orEmpty()
                                nfcVendorLastError.set(if (err.isBlank()) "vendor NFC read error" else err)
                                logE("nfcScanner/vendor onError: $err")
                            }
                        }
                nfcVendorCallback = callback
                val ok =
                        if (adapter != null) adapter.startRead(callback, false) else false
                nfcVendorReading.set(ok)
                if (!ok) {
                    nfcVendorLastError.set("vendor NFC startRead returned false")
                } else {
                    nfcVendorLastError.set("")
                }
            } catch (t: Throwable) {
                nfcVendorReading.set(false)
                nfcVendorLastError.set(
                        "${t.javaClass.simpleName}:${t.message ?: "vendor NFC startRead failed"}"
                )
                logE("nfcScanner/vendor startRead failed: ${t.message}", t)
            }
        }
    }

    private fun stopVendorNfcReadIfNeeded() {
        synchronized(nfcVendorLock) {
            val adapter = nfcVendorAdapter
            if (!nfcVendorReading.get()) return
            try {
                if (adapter != null) {
                    adapter.stopRead()
                }
            } catch (t: Throwable) {
                nfcVendorLastError.set(
                        "${t.javaClass.simpleName}:${t.message ?: "vendor NFC stopRead failed"}"
                )
            } finally {
                nfcVendorReading.set(false)
            }
        }
    }

    private fun nfcDiagnostics(): Map<String, Any?> {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        val now = System.currentTimeMillis()
        return mapOf(
                "available" to (adapter != null),
                "enabled" to (adapter?.isEnabled == true),
                "has_feature_nfc" to packageManager.hasSystemFeature("android.hardware.nfc"),
                "last_scan_age_ms" to
                        nfcLastScanAtMs.get().let { if (it <= 0L) -1L else now - it },
                "last_scan_at_ms" to nfcLastScanAtMs.get(),
                "last_action" to nfcLastAction.get(),
                "last_tag_id_hex" to nfcLastTagIdHex.get(),
                "last_tag_id_dec" to nfcLastTagIdDec.get(),
                "last_tech_list" to nfcLastTechList.get(),
                "scan_count" to nfcScanCount.get(),
                "vendor_hwinf_class_available" to nfcVendorClassAvailable.get(),
                "vendor_hwinf_initialized" to nfcVendorInitialized.get(),
                "vendor_hwinf_reading" to nfcVendorReading.get(),
                "vendor_hwinf_init_card_type" to nfcVendorInitCardType.get(),
                "vendor_hwinf_init_attempts" to nfcVendorInitAttempts.get(),
                "vendor_hwinf_adapter_class" to nfcVendorAdapterClassName.get(),
                "vendor_hwinf_start_method" to nfcVendorStartMethodName.get(),
                "vendor_hwinf_last_error" to nfcVendorLastError.get(),
        )
    }

    private fun listSerialPortsRaw(): List<Map<String, Any>> {
        val devDir = File("/dev")
        val files =
                try {
                    devDir.listFiles()?.toList().orEmpty()
                } catch (_: Exception) {
                    emptyList()
                }
        return files
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
    }

    private fun hardwareConfigReport(): Map<String, Any?> {
        val androidId =
                Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID).orEmpty()
        val pkgInfo =
                try {
                    if (Build.VERSION.SDK_INT >= 33) {
                        packageManager.getPackageInfo(
                                packageName,
                                android.content.pm.PackageManager.PackageInfoFlags.of(0)
                        )
                    } else {
                        @Suppress("DEPRECATION") packageManager.getPackageInfo(packageName, 0)
                    }
                } catch (_: Exception) {
                    null
                }
        val appVersionName = pkgInfo?.versionName.orEmpty()
        val appVersionCode =
                if (pkgInfo == null) {
                    -1L
                } else if (Build.VERSION.SDK_INT >= 28) {
                    pkgInfo.longVersionCode
                } else {
                    @Suppress("DEPRECATION")
                    pkgInfo.versionCode.toLong()
                }
        val appLastUpdateTimeMs = pkgInfo?.lastUpdateTime ?: -1L
        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
        val usbDeviceList = usbManager?.deviceList?.values?.toList().orEmpty()
        val cameraProbe = cameraProbe()
        val usbModuleReadiness = usbModuleReadiness(usbManager, usbDeviceList)
        val vendorPackageProbe = vendorPackageProbe()
        val scannerIntentProbe = scannerIntentProbe()
        val usbDevices =
                usbDeviceList
                        .map { device ->
                            mapOf(
                                    "device_name" to device.deviceName.orEmpty(),
                                    "vendor_id" to device.vendorId,
                                    "product_id" to device.productId,
                                    "manufacturer_name" to
                                            ((if (Build.VERSION.SDK_INT >= 21) device.manufacturerName
                                            else null)
                                                    ?: ""),
                                    "product_name" to
                                            ((if (Build.VERSION.SDK_INT >= 21) device.productName
                                            else null)
                                                    ?: ""),
                            )
                        }
                        .toList()
        val serialCandidates = listSerialPortsRaw()
        val serialProbe = probeQrSerialAdapter(serialCandidates)
        val hidInputDevices = listHidInputDevices()
        val qrInputDeviceCandidates = qrInputDeviceCandidates(hidInputDevices)
        val linuxInputNodes = linuxInputNodes()
        val qrInputEventCandidates = qrInputEventCandidates(qrInputDeviceCandidates, linuxInputNodes)
        val scannerBroadcastPackages = scannerBroadcastPackagesStatus()
        val serialDriverMetadata = serialDriverMetadata(serialCandidates)
        val integrationHints =
                buildIntegrationHints(
                        serialProbe = serialProbe,
                        hidDevices = hidInputDevices,
                        qrInputCandidates = qrInputDeviceCandidates,
                        broadcastPackages = scannerBroadcastPackages,
                )
        val hidLastScanAt = hidLastScanAtMs.get()
        val hidLastScanAgeMs =
                if (hidLastScanAt > 0L) {
                    System.currentTimeMillis() - hidLastScanAt
                } else {
                    -1L
                }

        return mapOf(
                "report_schema_version" to "hardware-config-v5",
                "report_generated_at_ms" to System.currentTimeMillis(),
                "app_build_marker" to appBuildMarker,
                "app_package_name" to packageName,
                "app_version_name" to appVersionName,
                "app_version_code" to appVersionCode,
                "app_last_update_time_ms" to appLastUpdateTimeMs,
                "manufacturer" to Build.MANUFACTURER.orEmpty(),
                "brand" to Build.BRAND.orEmpty(),
                "model" to Build.MODEL.orEmpty(),
                "device" to Build.DEVICE.orEmpty(),
                "product" to Build.PRODUCT.orEmpty(),
                "hardware" to Build.HARDWARE.orEmpty(),
                "android_id" to androidId,
                "serial_port_candidates" to serialCandidates,
                "serial_driver_metadata" to serialDriverMetadata,
                "qr_serial_adapter_probe" to serialProbe,
                "qr_hid_input_devices" to hidInputDevices,
                "qr_input_device_candidates" to qrInputDeviceCandidates,
                "linux_input_nodes" to linuxInputNodes,
                "qr_input_event_candidates" to qrInputEventCandidates,
                "qr_hid_last_scan" to
                        mapOf(
                                "device_id" to hidLastDeviceId.get(),
                                "device_name" to hidLastDeviceName,
                                "device_sources" to hidLastDeviceSources.get(),
                                "payload_len" to hidLastScanPayloadLen.get(),
                                "scan_age_ms" to hidLastScanAgeMs,
                        ),
                "scanner_broadcast_packages_installed" to scannerBroadcastPackages,
                "system_leshun_hwdevice_jar_exists" to
                        File("/system/framework/com.leshun.hwdevice.jar").exists(),
                "camera_probe" to cameraProbe,
                "vendor_package_probe" to vendorPackageProbe,
                "scanner_intent_probe" to scannerIntentProbe,
                "usb_devices" to usbDevices,
                "usb_module_readiness" to usbModuleReadiness,
                "integration_hints" to integrationHints,
        )
    }

    private fun appBuildInfo(): Map<String, Any?> {
        val pkgInfo =
                try {
                    if (Build.VERSION.SDK_INT >= 33) {
                        packageManager.getPackageInfo(
                                packageName,
                                android.content.pm.PackageManager.PackageInfoFlags.of(0)
                        )
                    } else {
                        @Suppress("DEPRECATION") packageManager.getPackageInfo(packageName, 0)
                    }
                } catch (_: Exception) {
                    null
                }
        val appVersionName = pkgInfo?.versionName.orEmpty()
        val appVersionCode =
                if (pkgInfo == null) {
                    -1L
                } else if (Build.VERSION.SDK_INT >= 28) {
                    pkgInfo.longVersionCode
                } else {
                    @Suppress("DEPRECATION")
                    pkgInfo.versionCode.toLong()
                }
        return mapOf(
                "app_build_marker" to appBuildMarker,
                "app_package_name" to packageName,
                "app_version_name" to appVersionName,
                "app_version_code" to appVersionCode,
                "app_last_update_time_ms" to (pkgInfo?.lastUpdateTime ?: -1L),
                "apk_path" to applicationInfo.sourceDir.orEmpty(),
        )
    }

    private fun getPackageInfoCompat(packageName: String): android.content.pm.PackageInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= 33) {
                packageManager.getPackageInfo(
                        packageName,
                        android.content.pm.PackageManager.PackageInfoFlags.of(
                                (
                                        android.content.pm.PackageManager.GET_ACTIVITIES or
                                                android.content.pm.PackageManager.GET_SERVICES or
                                                android.content.pm.PackageManager.GET_RECEIVERS or
                                                android.content.pm.PackageManager.GET_PROVIDERS
                                        ).toLong()
                        )
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                        packageName,
                        android.content.pm.PackageManager.GET_ACTIVITIES or
                                android.content.pm.PackageManager.GET_SERVICES or
                                android.content.pm.PackageManager.GET_RECEIVERS or
                                android.content.pm.PackageManager.GET_PROVIDERS
                )
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun vendorPackageProbe(): Map<String, Any?> {
        val candidates =
                listOf(
                        "com.leshun",
                        "com.leshun.factorytest",
                        "com.leshun.factory",
                        "com.leshun.scanner",
                        "com.leshun.scanservice",
                        "com.shiyun",
                        "com.veinshine",
                        "com.xinran.device",
                        "com.xzy.poshardscanservice",
                        "com.xzy.pos",
                )
        val found = mutableListOf<Map<String, Any?>>()
        for (pkg in candidates) {
            val info = getPackageInfoCompat(pkg) ?: continue
            val activities =
                    info.activities
                            ?.filter { it.exported }
                            ?.map { it.name.orEmpty() }
                            ?.sorted()
                            .orEmpty()
            val services =
                    info.services
                            ?.filter { it.exported }
                            ?.map { it.name.orEmpty() }
                            ?.sorted()
                            .orEmpty()
            val receivers =
                    info.receivers
                            ?.filter { it.exported }
                            ?.map { it.name.orEmpty() }
                            ?.sorted()
                            .orEmpty()
            val providers =
                    info.providers
                            ?.filter { it.exported }
                            ?.map { it.name.orEmpty() }
                            ?.sorted()
                            .orEmpty()
            found.add(
                    mapOf(
                            "package" to pkg,
                            "version_name" to (info.versionName ?: ""),
                            "version_code" to
                                    (if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else
                                            @Suppress("DEPRECATION") info.versionCode.toLong()),
                            "exported_activity_count" to activities.size,
                            "exported_service_count" to services.size,
                            "exported_receiver_count" to receivers.size,
                            "exported_provider_count" to providers.size,
                            "exported_activities" to activities.take(30),
                            "exported_services" to services.take(30),
                            "exported_receivers" to receivers.take(30),
                    )
            )
        }
        return mapOf(
                "candidate_count" to candidates.size,
                "found_count" to found.size,
                "packages" to found,
        )
    }

    private fun scannerIntentProbe(): List<Map<String, Any?>> {
        val actions =
                listOf(
                        "com.symbol.datawedge.datawedge_scanner_input",
                        "com.honeywell.aidc.action.BARCODE_DATA",
                        "com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED",
                        "nlscan.action.SCANNER_RESULT",
                        "com.datalogic.decodewedge.decode_action",
                        "scan.rcv.message",
                        "android.intent.ACTION_DECODE_DATA",
                        "com.leshun.scanner.SCAN",
                        "com.leshun.scan.RESULT",
                )
        return actions.map { action ->
            val intent = Intent(action)
            val receiverCount =
                    try {
                        if (Build.VERSION.SDK_INT >= 33) {
                            packageManager
                                    .queryBroadcastReceivers(
                                            intent,
                                            android.content.pm.PackageManager.ResolveInfoFlags.of(0)
                                    )
                                    .size
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.queryBroadcastReceivers(intent, 0).size
                        }
                    } catch (_: Exception) {
                        0
                    }
            val activityCount =
                    try {
                        if (Build.VERSION.SDK_INT >= 33) {
                            packageManager
                                    .queryIntentActivities(
                                            intent,
                                            android.content.pm.PackageManager.ResolveInfoFlags.of(0)
                                    )
                                    .size
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.queryIntentActivities(intent, 0).size
                        }
                    } catch (_: Exception) {
                        0
                    }
            mapOf(
                    "action" to action,
                    "resolvable_broadcast_receivers" to receiverCount,
                    "resolvable_activities" to activityCount,
            )
        }
    }

    private fun usbModuleReadiness(
            usbManager: UsbManager?,
            devices: List<android.hardware.usb.UsbDevice>,
    ): Map<String, Any?> {
        if (usbManager == null) {
            return mapOf(
                    "available" to false,
                    "error" to "usb manager unavailable",
                    "devices" to emptyList<Map<String, Any?>>(),
            )
        }
        val details =
                devices.map { device ->
                    val interfaces =
                            (0 until device.interfaceCount).map { i ->
                                val intf = device.getInterface(i)
                                val endpoints =
                                        (0 until intf.endpointCount).map { j ->
                                            val ep = intf.getEndpoint(j)
                                            mapOf(
                                                    "address" to ep.address,
                                                    "number" to ep.endpointNumber,
                                                    "direction" to
                                                            if (ep.direction ==
                                                                            android.hardware.usb
                                                                                    .UsbConstants
                                                                                    .USB_DIR_IN
                                                            ) {
                                                                "in"
                                                            } else {
                                                                "out"
                                                            },
                                                    "type" to
                                                            when (ep.type) {
                                                                android.hardware.usb.UsbConstants.USB_ENDPOINT_XFER_BULK ->
                                                                        "bulk"
                                                                android.hardware.usb.UsbConstants.USB_ENDPOINT_XFER_INT ->
                                                                        "interrupt"
                                                                android.hardware.usb.UsbConstants.USB_ENDPOINT_XFER_ISOC ->
                                                                        "isochronous"
                                                                android.hardware.usb.UsbConstants.USB_ENDPOINT_XFER_CONTROL ->
                                                                        "control"
                                                                else -> "unknown"
                                                            },
                                                    "max_packet_size" to ep.maxPacketSize,
                                            )
                                        }
                                mapOf(
                                        "id" to intf.id,
                                        "class" to intf.interfaceClass,
                                        "subclass" to intf.interfaceSubclass,
                                        "protocol" to intf.interfaceProtocol,
                                        "endpoint_count" to intf.endpointCount,
                                        "endpoints" to endpoints,
                                )
                            }
                    val name =
                            listOf(
                                            if (Build.VERSION.SDK_INT >= 21) device.manufacturerName
                                            else null,
                                            if (Build.VERSION.SDK_INT >= 21) device.productName else
                                                    null,
                                    )
                                    .joinToString(" ")
                                    .trim()
                                    .lowercase()
                    val isLikelyScannerOrPalm =
                            name.contains("shiyun") ||
                                    name.contains("vein") ||
                                    name.contains("palm") ||
                                    name.contains("scan")
                    mapOf(
                            "device_name" to device.deviceName.orEmpty(),
                            "vendor_id" to device.vendorId,
                            "product_id" to device.productId,
                            "has_permission" to usbManager.hasPermission(device),
                            "is_likely_scanner_or_palm" to isLikelyScannerOrPalm,
                            "interface_count" to device.interfaceCount,
                            "interfaces" to interfaces,
                    )
                }

        val likelyDevices = details.filter { it["is_likely_scanner_or_palm"] == true }
        val grantedLikelyCount =
                likelyDevices.count { it["has_permission"] == true }

        return mapOf(
                "available" to true,
                "error" to "",
                "likely_module_device_count" to likelyDevices.size,
                "likely_module_permission_granted_count" to grantedLikelyCount,
                "devices" to details,
        )
    }

    private fun cameraProbe(): Map<String, Any?> {
        val manager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
        if (manager == null) {
            return mapOf(
                    "available" to false,
                    "error" to "camera manager unavailable",
                    "cameras" to emptyList<Map<String, Any?>>(),
            )
        }
        return try {
            val cameras =
                    manager.cameraIdList.map { id ->
                        val chars = manager.getCameraCharacteristics(id)
                        val facingRaw =
                                chars.get(CameraCharacteristics.LENS_FACING) ?: -1
                        val facing =
                                when (facingRaw) {
                                    CameraCharacteristics.LENS_FACING_FRONT -> "front"
                                    CameraCharacteristics.LENS_FACING_BACK -> "back"
                                    CameraCharacteristics.LENS_FACING_EXTERNAL -> "external"
                                    else -> "unknown"
                                }
                        val levelRaw =
                                chars.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL) ?: -1
                        val level =
                                when (levelRaw) {
                                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY ->
                                            "legacy"
                                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED ->
                                            "limited"
                                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL -> "full"
                                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3 -> "level_3"
                                    CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_EXTERNAL ->
                                            "external"
                                    else -> "unknown"
                                }
                        val capsRaw =
                                chars.get(
                                                CameraCharacteristics
                                                        .REQUEST_AVAILABLE_CAPABILITIES
                                        )
                                        ?: intArrayOf()
                        val caps =
                                capsRaw.map { cap ->
                                    when (cap) {
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_BACKWARD_COMPATIBLE ->
                                                "backward_compatible"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR ->
                                                "manual_sensor"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_MANUAL_POST_PROCESSING ->
                                                "manual_post_processing"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_RAW ->
                                                "raw"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_PRIVATE_REPROCESSING ->
                                                "private_reprocessing"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_READ_SENSOR_SETTINGS ->
                                                "read_sensor_settings"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_BURST_CAPTURE ->
                                                "burst_capture"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_YUV_REPROCESSING ->
                                                "yuv_reprocessing"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_DEPTH_OUTPUT ->
                                                "depth_output"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_CONSTRAINED_HIGH_SPEED_VIDEO ->
                                                "high_speed_video"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_MOTION_TRACKING ->
                                                "motion_tracking"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA ->
                                                "logical_multi_camera"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_MONOCHROME ->
                                                "monochrome"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_SECURE_IMAGE_DATA ->
                                                "secure_image_data"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_SYSTEM_CAMERA ->
                                                "system_camera"
                                        CameraCharacteristics
                                                .REQUEST_AVAILABLE_CAPABILITIES_OFFLINE_PROCESSING ->
                                                "offline_processing"
                                        else -> "cap_$cap"
                                    }
                                }
                        val streamMap =
                                chars.get(
                                        CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP
                                )
                        val outputFormats = streamMap?.outputFormats?.map { it.toString() } ?: emptyList()
                        mapOf(
                                "camera_id" to id,
                                "lens_facing" to facing,
                                "hardware_level" to level,
                                "capabilities" to caps,
                                "output_format_count" to outputFormats.size,
                                "output_formats" to outputFormats.take(20),
                        )
                    }
            mapOf(
                    "available" to cameras.isNotEmpty(),
                    "error" to "",
                    "camera_count" to cameras.size,
                    "cameras" to cameras,
            )
        } catch (e: Exception) {
            mapOf(
                    "available" to false,
                    "error" to (e.javaClass.simpleName + ":" + (e.message ?: "")),
                    "cameras" to emptyList<Map<String, Any?>>(),
            )
        }
    }

    private fun runSerialStartSequenceTest(
            path: String,
            baud: Int,
            waitMs: Long,
    ): Map<String, Any?> {
        val startedAt = System.currentTimeMillis()
        val adapter = SerialPortAdapter()
        val bytesTotal = AtomicInteger(0)
        val framesTotal = AtomicInteger(0)
        val callbackError = AtomicReference<String?>(null)
        val lastPayload = AtomicReference<String?>(null)

        val cb =
                object : HWDataCallBack {
                    override fun onDataReceived(data: ByteArray, len: Int) {
                        if (len <= 0) return
                        val safeLen = len.coerceAtMost(data.size).coerceAtLeast(0)
                        if (safeLen <= 0) return
                        bytesTotal.addAndGet(safeLen)
                        framesTotal.incrementAndGet()
                        val text =
                                try {
                                    String(data, 0, safeLen, Charset.forName("UTF-8")).trim()
                                } catch (_: Exception) {
                                    ""
                                }
                        if (text.isNotEmpty()) {
                            lastPayload.set(text)
                        }
                    }

                    override fun onError(msg: String) {
                        callbackError.set(msg.trim().ifEmpty { "unknown callback error" })
                    }
                }

        var initOk = false
        var startReadOk = false
        var initError = ""
        var startError = ""
        var stopError = ""
        var deInitError = ""

        try {
            try {
                initOk = adapter.init(this@MainActivity, path, baud)
                if (!initOk) {
                    initError = "init returned false"
                }
            } catch (e: Exception) {
                initError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }
            if (!initOk) {
                return mapOf(
                        "path" to path,
                        "baud" to baud,
                        "wait_ms" to waitMs,
                        "init_ok" to false,
                        "init_error" to initError,
                        "start_read_ok" to false,
                        "start_read_error" to "",
                        "bytes_total" to 0,
                        "frames_total" to 0,
                        "last_payload_redacted" to "",
                        "callback_error" to "",
                        "elapsed_ms" to (System.currentTimeMillis() - startedAt),
                )
            }

            try {
                startReadOk = adapter.startRead(cb)
                if (!startReadOk) {
                    startError = "startRead returned false"
                }
            } catch (e: Exception) {
                startError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }

            if (startReadOk) {
                try {
                    Thread.sleep(waitMs.coerceIn(500L, 10000L))
                } catch (_: InterruptedException) {}
            }
        } finally {
            try {
                adapter.stopRead()
            } catch (e: Exception) {
                stopError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }
            try {
                adapter.deInit()
            } catch (e: Exception) {
                deInitError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }
        }

        return mapOf(
                "path" to path,
                "baud" to baud,
                "wait_ms" to waitMs,
                "init_ok" to initOk,
                "init_error" to initError,
                "start_read_ok" to startReadOk,
                "start_read_error" to startError,
                "bytes_total" to bytesTotal.get(),
                "frames_total" to framesTotal.get(),
                "last_payload_redacted" to redactForLog(lastPayload.get()),
                "callback_error" to (callbackError.get() ?: ""),
                "stop_error" to stopError,
                "deinit_error" to deInitError,
                "elapsed_ms" to (System.currentTimeMillis() - startedAt),
        )
    }

    private fun invokeAdapterWrite(
            adapter: SerialPortAdapter,
            bytes: ByteArray,
    ): Map<String, Any?> {
        return try {
            val m =
                    adapter.javaClass.methods.firstOrNull { method ->
                        method.name == "write" &&
                                method.parameterTypes.size == 2 &&
                                method.parameterTypes[0] == ByteArray::class.java &&
                                method.parameterTypes[1] == Int::class.javaPrimitiveType
                    }
            if (m == null) {
                mapOf(
                        "ok" to false,
                        "error" to "write(byte[], int) not found",
                )
            } else {
                val out = m.invoke(adapter, bytes, bytes.size)
                val ok = (out as? Boolean) ?: true
                mapOf(
                        "ok" to ok,
                        "error" to if (ok) "" else "write returned false",
                )
            }
        } catch (e: Exception) {
            mapOf(
                    "ok" to false,
                    "error" to (e.javaClass.simpleName + ":" + (e.message ?: "")),
            )
        }
    }

    private fun runFactoryParityScannerProbe(
            path: String,
            baud: Int,
            waitMs: Long,
    ): Map<String, Any?> {
        val startedAt = System.currentTimeMillis()
        val adapter = SerialPortAdapter()
        val bytesTotal = AtomicInteger(0)
        val framesTotal = AtomicInteger(0)
        val callbackError = AtomicReference<String?>(null)
        val lastPayload = AtomicReference<String?>(null)

        val cb =
                object : HWDataCallBack {
                    override fun onDataReceived(data: ByteArray, len: Int) {
                        if (len <= 0) return
                        val safeLen = len.coerceAtMost(data.size).coerceAtLeast(0)
                        if (safeLen <= 0) return
                        bytesTotal.addAndGet(safeLen)
                        framesTotal.incrementAndGet()
                        val text =
                                try {
                                    String(data, 0, safeLen, Charset.forName("UTF-8")).trim()
                                } catch (_: Exception) {
                                    ""
                                }
                        if (text.isNotEmpty()) {
                            lastPayload.set(text)
                        }
                    }

                    override fun onError(msg: String) {
                        callbackError.set(msg.trim().ifEmpty { "unknown callback error" })
                    }
                }

        var initOk = false
        var startReadOk = false
        var initError = ""
        var startError = ""
        var stopError = ""
        var deInitError = ""
        val writeAttempts = mutableListOf<Map<String, Any?>>()

        try {
            try {
                initOk = adapter.init(this@MainActivity, path, baud)
                if (!initOk) initError = "init returned false"
            } catch (e: Exception) {
                initError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }
            if (!initOk) {
                return mapOf(
                        "path" to path,
                        "baud" to baud,
                        "wait_ms" to waitMs,
                        "init_ok" to false,
                        "init_error" to initError,
                        "start_read_ok" to false,
                        "start_read_error" to "",
                        "write_attempts" to writeAttempts,
                        "bytes_total" to 0,
                        "frames_total" to 0,
                        "last_payload_redacted" to "",
                        "callback_error" to "",
                        "elapsed_ms" to (System.currentTimeMillis() - startedAt),
                )
            }

            try {
                startReadOk = adapter.startRead(cb)
                if (!startReadOk) startError = "startRead returned false"
            } catch (e: Exception) {
                startError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }

            if (startReadOk) {
                val probes =
                        listOf(
                                byteArrayOf('\r'.code.toByte(), '\n'.code.toByte()) to "CRLF",
                                byteArrayOf(0x16) to "SYN(0x16)",
                                "PING\r\n".toByteArray(Charsets.UTF_8) to "PING_ASCII",
                        )
                for ((bytes, label) in probes) {
                    val out = invokeAdapterWrite(adapter, bytes)
                    writeAttempts.add(
                            mapOf(
                                    "label" to label,
                                    "size" to bytes.size,
                                    "ok" to (out["ok"] == true),
                                    "error" to (out["error"]?.toString().orEmpty()),
                            )
                    )
                    try {
                        Thread.sleep(250L)
                    } catch (_: InterruptedException) {}
                }
                try {
                    Thread.sleep(waitMs.coerceIn(500L, 12000L))
                } catch (_: InterruptedException) {}
            }
        } finally {
            try {
                adapter.stopRead()
            } catch (e: Exception) {
                stopError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }
            try {
                adapter.deInit()
            } catch (e: Exception) {
                deInitError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }
        }

        return mapOf(
                "path" to path,
                "baud" to baud,
                "wait_ms" to waitMs,
                "init_ok" to initOk,
                "init_error" to initError,
                "start_read_ok" to startReadOk,
                "start_read_error" to startError,
                "write_attempts" to writeAttempts,
                "bytes_total" to bytesTotal.get(),
                "frames_total" to framesTotal.get(),
                "last_payload_redacted" to redactForLog(lastPayload.get()),
                "callback_error" to (callbackError.get() ?: ""),
                "stop_error" to stopError,
                "deinit_error" to deInitError,
                "elapsed_ms" to (System.currentTimeMillis() - startedAt),
        )
    }

    private fun selectUsbProbeTarget(
            devices: List<UsbDevice>,
            vendorId: Int?,
            productId: Int?,
    ): UsbDevice? {
        if (vendorId != null && productId != null) {
            devices.firstOrNull { it.vendorId == vendorId && it.productId == productId }?.let {
                return it
            }
        }
        return devices.firstOrNull { d ->
            val maker = if (Build.VERSION.SDK_INT >= 21) d.manufacturerName.orEmpty() else ""
            val prod = if (Build.VERSION.SDK_INT >= 21) d.productName.orEmpty() else ""
            val joined = "$maker $prod".lowercase()
            joined.contains("shiyun") ||
                    joined.contains("vein") ||
                    joined.contains("palm") ||
                    joined.contains("scan")
        }
    }

    private fun findBulkEndpoints(intf: UsbInterface): Pair<UsbEndpoint?, UsbEndpoint?> {
        var inEp: UsbEndpoint? = null
        var outEp: UsbEndpoint? = null
        for (i in 0 until intf.endpointCount) {
            val ep = intf.getEndpoint(i)
            if (ep.type != UsbConstants.USB_ENDPOINT_XFER_BULK) continue
            if (ep.direction == UsbConstants.USB_DIR_IN && inEp == null) {
                inEp = ep
            } else if (ep.direction == UsbConstants.USB_DIR_OUT && outEp == null) {
                outEp = ep
            }
        }
        return Pair(inEp, outEp)
    }

    private fun bytesPreview(data: ByteArray, len: Int): Map<String, Any> {
        val safeLen = len.coerceAtMost(data.size).coerceAtLeast(0)
        val trimmed = data.copyOfRange(0, safeLen)
        val ascii =
                try {
                    String(trimmed, Charset.forName("UTF-8")).replace("\r", "\\r").replace(
                            "\n",
                            "\\n"
                    )
                } catch (_: Exception) {
                    ""
                }
        val maxHex = trimmed.take(24)
        val hex = maxHex.joinToString(" ") { b -> String.format("%02X", b) }
        return mapOf(
                "len" to safeLen,
                "ascii_redacted" to redactForLog(ascii),
                "hex_prefix" to hex,
                "base64_prefix" to
                        Base64.encodeToString(trimmed.take(64).toByteArray(), Base64.NO_WRAP),
        )
    }

    private fun runUsbTransportProbe(
            vendorId: Int?,
            productId: Int?,
            readTimeoutMs: Int,
            readAttempts: Int,
    ): Map<String, Any?> {
        val startedAt = System.currentTimeMillis()
        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
        if (usbManager == null) {
            return mapOf(
                    "available" to false,
                    "error" to "usb manager unavailable",
                    "elapsed_ms" to (System.currentTimeMillis() - startedAt),
            )
        }
        val devices = usbManager.deviceList.values.toList()
        val selected = selectUsbProbeTarget(devices, vendorId, productId)
        val candidates =
                devices.map { d ->
                    mapOf(
                            "device_name" to d.deviceName.orEmpty(),
                            "vendor_id" to d.vendorId,
                            "product_id" to d.productId,
                            "has_permission" to usbManager.hasPermission(d),
                    )
                }
        if (selected == null) {
            return mapOf(
                    "available" to true,
                    "error" to "no usb target matched",
                    "candidate_count" to devices.size,
                    "candidates" to candidates,
                    "elapsed_ms" to (System.currentTimeMillis() - startedAt),
            )
        }
        val hasPermission = usbManager.hasPermission(selected)
        if (!hasPermission) {
            return mapOf(
                    "available" to true,
                    "error" to "permission denied for selected usb device",
                    "selected_device" to
                            mapOf(
                                    "device_name" to selected.deviceName.orEmpty(),
                                    "vendor_id" to selected.vendorId,
                                    "product_id" to selected.productId,
                            ),
                    "candidates" to candidates,
                    "elapsed_ms" to (System.currentTimeMillis() - startedAt),
            )
        }
        val connection = usbManager.openDevice(selected)
        if (connection == null) {
            return mapOf(
                    "available" to true,
                    "error" to "openDevice returned null",
                    "selected_device" to
                            mapOf(
                                    "device_name" to selected.deviceName.orEmpty(),
                                    "vendor_id" to selected.vendorId,
                                    "product_id" to selected.productId,
                            ),
                    "candidates" to candidates,
                    "elapsed_ms" to (System.currentTimeMillis() - startedAt),
            )
        }

        var claimOk = false
        var selectedInterfaceIndex = -1
        var selectedInterfaceClass = -1
        var selectedInterfaceSubclass = -1
        var selectedInterfaceProtocol = -1
        var inEndpoint: UsbEndpoint? = null
        var outEndpoint: UsbEndpoint? = null
        val writeAttempts = mutableListOf<Map<String, Any?>>()
        val readResults = mutableListOf<Map<String, Any?>>()
        var totalReadBytes = 0
        var closeError = ""
        var releaseError = ""

        try {
            for (i in 0 until selected.interfaceCount) {
                val intf = selected.getInterface(i)
                val (inEp, outEp) = findBulkEndpoints(intf)
                if (inEp == null && outEp == null) continue
                val ok = connection.claimInterface(intf, true)
                if (!ok) continue
                claimOk = true
                selectedInterfaceIndex = i
                selectedInterfaceClass = intf.interfaceClass
                selectedInterfaceSubclass = intf.interfaceSubclass
                selectedInterfaceProtocol = intf.interfaceProtocol
                inEndpoint = inEp
                outEndpoint = outEp
                break
            }
            if (!claimOk) {
                return mapOf(
                        "available" to true,
                        "error" to "could not claim any bulk usb interface",
                        "selected_device" to
                                mapOf(
                                        "device_name" to selected.deviceName.orEmpty(),
                                        "vendor_id" to selected.vendorId,
                                        "product_id" to selected.productId,
                                        "interface_count" to selected.interfaceCount,
                                ),
                        "candidates" to candidates,
                        "elapsed_ms" to (System.currentTimeMillis() - startedAt),
                )
            }

            if (outEndpoint != null) {
                val payloads =
                        listOf(
                                "PING\r\n".toByteArray(Charsets.UTF_8) to "PING_ASCII",
                                byteArrayOf(0x16) to "SYN(0x16)",
                        )
                for ((bytes, label) in payloads) {
                    val wrote =
                            connection.bulkTransfer(
                                    outEndpoint,
                                    bytes,
                                    bytes.size,
                                    readTimeoutMs.coerceIn(200, 5000),
                            )
                    writeAttempts.add(
                            mapOf(
                                    "label" to label,
                                    "attempted_size" to bytes.size,
                                    "written_size" to wrote,
                                    "ok" to (wrote >= 0),
                            )
                    )
                    try {
                        Thread.sleep(150L)
                    } catch (_: InterruptedException) {}
                }
            }

            if (inEndpoint != null) {
                val loops = readAttempts.coerceIn(1, 6)
                repeat(loops) { idx ->
                    val buff = ByteArray(512)
                    val read =
                            connection.bulkTransfer(
                                    inEndpoint,
                                    buff,
                                    buff.size,
                                    readTimeoutMs.coerceIn(200, 5000),
                            )
                    if (read > 0) {
                        totalReadBytes += read
                        val preview = bytesPreview(buff, read)
                        readResults.add(
                                mapOf(
                                        "attempt" to (idx + 1),
                                        "ok" to true,
                                        "len" to read,
                                        "ascii_redacted" to preview["ascii_redacted"],
                                        "hex_prefix" to preview["hex_prefix"],
                                        "base64_prefix" to preview["base64_prefix"],
                                )
                        )
                    } else {
                        readResults.add(
                                mapOf(
                                        "attempt" to (idx + 1),
                                        "ok" to false,
                                        "len" to read,
                                )
                        )
                    }
                }
            }
        } finally {
            try {
                if (claimOk && selectedInterfaceIndex >= 0) {
                    connection.releaseInterface(selected.getInterface(selectedInterfaceIndex))
                }
            } catch (e: Exception) {
                releaseError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }
            try {
                connection.close()
            } catch (e: Exception) {
                closeError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }
        }

        return mapOf(
                "available" to true,
                "error" to "",
                "selected_device" to
                        mapOf(
                                "device_name" to selected.deviceName.orEmpty(),
                                "vendor_id" to selected.vendorId,
                                "product_id" to selected.productId,
                                "interface_count" to selected.interfaceCount,
                        ),
                "selected_interface" to
                        mapOf(
                                "index" to selectedInterfaceIndex,
                                "class" to selectedInterfaceClass,
                                "subclass" to selectedInterfaceSubclass,
                                "protocol" to selectedInterfaceProtocol,
                        ),
                "claimed" to claimOk,
                "has_in_endpoint" to (inEndpoint != null),
                "has_out_endpoint" to (outEndpoint != null),
                "write_attempts" to writeAttempts,
                "read_attempts" to readResults,
                "total_read_bytes" to totalReadBytes,
                "release_error" to releaseError,
                "close_error" to closeError,
                "candidates" to candidates,
                "elapsed_ms" to (System.currentTimeMillis() - startedAt),
        )
    }

    private fun runUsbSniffProbe(
            vendorId: Int?,
            productId: Int?,
            durationMs: Int,
            readTimeoutMs: Int,
            triggerSweep: Boolean,
    ): Map<String, Any?> {
        val startedAt = System.currentTimeMillis()
        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
        if (usbManager == null) {
            return mapOf(
                    "available" to false,
                    "error" to "usb manager unavailable",
                    "elapsed_ms" to (System.currentTimeMillis() - startedAt),
            )
        }
        val devices = usbManager.deviceList.values.toList()
        val selected = selectUsbProbeTarget(devices, vendorId, productId)
        val candidates =
                devices.map { d ->
                    mapOf(
                            "device_name" to d.deviceName.orEmpty(),
                            "vendor_id" to d.vendorId,
                            "product_id" to d.productId,
                            "has_permission" to usbManager.hasPermission(d),
                    )
                }
        if (selected == null) {
            return mapOf(
                    "available" to true,
                    "error" to "no usb target matched",
                    "candidate_count" to devices.size,
                    "candidates" to candidates,
                    "elapsed_ms" to (System.currentTimeMillis() - startedAt),
            )
        }
        if (!usbManager.hasPermission(selected)) {
            return mapOf(
                    "available" to true,
                    "error" to "permission denied for selected usb device",
                    "selected_device" to
                            mapOf(
                                    "device_name" to selected.deviceName.orEmpty(),
                                    "vendor_id" to selected.vendorId,
                                    "product_id" to selected.productId,
                            ),
                    "candidates" to candidates,
                    "elapsed_ms" to (System.currentTimeMillis() - startedAt),
            )
        }
        val connection = usbManager.openDevice(selected)
        if (connection == null) {
            return mapOf(
                    "available" to true,
                    "error" to "openDevice returned null",
                    "selected_device" to
                            mapOf(
                                    "device_name" to selected.deviceName.orEmpty(),
                                    "vendor_id" to selected.vendorId,
                                    "product_id" to selected.productId,
                            ),
                    "candidates" to candidates,
                    "elapsed_ms" to (System.currentTimeMillis() - startedAt),
            )
        }

        var claimOk = false
        var selectedInterfaceIndex = -1
        var selectedInterfaceClass = -1
        var selectedInterfaceSubclass = -1
        var selectedInterfaceProtocol = -1
        var inEndpoint: UsbEndpoint? = null
        var outEndpoint: UsbEndpoint? = null
        val writeAttempts = mutableListOf<Map<String, Any?>>()
        val packetSamples = mutableListOf<Map<String, Any?>>()
        var readLoops = 0
        var readHits = 0
        var totalReadBytes = 0
        var firstDataAtMs = -1L
        var lastDataAtMs = -1L
        var releaseError = ""
        var closeError = ""

        try {
            for (i in 0 until selected.interfaceCount) {
                val intf = selected.getInterface(i)
                val (inEp, outEp) = findBulkEndpoints(intf)
                if (inEp == null && outEp == null) continue
                val ok = connection.claimInterface(intf, true)
                if (!ok) continue
                claimOk = true
                selectedInterfaceIndex = i
                selectedInterfaceClass = intf.interfaceClass
                selectedInterfaceSubclass = intf.interfaceSubclass
                selectedInterfaceProtocol = intf.interfaceProtocol
                inEndpoint = inEp
                outEndpoint = outEp
                break
            }
            if (!claimOk) {
                return mapOf(
                        "available" to true,
                        "error" to "could not claim any bulk usb interface",
                        "selected_device" to
                                mapOf(
                                        "device_name" to selected.deviceName.orEmpty(),
                                        "vendor_id" to selected.vendorId,
                                        "product_id" to selected.productId,
                                        "interface_count" to selected.interfaceCount,
                                ),
                        "candidates" to candidates,
                        "elapsed_ms" to (System.currentTimeMillis() - startedAt),
                )
            }

            if (triggerSweep && outEndpoint != null) {
                val triggers =
                        listOf(
                                "PING\r\n".toByteArray(Charsets.UTF_8) to "PING_ASCII",
                                byteArrayOf(0x16) to "SYN(0x16)",
                                byteArrayOf(0x05) to "ENQ(0x05)",
                                byteArrayOf(0x02, 0x54, 0x0D) to "STX-T-CR",
                                byteArrayOf(0x7E, 0x00, 0x00, 0x7E) to "FRAME_7E",
                        )
                for ((bytes, label) in triggers) {
                    val wrote =
                            connection.bulkTransfer(
                                    outEndpoint,
                                    bytes,
                                    bytes.size,
                                    readTimeoutMs.coerceIn(100, 3000),
                            )
                    writeAttempts.add(
                            mapOf(
                                    "label" to label,
                                    "attempted_size" to bytes.size,
                                    "written_size" to wrote,
                                    "ok" to (wrote >= 0),
                            )
                    )
                    try {
                        Thread.sleep(120L)
                    } catch (_: InterruptedException) {}
                }
            }

            if (inEndpoint != null) {
                val runForMs = durationMs.coerceIn(3000, 30000).toLong()
                val deadline = SystemClock.elapsedRealtime() + runForMs
                while (SystemClock.elapsedRealtime() < deadline) {
                    readLoops++
                    val buffer = ByteArray(512)
                    val read =
                            connection.bulkTransfer(
                                    inEndpoint,
                                    buffer,
                                    buffer.size,
                                    readTimeoutMs.coerceIn(100, 5000),
                            )
                    if (read > 0) {
                        val now = SystemClock.elapsedRealtime()
                        if (firstDataAtMs < 0) firstDataAtMs = now
                        lastDataAtMs = now
                        readHits++
                        totalReadBytes += read
                        if (packetSamples.size < 24) {
                            val preview = bytesPreview(buffer, read)
                            packetSamples.add(
                                    mapOf(
                                            "index" to readHits,
                                            "len" to read,
                                            "ascii_redacted" to preview["ascii_redacted"],
                                            "hex_prefix" to preview["hex_prefix"],
                                            "base64_prefix" to preview["base64_prefix"],
                                    )
                            )
                        }
                    }
                }
            }
        } finally {
            try {
                if (claimOk && selectedInterfaceIndex >= 0) {
                    connection.releaseInterface(selected.getInterface(selectedInterfaceIndex))
                }
            } catch (e: Exception) {
                releaseError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }
            try {
                connection.close()
            } catch (e: Exception) {
                closeError = e.javaClass.simpleName + ":" + (e.message ?: "")
            }
        }

        return mapOf(
                "available" to true,
                "error" to "",
                "selected_device" to
                        mapOf(
                                "device_name" to selected.deviceName.orEmpty(),
                                "vendor_id" to selected.vendorId,
                                "product_id" to selected.productId,
                                "interface_count" to selected.interfaceCount,
                        ),
                "selected_interface" to
                        mapOf(
                                "index" to selectedInterfaceIndex,
                                "class" to selectedInterfaceClass,
                                "subclass" to selectedInterfaceSubclass,
                                "protocol" to selectedInterfaceProtocol,
                        ),
                "claimed" to claimOk,
                "trigger_sweep" to triggerSweep,
                "has_in_endpoint" to (inEndpoint != null),
                "has_out_endpoint" to (outEndpoint != null),
                "write_attempts" to writeAttempts,
                "sniff_duration_ms" to durationMs.coerceIn(3000, 30000),
                "read_timeout_ms" to readTimeoutMs.coerceIn(100, 5000),
                "read_loops" to readLoops,
                "read_hits" to readHits,
                "total_read_bytes" to totalReadBytes,
                "first_data_elapsed_ms" to firstDataAtMs,
                "last_data_elapsed_ms" to lastDataAtMs,
                "packet_samples" to packetSamples,
                "release_error" to releaseError,
                "close_error" to closeError,
                "candidates" to candidates,
                "elapsed_ms" to (System.currentTimeMillis() - startedAt),
        )
    }

    private fun serialDriverMetadata(
            serialCandidates: List<Map<String, Any>>,
    ): List<Map<String, Any?>> {
        return serialCandidates.map { port ->
            val path = port["path"]?.toString().orEmpty()
            val name = path.substringAfterLast("/", "")
            val sysPath = File("/sys/class/tty/$name")
            val linkTarget =
                    try {
                        sysPath.canonicalPath
                    } catch (_: Exception) {
                        ""
                    }
            mapOf(
                    "path" to path,
                    "sysfs_exists" to sysPath.exists(),
                    "sysfs_target" to linkTarget,
            )
        }
    }

    private fun linuxInputNodes(): List<Map<String, Any?>> {
        val file = File("/proc/bus/input/devices")
        if (!file.exists() || !file.canRead()) return emptyList()
        val text =
                try {
                    file.readText()
                } catch (_: Exception) {
                    return emptyList()
                }
        val blocks = text.split("\n\n")
        return blocks.mapNotNull { block ->
            val lines = block.lines().map { it.trim() }.filter { it.isNotEmpty() }
            if (lines.isEmpty()) return@mapNotNull null
            var name = ""
            var handlers = ""
            var phys = ""
            var uniq = ""
            var bus = ""
            var vendor = ""
            var product = ""
            var version = ""
            for (line in lines) {
                when {
                    line.startsWith("N:") -> {
                        val start = line.indexOf("\"")
                        val end = line.lastIndexOf("\"")
                        if (start >= 0 && end > start) {
                            name = line.substring(start + 1, end).trim()
                        }
                    }
                    line.startsWith("H:") -> handlers = line.removePrefix("H:").trim()
                    line.startsWith("P:") -> phys = line.removePrefix("P:").trim()
                    line.startsWith("U:") -> uniq = line.removePrefix("U:").trim()
                    line.startsWith("I:") -> {
                        val tokens = line.removePrefix("I:").trim().split(" ")
                        for (token in tokens) {
                            when {
                                token.startsWith("Bus=") -> bus = token.removePrefix("Bus=")
                                token.startsWith("Vendor=") ->
                                        vendor = token.removePrefix("Vendor=")
                                token.startsWith("Product=") ->
                                        product = token.removePrefix("Product=")
                                token.startsWith("Version=") ->
                                        version = token.removePrefix("Version=")
                            }
                        }
                    }
                }
            }
            if (!handlers.contains("event")) return@mapNotNull null
            val eventNodes =
                    handlers
                            .split(" ")
                            .map { it.trim() }
                            .filter { it.startsWith("event") }
                            .map { "/dev/input/$it" }
                            .distinct()
            if (eventNodes.isEmpty()) return@mapNotNull null
            mapOf(
                    "name" to name,
                    "handlers" to handlers,
                    "event_nodes" to eventNodes,
                    "phys" to phys,
                    "uniq" to uniq,
                    "bus_hex" to bus,
                    "vendor_hex" to vendor,
                    "product_hex" to product,
                    "version_hex" to version,
            )
        }
    }

    private fun qrInputEventCandidates(
            qrInputCandidates: List<Map<String, Any?>>,
            linuxInputNodes: List<Map<String, Any?>>,
    ): List<Map<String, Any?>> {
        return qrInputCandidates.map { q ->
            val qName = q["name"]?.toString()?.trim().orEmpty()
            val qNameLower = qName.lowercase()
            val matched =
                    linuxInputNodes.filter { node ->
                        val n = node["name"]?.toString()?.trim().orEmpty().lowercase()
                        n.isNotEmpty() &&
                                (n == qNameLower ||
                                        n.contains(qNameLower) ||
                                        qNameLower.contains(n))
                    }
            mapOf(
                    "input_device_id" to q["id"],
                    "name" to q["name"],
                    "vendor_id" to q["vendor_id"],
                    "product_id" to q["product_id"],
                    "descriptor" to q["descriptor"],
                    "matched_linux_nodes" to matched,
            )
        }
    }

    private fun probeQrSerialAdapter(
            serialCandidates: List<Map<String, Any>>,
    ): List<Map<String, Any?>> {
        val bauds = listOf(9600, 115200)
        val readablePorts =
                serialCandidates
                        .filter { it["can_read"] == true }
                        .mapNotNull { it["path"]?.toString() }
                        .filter { it.isNotBlank() }
        return readablePorts.map { path ->
            val baudResults =
                    bauds.map { baud ->
                        val adapter = SerialPortAdapter()
                        var ok = false
                        var error = ""
                        try {
                            ok = adapter.init(this@MainActivity, path, baud)
                            if (!ok) error = "init returned false"
                        } catch (e: Exception) {
                            error = e.message.orEmpty()
                        } finally {
                            try {
                                adapter.deInit()
                            } catch (_: Exception) {}
                        }
                        mapOf(
                                "baud" to baud,
                                "adapter_init_ok" to ok,
                                "error" to error,
                        )
                    }
            mapOf(
                    "path" to path,
                    "probe_results" to baudResults,
            )
        }
    }

    private fun listHidInputDevices(): List<Map<String, Any?>> {
        val ids =
                try {
                    InputDevice.getDeviceIds()
                } catch (_: Exception) {
                    IntArray(0)
                }
        return ids.asList().mapNotNull { id ->
            val dev =
                    try {
                        InputDevice.getDevice(id)
                    } catch (_: Exception) {
                        null
                    } ?: return@mapNotNull null
            val sources = dev.sources
            val keyboard = (sources and InputDevice.SOURCE_KEYBOARD) == InputDevice.SOURCE_KEYBOARD
            val dpad = (sources and InputDevice.SOURCE_DPAD) == InputDevice.SOURCE_DPAD
            val external = !dev.isVirtual
            val vendorId =
                    try {
                        dev.vendorId
                    } catch (_: Exception) {
                        -1
                    }
            val productId =
                    try {
                        dev.productId
                    } catch (_: Exception) {
                        -1
                    }
            mapOf(
                    "id" to id,
                    "name" to dev.name.orEmpty(),
                    "descriptor" to dev.descriptor.orEmpty(),
                    "vendor_id" to vendorId,
                    "product_id" to productId,
                    "sources" to sources,
                    "is_virtual" to dev.isVirtual,
                    "is_external" to external,
                    "has_keyboard_source" to keyboard,
                    "has_dpad_source" to dpad,
            )
        }
    }

    private fun qrInputDeviceCandidates(
            hidDevices: List<Map<String, Any?>>,
    ): List<Map<String, Any?>> {
        return hidDevices
                .filter { d ->
                    d["is_external"] == true &&
                            d["has_keyboard_source"] == true &&
                            d["is_virtual"] == false
                }
                .map { d ->
                    mapOf(
                            "id" to d["id"],
                            "name" to d["name"],
                            "vendor_id" to d["vendor_id"],
                            "product_id" to d["product_id"],
                            "descriptor" to d["descriptor"],
                    )
                }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= 33) {
                packageManager.getPackageInfo(
                        packageName,
                        android.content.pm.PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION") packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun scannerBroadcastPackagesStatus(): List<Map<String, Any>> {
        val packageCandidates =
                listOf(
                        "com.symbol.datawedge",
                        "com.honeywell.aidc",
                        "com.sunmi.scanner",
                        "com.nlscan.android.scanservice",
                        "com.datalogic.decodewedge",
                )
        return packageCandidates.map { pkg ->
            mapOf(
                    "package" to pkg,
                    "installed" to isPackageInstalled(pkg),
            )
        }
    }

    private fun buildIntegrationHints(
            serialProbe: List<Map<String, Any?>>,
            hidDevices: List<Map<String, Any?>>,
            qrInputCandidates: List<Map<String, Any?>>,
            broadcastPackages: List<Map<String, Any>>,
    ): List<String> {
        val serialSuccess =
                serialProbe.firstNotNullOfOrNull { port ->
                    val path = port["path"]?.toString().orEmpty()
                    val probeResults = port["probe_results"] as? List<*> ?: return@firstNotNullOfOrNull null
                    val okEntry =
                            probeResults.firstOrNull { r ->
                                (r as? Map<*, *>)?.get("adapter_init_ok") == true
                            } as? Map<*, *>
                    if (okEntry != null) {
                        "QR serial mode is available: path=$path baud=${okEntry["baud"]}."
                    } else {
                        null
                    }
                }
        val hidLikely =
                hidDevices.any { d ->
                    d["has_keyboard_source"] == true &&
                            d["is_external"] == true &&
                            d["name"]?.toString()?.trim()?.isNotEmpty() == true
                }
        val qrInputCount = qrInputCandidates.size
        val broadcastInstalled = broadcastPackages.any { it["installed"] == true }
        val hints = mutableListOf<String>()
        if (serialSuccess != null) {
            hints.add(serialSuccess)
            hints.add("Use serial QR integration first; scanner likely outputs to tty port.")
        } else if (hidLikely) {
            hints.add("No serial adapter init success; HID keyboard scanner input is likely.")
            hints.add("Use focused hidden text input to capture scanner keystrokes (external keyboard candidates=$qrInputCount).")
        } else if (broadcastInstalled) {
            hints.add("No serial/HID signal confirmed; broadcast scanner service package detected.")
            hints.add("Configure scanner app to broadcast decode results to app-supported actions.")
        } else {
            hints.add("QR integration signal not confirmed from hardware probe.")
            hints.add("Verify scanner mode on device settings (Serial or HID or Broadcast).")
        }

        return hints
    }

    private fun startQrReaderIfNeeded() {
        synchronized(qrLock) {
            if (qrReaderRunning.get()) return
            qrReaderRunning.set(true)

            qrReaderStartElapsedMs.set(SystemClock.elapsedRealtime())
            qrReaderBytesTotal.set(0L)
            qrReaderFramesTotal.set(0L)
            qrReaderLastByteElapsedMs.set(0L)
            qrReaderLastTerminatorElapsedMs.set(0L)
            qrReaderLastLogElapsedMs.set(0L)
            qrSerialFrameSamplesLogged.set(0)
            synchronized(qrSerialBufferLock) {
                qrSerialFrameBuffer.reset()
                qrSerialFrameSource = "serial"
                qrSerialFrameMeta = emptyMap()
            }
            qrSerialFinalizeRunnable?.let { qrSerialFinalizeHandler.removeCallbacks(it) }

            qrReaderThread =
                    Thread {
                        val devicePath = synchronized(qrLock) { qrDevicePath }
                        val bitrate = 9600
                        qrSerialDriver = "raw"

                        try {
                            val adapter = SerialPortAdapter()
                            var initError: String? = null
                            val initOk =
                                    try {
                                        adapter.init(this@MainActivity, devicePath, bitrate)
                                    } catch (e: Exception) {
                                        initError = e.message
                                        false
                                    }
                            if (initOk) {
                                qrSerialAdapter = adapter
                                qrSerialDriver = "adapter"
                                qrSerialAdapterLastInitError = null
                                qrSerialAdapterLastInitAtMs.set(System.currentTimeMillis())
                                logD(
                                        "qrScanner/reader start adapter path=$devicePath bitrate=$bitrate"
                                )

                                val cb =
                                        object : HWDataCallBack {
                                            override fun onDataReceived(data: ByteArray, len: Int) {
                                                if (!qrReaderRunning.get()) return
                                                if (len <= 0) return

                                                val safeLen =
                                                        len.coerceAtMost(data.size).coerceAtLeast(0)
                                                if (safeLen <= 0) return
                                                qrReaderBytesTotal.addAndGet(safeLen.toLong())
                                                maybeLogQrBytes(safeLen, data, 0)
                                                processSerialChunk(
                                                        data = data,
                                                        len = safeLen,
                                                        source = "serial",
                                                        meta =
                                                                mapOf(
                                                                        "device_path" to
                                                                                devicePath,
                                                                        "driver" to "adapter",
                                                                        "bitrate" to bitrate,
                                                                ),
                                                )
                                            }

                                            override fun onError(msg: String) {
                                                if (!qrReaderRunning.get()) return
                                                emitQrError(
                                                        "QR_ADAPTER_ERROR",
                                                        msg.trim().ifEmpty { null }
                                                )
                                            }
                                        }

                                qrSerialAdapterCallback = cb
                                val startOk =
                                        try {
                                            adapter.startRead(cb)
                                        } catch (_: Exception) {
                                            false
                                        }
                                if (!startOk) {
                                    qrSerialAdapterCallback = null
                                    try {
                                        adapter.deInit()
                                    } catch (_: Exception) {}
                                    qrSerialAdapter = null
                                    qrSerialDriver = "raw"
                                    qrReaderRunning.set(false)
                                    emitQrError(
                                            "QR_ADAPTER_START_FAILED",
                                            "startRead returned false"
                                    )
                                }
                                return@Thread
                            }
                            qrSerialAdapterLastInitError =
                                    (initError?.trim().orEmpty().ifEmpty { "init returned false" })
                            qrSerialAdapterLastInitAtMs.set(System.currentTimeMillis())
                        } catch (_: Exception) {}

                        logD("qrScanner/reader start raw (${qrDeviceSnapshot()})")
                        val input =
                                try {
                                    FileInputStream(devicePath)
                                } catch (e: Exception) {
                                    emitQrError("QR_OPEN_FAILED", e.message)
                                    qrReaderRunning.set(false)
                                    return@Thread
                                }

                        qrInputStream = input
                        logD("qrScanner/reader opened ok raw (${qrDeviceSnapshot()})")

                        val buffer = ByteArray(256)

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
                                processSerialChunk(
                                        data = buffer,
                                        len = read,
                                        source = "serial",
                                        meta =
                                                mapOf(
                                                        "device_path" to devicePath,
                                                        "driver" to "raw",
                                                        "bitrate" to bitrate,
                                                ),
                                )
                            }
                        } finally {
                            finalizeSerialFrame("reader_stop")
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
            val adapter = qrSerialAdapter
            qrSerialAdapter = null
            qrSerialAdapterCallback = null
            if (adapter != null) {
                try {
                    adapter.stopRead()
                } catch (_: Exception) {}
                try {
                    adapter.deInit()
                } catch (_: Exception) {}
            }
            try {
                qrInputStream?.close()
            } catch (_: Exception) {}
            qrInputStream = null
            qrReaderThread = null
            qrSerialFinalizeRunnable?.let { qrSerialFinalizeHandler.removeCallbacks(it) }
            synchronized(qrSerialBufferLock) { qrSerialFrameBuffer.reset() }
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
        val lastAdapterInitAt = qrSerialAdapterLastInitAtMs.get()
        val adapterInitAgeMs = if (lastAdapterInitAt <= 0L) -1L else (now - lastAdapterInitAt)
        val systemHwJar = File("/system/framework/com.leshun.hwdevice.jar")
        val sdcardHwJar = File("/sdcard/com.leshun.hwdevice.jar")
        val hidLen = synchronized(hidBuffer) { hidBuffer.length }

        return mapOf(
                "uptime_ms" to SystemClock.elapsedRealtime(),
                "qr_device_path" to path,
                "qr_device_exists" to file.exists(),
                "qr_device_can_read" to file.canRead(),
                "qr_device_can_write" to file.canWrite(),
                "qr_reader_running" to qrReaderRunning.get(),
                "qr_serial_driver" to qrSerialDriver,
                "qr_serial_adapter_active" to (qrSerialAdapter != null),
                "qr_serial_expected_bitrate" to 9600,
                "qr_serial_adapter_last_init_error" to (qrSerialAdapterLastInitError ?: ""),
                "qr_serial_adapter_last_init_age_ms" to adapterInitAgeMs,
                "hwdevice_jar_system_exists" to systemHwJar.exists(),
                "hwdevice_jar_sdcard_exists" to sdcardHwJar.exists(),
                "qr_reader_bytes_total" to qrReaderBytesTotal.get(),
                "qr_serial_frames_total" to qrReaderFramesTotal.get(),
                "qr_broadcast_frames_total" to qrBroadcastFramesTotal.get(),
                "qr_hid_frames_total" to qrHidFramesTotal.get(),
                "qr_last_payload_redacted" to redactForLog(lastQrPayload),
                "qr_last_scan_age_ms" to ageMs,
                "qr_last_byte_age_ms" to
                        if (qrReaderLastByteElapsedMs.get() <= 0L) -1L
                        else SystemClock.elapsedRealtime() - qrReaderLastByteElapsedMs.get(),
                "qr_last_terminator_age_ms" to
                        if (qrReaderLastTerminatorElapsedMs.get() <= 0L) -1L
                        else SystemClock.elapsedRealtime() - qrReaderLastTerminatorElapsedMs.get(),
                "hid_last_key_age_ms" to
                        if (hidLastKeyElapsedMs.get() <= 0L) -1L
                        else SystemClock.elapsedRealtime() - hidLastKeyElapsedMs.get(),
                "hid_buffer_len" to hidLen,
                "hid_finalize_pending" to (hidFinalizeRunnable != null),
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
        } else if (source == "hid") {
            qrHidFramesTotal.incrementAndGet()
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

}
