package com.caco.musicapp

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.provider.MediaStore
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

    /** Canal aparte: leer la música del celular no tiene nada que ver
     * con los efectos de audio, y mezclarlos en el mismo canal haría
     * que el nombre "audio_effects" dejara de querer decir algo. */
    private val channelMusicaLocal = "com.caco.musicapp/musica_local"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelMusicaLocal).setMethodCallHandler { call, result ->
            when (call.method) {
                "listar" -> result.success(listarMusicaDelCelular())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Devuelve TODO el audio que Android tiene indexado, con los datos
     * crudos y sin filtrar nada.
     *
     * Lo de "sin filtrar" es a propósito y es importante: decidir qué
     * es música de verdad y qué es una nota de voz de WhatsApp se hace
     * del lado de Dart (`utils/filtro_musica_local.dart`), donde está
     * cubierto por tests que se pueden correr sin un celular. Acá solo
     * se leen los datos y se los pasa tal cual.
     *
     * Android mantiene este índice solo: cuando llega un archivo nuevo
     * al teléfono --por WhatsApp, por cable, desde otra app-- lo agrega
     * sin que nadie tenga que pedírselo. Por eso alcanza con volver a
     * consultar para ver lo nuevo.
     *
     * SOBRE LA COLUMNA `DATA`, QUE FIGURA COMO OBSOLETA
     *
     * `DATA` es la ruta del archivo, y Android la marca como obsoleta
     * desde la versión 10. Es de las cosas que alguien mira, ve el
     * tachado en el editor y "arregla" cambiándola por una dirección
     * `content://`. Conviene dejar escrito por qué acá se usa igual:
     *
     *  * Desde Android 11, una app con permiso de audio SÍ puede abrir
     *    los archivos de música por su ruta. Lo prohibido fue el acceso
     *    suelto a todo el almacenamiento, no esto.
     *  * La app usa esa ruta para tres cosas y no solo para reproducir:
     *    decidir si el archivo es música de verdad --que se hace
     *    mirando en qué CARPETA está--, leerle la carátula de adentro
     *    del MP3, y sacarle el título y el artista reales. Con una
     *    dirección `content://` nada de eso funciona sin escribir otro
     *    puente nativo.
     *
     * O sea: cambiarlo no arregla nada y rompe tres cosas. Si algún día
     * deja de andar de verdad en algún celular, el camino es devolver
     * las DOS --la ruta para filtrar y la dirección para reproducir--,
     * no reemplazar una por la otra.
     */
    private fun listarMusicaDelCelular(): List<Map<String, Any?>> {
        val encontradas = mutableListOf<Map<String, Any?>>()

        val columnas = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.IS_RINGTONE,
            MediaStore.Audio.Media.IS_NOTIFICATION,
            MediaStore.Audio.Media.IS_ALARM,
            MediaStore.Audio.Media.IS_PODCAST
        )
        // Estas dos columnas no existen en las versiones viejas de
        // Android: preguntarlas ahí hace fallar la consulta entera.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            columnas.add(MediaStore.Audio.Media.IS_AUDIOBOOK)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            columnas.add(MediaStore.Audio.Media.IS_RECORDING)
        }

        try {
            val cursor = contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                columnas.toTypedArray(),
                "${MediaStore.Audio.Media.IS_MUSIC} != 0",
                null,
                "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
            ) ?: return encontradas

            cursor.use { c ->
                fun texto(nombre: String): String {
                    val i = c.getColumnIndex(nombre)
                    return if (i == -1) "" else (c.getString(i) ?: "")
                }
                fun bandera(nombre: String): Boolean {
                    val i = c.getColumnIndex(nombre)
                    return i != -1 && c.getInt(i) != 0
                }

                while (c.moveToNext()) {
                    val ruta = texto(MediaStore.Audio.Media.DATA)
                    // Sin ruta no se puede reproducir ni leer la
                    // carátula: no sirve de nada mostrarla.
                    if (ruta.isEmpty()) continue

                    val iDuracion = c.getColumnIndex(MediaStore.Audio.Media.DURATION)
                    val iId = c.getColumnIndex(MediaStore.Audio.Media._ID)

                    encontradas.add(
                        mapOf(
                            "id" to if (iId == -1) 0L else c.getLong(iId),
                            "titulo" to texto(MediaStore.Audio.Media.TITLE),
                            "artista" to texto(MediaStore.Audio.Media.ARTIST),
                            "album" to texto(MediaStore.Audio.Media.ALBUM),
                            "duracionMs" to if (iDuracion == -1) 0L else c.getLong(iDuracion),
                            "ruta" to ruta,
                            "esTimbre" to bandera(MediaStore.Audio.Media.IS_RINGTONE),
                            "esNotificacion" to bandera(MediaStore.Audio.Media.IS_NOTIFICATION),
                            "esAlarma" to bandera(MediaStore.Audio.Media.IS_ALARM),
                            "esPodcast" to bandera(MediaStore.Audio.Media.IS_PODCAST),
                            "esAudiolibro" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                                bandera(MediaStore.Audio.Media.IS_AUDIOBOOK) else false,
                            "esGrabacion" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                                bandera(MediaStore.Audio.Media.IS_RECORDING) else false
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // Sin permiso, o el fabricante cambió algo: se devuelve lo
            // que se haya juntado en vez de tirar la app abajo. La
            // biblioteca del servidor sigue funcionando igual.
        }

        return encontradas
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
