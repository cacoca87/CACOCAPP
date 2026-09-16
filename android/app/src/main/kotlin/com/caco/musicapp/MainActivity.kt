package com.caco.musicapp

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Puente nativo hacia los efectos de audio de Android
 * (`android.media.audiofx`): Equalizer, BassBoost, LoudnessEnhancer.
 * `just_audio` (el motor de audio que usa la app) no trae ecualizador
 * ni realce de volumen de fábrica -- pero SÍ expone el ID de sesión de
 * audio (`androidAudioSessionIdStream`), que es justo lo que Android
 * necesita para engancharle estos efectos nativos desde afuera.
 *
 * Cada método está envuelto en try/catch: algunos fabricantes
 * restringen o no implementan estos efectos en ciertos dispositivos --
 * si eso pasa, el canal simplemente no hace nada en vez de crashear la
 * app.
 */
class MainActivity : AudioServiceActivity() {
    private val channelName = "com.caco.musicapp/audio_effects"

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var currentSessionId: Int = -1

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "attach" -> {
                    val sessionId = call.argument<Int>("sessionId") ?: -1
                    attachEffects(sessionId)
                    result.success(effectsInfo())
                }
                "setBandLevel" -> {
                    val band = (call.argument<Int>("band") ?: 0).toShort()
                    val level = (call.argument<Int>("level") ?: 0).toShort()
                    try { equalizer?.setBandLevel(band, level) } catch (e: Exception) {}
                    result.success(null)
                }
                "setEqualizerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try { equalizer?.enabled = enabled } catch (e: Exception) {}
                    result.success(null)
                }
                "setBassBoostStrength" -> {
                    val strength = (call.argument<Int>("strength") ?: 0).toShort()
                    try { bassBoost?.setStrength(strength) } catch (e: Exception) {}
                    result.success(null)
                }
                "setBassBoostEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try { bassBoost?.enabled = enabled } catch (e: Exception) {}
                    result.success(null)
                }
                "setLoudnessGain" -> {
                    val gainMb = call.argument<Int>("gainMb") ?: 0
                    try { loudnessEnhancer?.setTargetGain(gainMb) } catch (e: Exception) {}
                    result.success(null)
                }
                "setLoudnessEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try { loudnessEnhancer?.enabled = enabled } catch (e: Exception) {}
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun attachEffects(sessionId: Int) {
        if (sessionId == currentSessionId && equalizer != null) return
        releaseEffects()
        if (sessionId <= 0) return
        currentSessionId = sessionId

        try {
            equalizer = Equalizer(0, sessionId).apply { enabled = false }
        } catch (e: Exception) {}
        try {
            bassBoost = BassBoost(0, sessionId).apply { enabled = false }
        } catch (e: Exception) {}
        try {
            loudnessEnhancer = LoudnessEnhancer(sessionId).apply { enabled = false }
        } catch (e: Exception) {}
    }

    private fun effectsInfo(): Map<String, Any> {
        val eq = equalizer
        if (eq == null) {
            return mapOf(
                "bands" to emptyList<Map<String, Any>>(),
                "minLevel" to 0,
                "maxLevel" to 0,
                "bassBoostSupported" to false,
                "loudnessSupported" to false
            )
        }

        val numBands = try { eq.numberOfBands.toInt() } catch (e: Exception) { 0 }
        val range = try { eq.bandLevelRange } catch (e: Exception) { shortArrayOf(0, 0) }
        val bands = (0 until numBands).map { i ->
            val freqHz = try { eq.getCenterFreq(i.toShort()) / 1000 } catch (e: Exception) { 0 }
            val level = try { eq.getBandLevel(i.toShort()).toInt() } catch (e: Exception) { 0 }
            mapOf("index" to i, "freqHz" to freqHz, "level" to level)
        }

        return mapOf(
            "bands" to bands,
            "minLevel" to range[0].toInt(),
            "maxLevel" to range[1].toInt(),
            "bassBoostSupported" to (bassBoost != null),
            "loudnessSupported" to (loudnessEnhancer != null)
        )
    }

    private fun releaseEffects() {
        try { equalizer?.release() } catch (e: Exception) {}
        try { bassBoost?.release() } catch (e: Exception) {}
        try { loudnessEnhancer?.release() } catch (e: Exception) {}
        equalizer = null
        bassBoost = null
        loudnessEnhancer = null
    }

    override fun onDestroy() {
        releaseEffects()
        super.onDestroy()
    }
}
