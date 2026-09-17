import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../services/my_audio_handler.dart';
import '../utils/app_logger.dart';
import '../utils/extension_guesser.dart';
import 'recommendation_engine.dart';

class PlayerProvider extends ChangeNotifier {
  final MyAudioHandler audioHandler;

  /// Pausa el video de YouTube que esté sonando en la app, si hay uno.
  ///
  /// Se llama desde dos lugares: cuando arranca a sonar una canción de
  /// la biblioteca (para que no queden dos cosas sonando a la vez) y
  /// cuando vence el temporizador de apagado. Este segundo caso faltaba:
  /// el temporizador solo frenaba el motor de audio, así que si te
  /// dormías escuchando un video, seguía sonando toda la noche.
  final VoidCallback? onPausarVideoOnline;

  List<Song> _queue = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isShuffleEnabled = false;
  int _repeatMode = 0;
  Song? _currentSong;

  Timer? _sleepTimer;
  DateTime? _sleepTimerEndsAt;

  List<String> _historial = [];
  Map<String, int> _conteoReproducciones = {};

  final Map<String, int> _tiempoEscuchadoSegundos = {};
  final Map<String, String> _tituloPorCancion = {};
  Timer? _tiempoEscuchaTimer;

  final Map<String, String> _rutasDescargadas = {};
  final Map<String, Song> _cancionesDescargadas = {};
  final Set<String> _descargando = {};
  Future<void>? _descargasListas;

  // Getters
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffleEnabled => _isShuffleEnabled;
  int get repeatMode => _repeatMode;
  Song? get currentSong => _currentSong;
  bool get sleepTimerActivo => _sleepTimer != null;
  List<String> get historialIds => List.unmodifiable(_historial);

  List<String> get masEscuchadasIds =>
      ordenarPorMasEscuchadas(_conteoReproducciones);

  int? get sleepTimerMinutosRestantes {
    if (_sleepTimerEndsAt == null) return null;
    final restante = _sleepTimerEndsAt!.difference(DateTime.now());
    if (restante.isNegative) return 0;
    return (restante.inSeconds / 60).ceil();
  }

  Map<String, int> get timeListened =>
      Map.unmodifiable(_tiempoEscuchadoSegundos);

  String tituloDeCancion(String songId) => _tituloPorCancion[songId] ?? songId;

  bool isDownloaded(String songId) => _rutasDescargadas.containsKey(songId);

  /// Todas las canciones descargadas, con su metadata completa (título,
  /// artista, carátula) sin importar de dónde vinieron originalmente
  /// (biblioteca del Drive, Jamendo, o el buscador online) -- para
  /// mostrarlas todas juntas en una sola pantalla de "Música descargada".
  List<Song> get downloadedSongs =>
      List.unmodifiable(_cancionesDescargadas.values);

  /// Se resuelve cuando terminó de leer las descargas guardadas en
  /// disco (SharedPreferences). Como `_cargarDescargas()` se dispara
  /// en el constructor sin esperarse, cualquier código que necesite
  /// `downloadedSongs` ya completo (ej. para fusionarlo con la
  /// biblioteca antes de restaurar playlists) debe esperar esto primero.
  Future<void> get whenDownloadsLoaded => _descargasListas ?? Future.value();
  bool isDownloading(String songId) => _descargando.contains(songId);

  PlayerProvider(this.audioHandler, {this.onPausarVideoOnline}) {
    audioHandler.playbackState.listen((state) {
      // Mientras suena un VIDEO de YouTube, esta notificación no habla
      // de la biblioteca: la comparte el video, que la usa para poner
      // sus controles en la pantalla de bloqueo.
      //
      // Sin esta salvedad, este provider la leía como si la canción de
      // la biblioteca hubiera empezado a sonar, y pasaban dos cosas
      // feas:
      //
      //  * el reloj de "tiempo escuchado" se ponía en marcha y le sumaba
      //    a la ÚLTIMA canción de la biblioteca cada minuto de video que
      //    mirabas. Las Estadísticas mostraban horas dedicadas a
      //    canciones que en ese rato no sonaron ni un segundo.
      //  * si esa canción venía restaurada de la sesión anterior y
      //    todavía no se había contado, se le anotaba una reproducción
      //    que nunca ocurrió.
      //
      // El video lleva su propia cuenta en su propia barra; acá no
      // tiene nada que hacer.
      if (audioHandler.modoVideo) return;

      final sonando = state.playing;
      var hayQueAvisar = false;

      if (sonando) {
        _iniciarTemporizadorDeEscucha();
        // El historial y el contador de reproducciones se anotan ACA y
        // no al cambiar el `mediaItem`: al abrir la app se restaura la
        // ultima sesion en pausa, y eso emitia un `mediaItem` que
        // sumaba una reproduccion sin que nadie escuchara nada. Abrir
        // la app diez veces contaba diez escuchas.
        final song = _currentSong;
        if (song != null &&
            song.id.isNotEmpty &&
            _registrarEnHistorial(song.id)) {
          // Cambió "Recientes" y "Más Escuchadas": eso sí se ve.
          hayQueAvisar = true;
        }
      } else {
        _detenerTemporizadorDeEscucha();
      }

      if (sonando != _isPlaying) {
        _isPlaying = sonando;
        hayQueAvisar = true;
      }

      // Solo se avisa a las pantallas cuando cambió algo que SE VE.
      //
      // Antes se avisaba en cada evento del reproductor, y esos llegan
      // varias veces por segundo mientras se descarga la canción
      // (cambia cuánto lleva bufferizado). O sea que la pantalla
      // principal entera --con su lista de cientos de canciones-- se
      // rehacía varias veces por segundo mientras sonaba música, sin
      // que cambiara un solo pixel. En un celular de gama media eso se
      // siente como que la app va pesada.
      if (hayQueAvisar) notifyListeners();
    });

    audioHandler.mediaItem.listen((item) {
      // Por el mismo motivo: en modo video lo que se anuncia ahí es el
      // video, no una canción de la biblioteca. Sin esto, con la cola
      // vacía se fabricaba una `Song` falsa con los datos del video y
      // el mini reproductor de la biblioteca aparecía mostrándolo, como
      // si fuera un tema tuyo.
      if (audioHandler.modoVideo) return;

      if (item != null) {
        // Se busca por posición y no solo por contenido porque hacen
        // falta las dos cosas: cuál es la canción Y en qué lugar de la
        // cola está.
        final indice = _queue.indexWhere((s) => s.id == item.id);
        final song = indice != -1
            ? _queue[indice]
            // El indice se acota a la cola: si quedo apuntando mas alla
            // del final (una cola nueva mas corta que la anterior), esto
            // era un RangeError en medio de un evento de audio.
            : (_queue.isNotEmpty
                ? _queue[_currentIndex.clamp(0, _queue.length - 1)]
                : Song(
                    id: item.id,
                    title: item.title,
                    artist: item.artist ?? '',
                    album: item.album ?? '',
                    url: '',
                    coverUrl: item.artUri?.toString() ?? '',
                  ));

        var hayQueAvisar = false;

        // El índice solo se fijaba al armar la cola, así que en cuanto
        // la música pasaba sola a la siguiente canción quedaba viejo.
        // La pantalla "Cola de reproducción" lo usa para saber cuál
        // resaltar: te marcaba en ámbar, con el ícono de ecualizador,
        // una canción que había terminado hace rato, y al abrirla te
        // dejaba parado en ese lugar de la lista en vez de en la que
        // estaba sonando.
        if (indice != -1 && indice != _currentIndex) {
          _currentIndex = indice;
          hayQueAvisar = true;
        }

        // Mismo criterio: el `mediaItem` se emite varias veces por
        // canción (al armar la fuente, al llegar el índice, al conocerse
        // la duración, al aparecer la carátula) y casi siempre es la
        // MISMA canción. Avisar solo cuando de verdad cambió.
        if (song.id.isNotEmpty && song.id != _currentSong?.id) {
          _currentSong = song;
          hayQueAvisar = true;
        }

        if (hayQueAvisar) notifyListeners();
      }
    });
    _cargarHistorial();
    _cargarTiempoEscuchado();
    _descargasListas = _cargarDescargas();
  }

  // ========== RECOMENDACIONES ==========

  // Las recomendaciones se barajan al azar, y se piden desde el `build`
  // de dos pantallas. Sin guardar el resultado, cada refresco --y hay
  // muchos: uno por cada latido del reproductor-- devolvía un orden
  // distinto, así que el carrusel de "Recomendado para ti" se
  // reacomodaba solo delante de los ojos del usuario.
  //
  // Se recalcula únicamente cuando cambia algo que de verdad importa:
  // la cantidad de canciones o el historial de escucha.
  List<Song>? _recomendacionesGuardadas;
  String? _claveRecomendaciones;

  List<Song> getRecommendations(List<Song> allSongs) {
    final clave = '${allSongs.length}|${_historial.join(',')}';
    final guardadas = _recomendacionesGuardadas;
    if (guardadas != null && _claveRecomendaciones == clave) return guardadas;

    final nuevas = calcularRecomendaciones(allSongs, _historial);
    _claveRecomendaciones = clave;
    _recomendacionesGuardadas = nuevas;
    return nuevas;
  }

  // ========== HISTORIAL ==========
  static const String _historialKey = 'player_history_v1';
  static const String _conteoKey = 'player_playcount_v1';

  // El id de la ultima cancion que se conto como reproducida.
  //
  // `audioHandler.mediaItem` emite VARIAS veces por cada cancion: una
  // al armar la fuente, otra cuando llega el indice, otra cuando se
  // conoce la duracion y otra cuando aparece la caratula. Sin este
  // control, una sola escucha sumaba tres o cuatro reproducciones al
  // contador, y "Tus mas escuchadas" y las Estadisticas quedaban con
  // numeros inventados (distintos ademas segun cuantas de esas
  // emisiones llegara a hacer cada cancion).
  String? _ultimaCancionContada;

  /// Devuelve `true` si de verdad se anotó algo. Sirve para que quien
  /// llama sepa si tiene que refrescar la pantalla: "Recientes" y "Más
  /// Escuchadas" salen de acá, y si no cambió nada no hay nada que
  /// volver a dibujar.
  bool _registrarEnHistorial(String songId) {
    if (songId == _ultimaCancionContada) return false;
    _ultimaCancionContada = songId;
    _historial.remove(songId);
    _historial.insert(0, songId);
    if (_historial.length > 30) {
      _historial = _historial.sublist(0, 30);
    }
    _conteoReproducciones[songId] = (_conteoReproducciones[songId] ?? 0) + 1;
    _guardarHistorial();
    return true;
  }

  Future<void> _guardarHistorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historialKey, _historial);
      await prefs.setString(_conteoKey, jsonEncode(_conteoReproducciones));
    } catch (_) {}
  }

  Future<void> _cargarHistorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getStringList(_historialKey);
      if (guardado != null) _historial = guardado;
      final conteoRaw = prefs.getString(_conteoKey);
      if (conteoRaw != null) {
        final decodificado = jsonDecode(conteoRaw) as Map<String, dynamic>;
        _conteoReproducciones = decodificado.map(
          (clave, valor) => MapEntry(clave, valor as int),
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  // ========== TIEMPO ESCUCHADO ==========
  static const String _tiempoEscuchadoKey = 'player_time_listened_v2';

  void _iniciarTemporizadorDeEscucha() {
    // Si ya hay uno andando se deja como esta. Antes se cancelaba y se
    // creaba de nuevo en CADA evento del reproductor: si esos eventos
    // llegan mas seguido que una vez por segundo, el temporizador se
    // reiniciaba siempre antes de cumplir su primer segundo y el
    // tiempo escuchado no subia nunca -- con Estadisticas vacia para
    // siempre.
    if (_tiempoEscuchaTimer?.isActive ?? false) return;
    _tiempoEscuchaTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final song = _currentSong;
      if (song == null) return;
      _tituloPorCancion[song.id] = song.title;
      final total = (_tiempoEscuchadoSegundos[song.id] ?? 0) + 1;
      _tiempoEscuchadoSegundos[song.id] = total;
      if (total % 10 == 0) _guardarTiempoEscuchado();
    });
  }

  void _detenerTemporizadorDeEscucha() {
    _tiempoEscuchaTimer?.cancel();
    _tiempoEscuchaTimer = null;
    _guardarTiempoEscuchado();
  }

  Future<void> _guardarTiempoEscuchado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'segundos': _tiempoEscuchadoSegundos,
        'titulos': _tituloPorCancion,
      };
      await prefs.setString(_tiempoEscuchadoKey, jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> _cargarTiempoEscuchado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tiempoEscuchadoKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final segundos = (decoded['segundos'] as Map<String, dynamic>?) ?? {};
      final titulos = (decoded['titulos'] as Map<String, dynamic>?) ?? {};
      _tiempoEscuchadoSegundos
        ..clear()
        ..addAll(segundos.map((k, v) => MapEntry(k, v as int)));
      _tituloPorCancion
        ..clear()
        ..addAll(titulos.map((k, v) => MapEntry(k, v as String)));
      notifyListeners();
    } catch (_) {}
  }

  // ========== DESCARGAS OFFLINE ==========
  static const String _descargasKey = 'player_downloads_v1';
  static const String _descargasMetaKey = 'player_downloads_meta_v1';

  Future<void> _cargarDescargas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_descargasKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final ruta = entry.value as String;
          if (await File(ruta).exists()) {
            _rutasDescargadas[entry.key] = ruta;
          }
        }
      }

      final rawMeta = prefs.getString(_descargasMetaKey);
      if (rawMeta != null) {
        final decodedMeta = jsonDecode(rawMeta) as Map<String, dynamic>;
        for (final entry in decodedMeta.entries) {
          // Si el archivo ya no está (se borró a mano, falló la carga
          // de arriba, etc.), no mostramos una canción "descargada"
          // fantasma que en realidad no se puede reproducir.
          if (!_rutasDescargadas.containsKey(entry.key)) continue;
          final m = entry.value as Map<String, dynamic>;
          _cancionesDescargadas[entry.key] = Song(
            id: entry.key,
            title: (m['title'] as String?) ?? 'Sin título',
            artist: (m['artist'] as String?) ?? 'Desconocido',
            album: (m['album'] as String?) ?? '',
            url: (m['url'] as String?) ?? '',
            coverUrl: (m['coverUrl'] as String?) ?? '',
          );
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _guardarDescargas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_descargasKey, jsonEncode(_rutasDescargadas));
      final meta = _cancionesDescargadas.map((id, song) => MapEntry(id, {
            'title': song.title,
            'artist': song.artist,
            'album': song.album,
            'url': song.url,
            'coverUrl': song.coverUrl,
          }));
      await prefs.setString(_descargasMetaKey, jsonEncode(meta));
    } catch (_) {}
  }

  Future<bool> downloadSong(Song song, {String? extensionForzada}) async {
    if (_rutasDescargadas.containsKey(song.id)) return true;
    if (_descargando.contains(song.id)) return false;

    _descargando.add(song.id);
    notifyListeners();

    var exito = false;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final carpeta = Directory('${dir.path}/descargas');
      if (!await carpeta.exists()) await carpeta.create(recursive: true);

      final extension = extensionForzada ?? adivinarExtensionDeUrl(song.url);
      final archivo = File('${carpeta.path}/${song.id}.$extension');

      final respuesta = await http
          .get(Uri.parse(song.url))
          .timeout(const Duration(minutes: 5));
      if (respuesta.statusCode == 200) {
        await archivo.writeAsBytes(respuesta.bodyBytes);
        _rutasDescargadas[song.id] = archivo.path;
        _cancionesDescargadas[song.id] = song;
        await _guardarDescargas();
        exito = true;
      }
    } catch (e) {
      AppLogger.e('Error descargando ${song.title}', error: e);
    } finally {
      _descargando.remove(song.id);
      notifyListeners();
    }
    return exito;
  }

  Future<void> deleteDownload(String songId) async {
    final ruta = _rutasDescargadas[songId];
    if (ruta == null) return;
    try {
      final archivo = File(ruta);
      if (await archivo.exists()) await archivo.delete();
    } catch (_) {}
    _rutasDescargadas.remove(songId);
    _cancionesDescargadas.remove(songId);
    await _guardarDescargas();
    notifyListeners();

    // La cola que está sonando se armó con la RUTA DEL ARCHIVO de las
    // canciones descargadas, así que si se acaba de borrar una que está
    // en esa cola, el motor de audio quedó apuntando a un archivo que
    // ya no existe.
    //
    // Sin esto, seguir escuchando terminaba en un error raro: al llegar
    // a esa canción, el reproductor fallaba y el sistema de reintentos
    // la buscaba ocho veces seguidas antes de rendirse con "se perdió
    // la conexión" -- un mensaje que no tiene nada que ver con lo que
    // pasó, porque la conexión estaba perfecta.
    //
    // Se rearma la cola con las mismas canciones: `_queue` guarda los
    // originales, con su dirección de internet, y ahora que la descarga
    // no está, es esa la que se va a usar. Se conserva en qué canción
    // ibas, en qué minuto, y si estaba sonando o en pausa. Hay un
    // saltito, pero borrar una descarga es algo que se hace a
    // propósito y de vez en cuando, no en medio de nada.
    if (!_queue.any((s) => s.id == songId)) return;
    await setQueue(
      _queue,
      initialIndex: _currentIndex,
      initialPosition: audioHandler.player.position,
      autoplay: _isPlaying,
    );
  }

  String _urlParaReproducir(Song song) {
    final ruta = _rutasDescargadas[song.id];
    if (ruta == null) return song.url;
    // `ruta` es una ruta de archivo local cruda (ej.
    // "/data/user/0/.../descargas/id123.mp3"), NO una URL. just_audio
    // (AudioSource.uri) exige un esquema explícito para tratarla como
    // archivo local -- sin "file://" el audio nunca carga y la
    // canción "descargada" se queda muda aunque aparezca en la cola.
    return Uri.file(ruta).toString();
  }

  // ========== REPRODUCCIÓN ==========
  Future<bool> setQueue(
    List<Song> songs, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoplay = true,
  }) async {
    // Si había un video de YouTube sonando en la barra de abajo, se
    // pausa -- solo cuando esto realmente va a sonar (no en la
    // restauración silenciosa de sesión al abrir la app).
    if (autoplay) onPausarVideoOnline?.call();
    // Copia, no la lista de quien llamó.
    //
    // `cancionesParaNombre()` devuelve la lista INTERNA de la playlist,
    // así que sin esta copia la cola y la playlist eran el mismo objeto:
    // quitar una canción de la playlist (deslizándola) se la sacaba
    // también a la cola que estaba sonando, por debajo, y el índice
    // actual podía quedar apuntando fuera de rango.
    _queue = List<Song>.from(songs);
    _currentIndex =
        initialIndex.clamp(0, _queue.isNotEmpty ? _queue.length - 1 : 0);
    _currentSong = _queue.isNotEmpty ? _queue[_currentIndex] : null;

    final cancionesParaReproducir = songs
        .map((s) => Song(
              id: s.id,
              title: s.title,
              artist: s.artist,
              album: s.album,
              url: _urlParaReproducir(s),
              coverUrl: s.coverUrl,
            ))
        .toList();

    var exito = true;
    try {
      await audioHandler.setPlaylist(
        cancionesParaReproducir,
        initialIndex: _currentIndex,
        initialPosition: initialPosition,
        autoplay: autoplay,
      );
    } catch (e) {
      // El audioHandler ya avisó el error concreto por su canal de
      // "mensajes" (que main.dart muestra como SnackBar). Acá solo
      // evitamos que la excepción quede sin atrapar y rompa a quien
      // llamó a setQueue -- el estado de _currentSong/_queue queda tal
      // como se pidió (es lo que muestra el mini player) aunque el
      // audio en sí no haya podido cargar.
      AppLogger.e('setQueue: no se pudo cargar el audio', error: e);
      exito = false;
    }
    notifyListeners();
    _persistState();
    return exito;
  }

  void playSong(Song song, List<Song> queue, int index) {
    setQueue(queue, initialIndex: index);
  }

  void togglePlayPause() {
    if (_isPlaying) {
      audioHandler.pause();
    } else {
      audioHandler.play();
    }
  }

  void playNext() => audioHandler.skipToNext();
  void playPrevious() => audioHandler.skipToPrevious();
  void saltarAIndice(int index) => audioHandler.skipToQueueItem(index);

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    audioHandler.setShuffle(_isShuffleEnabled);
    notifyListeners();
    _persistState();
  }

  void toggleRepeat() {
    _repeatMode = (_repeatMode + 1) % 3;
    final mode = _repeatMode == 0
        ? AudioServiceRepeatMode.none
        : _repeatMode == 1
            ? AudioServiceRepeatMode.all
            : AudioServiceRepeatMode.one;
    audioHandler.setRepeatMode(mode);
    notifyListeners();
    _persistState();
  }

  // ========== TEMPORIZADOR DE SUEÑO ==========
  void activarTemporizadorDeSueno(Duration duracion) {
    _sleepTimer?.cancel();
    _sleepTimerEndsAt = DateTime.now().add(duracion);
    _sleepTimer = Timer(duracion, () {
      audioHandler.pause();
      // También el video de YouTube: si no, el temporizador solo frenaba
      // el motor de audio y un video en la barra seguía sonando toda la
      // noche, que es justo lo contrario de para qué sirve esto.
      onPausarVideoOnline?.call();
      _sleepTimer = null;
      _sleepTimerEndsAt = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelarTemporizadorDeSueno() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndsAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _tiempoEscuchaTimer?.cancel();
    super.dispose();
  }

  // ========== PERSISTENCIA ==========
  static const String _stateKey = 'player_state_v2';

  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final state = {
        'currentSongId': _currentSong?.id ?? '',
        'currentIndex': _currentIndex,
        'shuffle': _isShuffleEnabled,
        'repeat': _repeatMode,
      };
      await prefs.setString(_stateKey, jsonEncode(state));
    } catch (e) {
      AppLogger.e('Error guardando estado', error: e);
    }
  }

  Future<void> restoreSession(List<Song> allSongs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateRaw = prefs.getString(_stateKey);
      if (stateRaw != null) {
        final state = jsonDecode(stateRaw) as Map<String, dynamic>;
        final songId = state['currentSongId'] as String? ?? '';
        _isShuffleEnabled = state['shuffle'] as bool? ?? false;
        _repeatMode = state['repeat'] as int? ?? 0;

        final songIndex = allSongs.indexWhere((s) => s.id == songId);
        if (songIndex != -1 && allSongs.isNotEmpty) {
          final positionMs = prefs.getInt('last_position') ?? 0;
          await setQueue(
            allSongs,
            initialIndex: songIndex,
            initialPosition: Duration(milliseconds: positionMs),
            autoplay: false,
          );
        } else if (allSongs.isNotEmpty) {
          await setQueue(allSongs, initialIndex: 0, autoplay: false);
        }
      } else if (allSongs.isNotEmpty) {
        await setQueue(allSongs, initialIndex: 0, autoplay: false);
      }
      notifyListeners();
    } catch (e) {
      AppLogger.e('Error restaurando sesión', error: e);
    }
  }

  Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final position = audioHandler.player.position;
    await prefs.setInt('last_position', position.inMilliseconds);
    await _persistState();
  }
}
