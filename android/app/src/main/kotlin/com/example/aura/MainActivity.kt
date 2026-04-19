package com.example.aura

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.media.AudioManager
import android.media.MediaRecorder
import android.os.Build
import android.os.PowerManager
import android.content.Context
import android.content.Intent
import android.content.ActivityNotFoundException
import android.net.Uri
import android.util.Log

class MainActivity : FlutterActivity() {
    private val channelName = "com.aura.recording/audio"
    private val pdfChannelName = "com.aura.files/pdf"
    private val createPdfRequestCode = 9201

    private var pendingCreatePdfResult: MethodChannel.Result? = null
    private var mediaRecorder: MediaRecorder? = null
    private var recordingPath: String? = null
    private var isRecording = false
    private var isPaused = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioFocusRequest: Any? = null // AudioFocusRequest on API 26+

    companion object {
        private const val TAG = "AuraRecording"
        // ── Audio quality constants ──────────────────────────────────────
        // 44.1 kHz is universally supported and sufficient for speech.
        // 48 kHz is technically "better" but causes resampling on some
        // OEM HALs, introducing artifacts. 44.1 kHz avoids this.
        private const val SAMPLE_RATE = 44100
        // 128 kbps AAC is transparent quality for mono speech.
        // Lower rates save space but introduce audible compression.
        private const val BIT_RATE = 128_000
        // Mono is preferred: speech is inherently mono-source,
        // stereo doubles file size with no perceptual benefit.
        private const val CHANNELS = 1
    }

    // ════════════════════════════════════════════════════════════════════
    //  Platform channel setup
    // ════════════════════════════════════════════════════════════════════

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            startRecording(path, result)
                        } else {
                            result.error("INVALID_ARGS", "Path is required", null)
                        }
                    }
                    "stopRecording" -> {
                        stopRecording(result)
                    }
                    "pauseRecording" -> {
                        pauseRecording(result)
                    }
                    "resumeRecording" -> {
                        resumeRecording(result)
                    }
                    "getDeviceAudioCapabilities" -> {
                        getDeviceAudioCapabilities(result)
                    }
                    "getAmplitude" -> {
                        getAmplitude(result)
                    }
                    "setWakeLock" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setWakeLock(enabled, result)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pdfChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "createPdfDocument" -> {
                        if (pendingCreatePdfResult != null) {
                            result.error(
                                "BUSY",
                                "A document picker is already in progress",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val suggestedName = call.argument<String>("suggestedName")
                            ?: "AURA_Summary.pdf"

                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/pdf"
                            putExtra(Intent.EXTRA_TITLE, suggestedName)
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                            )
                        }

                        pendingCreatePdfResult = result
                        startActivityForResult(intent, createPdfRequestCode)
                    }
                    "writeBytesToUri" -> {
                        val uriString = call.argument<String>("uri")
                        val bytes = call.argument<ByteArray>("bytes")

                        if (uriString == null || bytes == null) {
                            result.error("INVALID_ARGS", "uri and bytes are required", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val uri = Uri.parse(uriString)
                            contentResolver.openOutputStream(uri)?.use { out ->
                                out.write(bytes)
                                out.flush()
                            } ?: run {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to write PDF bytes", e)
                            result.success(false)
                        }
                    }
                    "openPdfUri" -> {
                        val uriString = call.argument<String>("uri")
                        if (uriString == null) {
                            result.error("INVALID_ARGS", "uri is required", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val uri = Uri.parse(uriString)
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/pdf")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(intent, "Open PDF"))
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.error("NO_APP", "No PDF viewer installed", null)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", "Failed to open PDF", null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != createPdfRequestCode) return

        val pending = pendingCreatePdfResult
        pendingCreatePdfResult = null

        if (pending == null) return

        if (resultCode != Activity.RESULT_OK) {
            pending.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            pending.success(null)
            return
        }

        try {
            val flags = (data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))

            contentResolver.takePersistableUriPermission(uri, flags)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to persist URI permission", e)
        }

        pending.success(uri.toString())
    }

    // ════════════════════════════════════════════════════════════════════
    //  Audio source selection
    // ════════════════════════════════════════════════════════════════════

    /**
     * Selects the best available audio source for high-fidelity speech capture.
     *
     * Priority:
     * 1. UNPROCESSED (API 24+, device must advertise support) — raw PCM,
     *    no AGC / NS / AEC applied by the HAL. Best fidelity.
     * 2. VOICE_RECOGNITION — disables AEC & NS on most OEMs while keeping
     *    light gain control. Safe default for speech.
     *
     * MIC (the previous default) applies aggressive OEM-tuned AGC, NS,
     * and AEC that degrade lecture recordings on most Samsung, Xiaomi,
     * and Pixel devices.
     */
    private fun getBestAudioSource(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val supportsUnprocessed = audioManager.getProperty(
                AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED
            )
            if (supportsUnprocessed?.toBoolean() == true) {
                Log.i(TAG, "Audio source: UNPROCESSED")
                return MediaRecorder.AudioSource.UNPROCESSED
            }
        }
        Log.i(TAG, "Audio source: VOICE_RECOGNITION (UNPROCESSED not available)")
        return MediaRecorder.AudioSource.VOICE_RECOGNITION
    }

    // ════════════════════════════════════════════════════════════════════
    //  Audio focus — prevents notification sounds / music from
    //  bleeding into the microphone during a recording session.
    // ════════════════════════════════════════════════════════════════════

    private fun requestAudioFocus(): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = android.media.AudioFocusRequest.Builder(
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
            ).build()
            audioFocusRequest = request
            audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun getAmplitude(result: MethodChannel.Result) {
        if (!isRecording || isPaused || mediaRecorder == null) {
            result.success(0.0)
            return
        }

        try {
            val rawAmplitude = mediaRecorder?.maxAmplitude ?: 0
            val normalized = (rawAmplitude.toDouble() / 32767.0).coerceIn(0.0, 1.0)
            result.success(normalized)
        } catch (e: Exception) {
            Log.e(TAG, "Error reading amplitude", e)
            result.success(0.0)
        }
    }

    private fun abandonAudioFocus() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            (audioFocusRequest as? android.media.AudioFocusRequest)?.let {
                audioManager.abandonAudioFocusRequest(it)
            }
            audioFocusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  Recording lifecycle
    // ════════════════════════════════════════════════════════════════════

    private fun startRecording(path: String, result: MethodChannel.Result) {
        if (isRecording) {
            result.error("ALREADY_RECORDING", "A recording is already in progress", null)
            return
        }

        try {
            if (!requestAudioFocus()) {
                Log.w(TAG, "Audio focus not granted — proceeding anyway")
            }

            recordingPath = path

            // Use context-aware constructor on API 31+ (old one is deprecated)
            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            recorder.apply {
                setAudioSource(getBestAudioSource())
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(SAMPLE_RATE)
                setAudioEncodingBitRate(BIT_RATE)
                setAudioChannels(CHANNELS)
                setOutputFile(path)

                // Async error callback — fires on I/O failures, storage full, etc.
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaRecorder async error: what=$what extra=$extra")
                    safeStopAndRelease()
                }

                setOnInfoListener { _, what, extra ->
                    Log.i(TAG, "MediaRecorder info: what=$what extra=$extra")
                }

                prepare()
                start()
            }

            mediaRecorder = recorder
            isRecording = true
            isPaused = false

            Log.i(TAG, "Recording started: $path " +
                    "(${SAMPLE_RATE}Hz, ${BIT_RATE / 1000}kbps, ${CHANNELS}ch)")

            result.success(mapOf(
                "path" to path,
                "sampleRate" to SAMPLE_RATE,
                "bitRate" to BIT_RATE,
                "channels" to CHANNELS
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording", e)
            safeStopAndRelease()
            result.error("RECORDING_ERROR", e.message, e.stackTraceToString())
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        if (!isRecording || mediaRecorder == null) {
            result.error("NOT_RECORDING", "No active recording to stop", null)
            return
        }

        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            isRecording = false
            isPaused = false
            abandonAudioFocus()

            // Validate output file
            val file = java.io.File(recordingPath ?: "")
            if (file.exists() && file.length() > 0) {
                Log.i(TAG, "Recording saved: $recordingPath (${file.length()} bytes)")
                result.success(recordingPath)
            } else {
                Log.e(TAG, "Output file empty or missing: $recordingPath")
                result.error("FILE_ERROR", "Recording file is empty or missing", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording", e)
            safeStopAndRelease()
            // Return path anyway — partial file may still be usable
            result.success(recordingPath)
        }
    }

    private fun pauseRecording(result: MethodChannel.Result) {
        if (!isRecording || mediaRecorder == null) {
            result.error("NOT_RECORDING", "No active recording to pause", null)
            return
        }

        if (isPaused) {
            result.success(null)
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            result.error("UNSUPPORTED", "Pause is not supported on this Android version", null)
            return
        }

        try {
            mediaRecorder?.pause()
            isPaused = true
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing recording", e)
            result.error("PAUSE_ERROR", e.message, null)
        }
    }

    private fun resumeRecording(result: MethodChannel.Result) {
        if (!isRecording || mediaRecorder == null) {
            result.error("NOT_RECORDING", "No active recording to resume", null)
            return
        }

        if (!isPaused) {
            result.success(null)
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            result.error("UNSUPPORTED", "Resume is not supported on this Android version", null)
            return
        }

        try {
            mediaRecorder?.resume()
            isPaused = false
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Error resuming recording", e)
            result.error("RESUME_ERROR", e.message, null)
        }
    }

    /**
     * Safely releases MediaRecorder, swallowing exceptions.
     * Used in error paths and lifecycle callbacks where throwing is not useful.
     */
    private fun safeStopAndRelease() {
        try { mediaRecorder?.stop() } catch (_: Exception) {}
        try { mediaRecorder?.release() } catch (_: Exception) {}
        mediaRecorder = null
        isRecording = false
        isPaused = false
        abandonAudioFocus()
    }

    // ════════════════════════════════════════════════════════════════════
    //  Device capability detection — callable from Flutter
    // ════════════════════════════════════════════════════════════════════

    private fun getDeviceAudioCapabilities(result: MethodChannel.Result) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val caps = mutableMapOf<String, Any?>()

        caps["nativeSampleRate"] =
            audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)?.toIntOrNull()
        caps["nativeFramesPerBuffer"] =
            audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)?.toIntOrNull()

        caps["supportsUnprocessed"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            audioManager.getProperty(
                AudioManager.PROPERTY_SUPPORT_AUDIO_SOURCE_UNPROCESSED
            )?.toBoolean() ?: false
        } else false

        caps["sdkVersion"] = Build.VERSION.SDK_INT
        caps["manufacturer"] = Build.MANUFACTURER
        caps["model"] = Build.MODEL
        caps["selectedAudioSource"] = getBestAudioSource()
        caps["configuredSampleRate"] = SAMPLE_RATE
        caps["configuredBitRate"] = BIT_RATE
        caps["configuredChannels"] = CHANNELS

        result.success(caps)
    }

    // ════════════════════════════════════════════════════════════════════
    //  Wakelock — keeps CPU active during long recordings when the
    //  screen turns off. Without this, the OS may suspend the process
    //  after ~1 minute in the background.
    // ════════════════════════════════════════════════════════════════════

    private fun setWakeLock(enabled: Boolean, result: MethodChannel.Result) {
        try {
            if (enabled) {
                if (wakeLock == null) {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    wakeLock = pm.newWakeLock(
                        PowerManager.PARTIAL_WAKE_LOCK,
                        "aura:recording_wakelock"
                    )
                }
                // Ceiling of 4 hours prevents leaked wakelocks
                wakeLock?.acquire(4 * 60 * 60 * 1000L)
                Log.i(TAG, "WakeLock acquired")
            } else {
                wakeLock?.let { if (it.isHeld) it.release() }
                wakeLock = null
                Log.i(TAG, "WakeLock released")
            }
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "WakeLock error", e)
            result.error("WAKELOCK_ERROR", e.message, null)
        }
    }

    // ════════════════════════════════════════════════════════════════════
    //  Activity lifecycle — protect against data loss
    // ════════════════════════════════════════════════════════════════════

    override fun onDestroy() {
        if (isRecording) {
            Log.w(TAG, "Activity destroyed during recording — saving file")
            safeStopAndRelease()
        }
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }
}

