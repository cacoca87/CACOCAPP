import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart'; // Asegura acceso a ProcessingState
import '../models/song.dart';
import '../services/my_audio_handler.dart';
import '../services/youtube_service.dart'; // Importante para refrescar los enlaces expirados
import '../utils/extension_guesser.dart';
import 'refresh_retry_guard.dart';

class PlayerProvider extends ChangeNotifier {
  final MyAudioHandler audioHandler;

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

  // Guarda contra el bucle de "refresco de enlace expirado" (ver más
  // abajo, en el constructor): sin esto, dos canciones de YouTube que
  // fallan a la vez pueden quedar reintentando para siempre entre sí,
  // cada una reseteando el contador de reintentos de la otra. La
  // lógica vive aparte, en `RefreshRetryGuard`, para poder testearla
  // sin tener que levantar todo el motor de audio -- ver
  // test/providers/refresh_retry_guard_test.dart.
  final RefreshRetryGuard _refreshGuard = RefreshRetryGuard();
  // Se incrementa en cada `setQueue`. Sirve para que un refresco de
  // enlace vencido que quedó esperando una respuesta de red se dé
  // cuenta de que, mientras tanto, se pidió reproducir otra cosa, y no
  // la pise al terminar.
  int _playbackRequestId = 0;

  // Getters
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffleEnabled => _isShuffleEnabled;
  int get repeatMode => _repeatMode;
  Song? get currentSong => _currentSong;
  bool get sleepTimerActivo => _sleepTimer != null;
  List<String> get historialIds => List.unmodifiable(_historial);
  
  List<String> get masEscuchadasIds {
    final entradas = _conteoReproducciones.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entradas.map((e) => e.key).toList();
  }

  int? get sleepTimerMinutosRestantes {
    if (_sleepTimerEndsAt == null) return null;
    final restante = _sleepTimerEndsAt!.difference(DateTime.now());
    if (restante.isNegative) return 0;
    return (restante.inSeconds / 60).ceil();
  }

  Map<String, int> get timeListened => Map.unmodifiable(_tiempoEscuchadoSegundos);

  String tituloDeCancion(String songId) => _tituloPorCancion[songId] ?? songId;

  bool isDownloaded(String songId) => _rutasDescargadas.containsKey(songId);

  /// Todas las canciones descargadas, con su metadata completa (título,
  /// artista, carátula) sin importar de dónde vinieron originalmente
  /// (biblioteca del Drive, Jamendo, o el buscador online) -- para
  /// mostrarlas todas juntas en una sola pantalla de "Música descargada".
  List<Song> get downloadedSongs => List.unmodifiable(_cancionesDescargadas.values);

  /// Se resuelve cuando terminó de leer las descargas guardadas en
  /// disco (SharedPreferences). Como `_cargarDescargas()` se dispara
  /// en el constructor sin esperarse, cualquier código que necesite
  /// `downloadedSongs` ya completo (ej. para fusionarlo con la
  /// biblioteca antes de restaurar playlists) debe esperar esto primero.
  Future<void> get whenDownloadsLoaded => _descargasListas ?? Future.value();
  bool isDownloading(String songId) => _descargando.contains(songId);

  PlayerProvider(this.audioHandler) {
    audioHandler.playbackState.listen((state) {
      _isPlaying = state.playing;
      if (_isPlaying) {
        _iniciarTemporizadorDeEscucha();
      } else {
        _detenerTemporizadorDeEscucha();
      }
      notifyListeners();
    });

    // ESCUCHA INTELIGENTE DE ERRORES DE REPRODUCCIÓN Y RECUPERACIÓN DE ENLACES
    // Esto SOLO aplica a canciones de YouTube: son las únicas cuyas URLs
    // de audio vienen firmadas con expiración. Las de Drive/Jamendo/
    // descargas no necesitan (ni pueden) "refrescarse" así.
    audioHandler.player.playerStateStream.listen((playerState) async {
      final estaFallando = playerState.processingState == ProcessingState.idle ||
          (playerState.processingState != ProcessingState.completed && !playerState.playing && _isPlaying);

      if (!estaFallando) {
        // Reproducción normal (o recién arrancando bien): se limpia
        // cualquier racha de reintentos previa para que la próxima vez
        // que ESTA canción falle empiece a contar de cero de nuevo.
        _refreshGuard.reset();
        return;
      }

      final song = _currentSong;
      final esDeYoutube = song != null && song.id.startsWith('yt_');
      if (!esDeYoutube || isDownloaded(song.id) || song.url.isEmpty) return;

      // Tope de reintentos POR canción: sin esto, si la URL nueva
      // también falla, el estado vuelve a "idle", este listener vuelve
      // a dispararse, y así para siempre -- confirmado en la práctica
      // (dos canciones de YouTube quedaron alternándose en este bucle
      // sin parar, porque cada refresco "exitoso" reseteaba el propio
      // contador de reintentos de `my_audio_handler.dart`).
      if (!_refreshGuard.deberiaReintentar(song.id)) return;

      debugPrint(
        'Enlace expirado o caída detectada. Refrescando URL para: ${song.title} '
        '(intento ${_refreshGuard.intentosPara(song.id)}/${_refreshGuard.maxIntentos})',
      );

      // Token de generación: si mientras esto está en vuelo el usuario
      // pone a sonar otra cosa (setQueue lo incrementa), este intento
      // se descarta en vez de pisar la canción nueva al terminar.
      final generacionAlEmpezar = _playbackRequestId;
      try {
        // song.id tiene forma "yt_<videoId>" -- hay que sacarle el
        // prefijo antes de pedirle el audio a YoutubeService, que
        // espera el ID de video real. Pasarle "yt_<videoId>" tal
        // cual (como se hacía antes) hacía que esto fallara siempre
        // en silencio y la reproducción se quedara trabada.
        final videoId = song.id.substring(3);
        final nuevaUrl = await YoutubeService.instance.obtenerUrlAudioPuro(videoId);

        if (generacionAlEmpezar != _playbackRequestId) return;

        if (nuevaUrl != null && nuevaUrl.isNotEmpty) {
          // Creamos una nueva instancia de Song ya que 'url' es final
          final songActualizada = Song(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            url: nuevaUrl,
            coverUrl: song.coverUrl,
            playlists: song.playlists,
          );

          final posicionActual = audioHandler.player.position;
          // setQueue es el mismo camino que usa el resto de la app
          // para reproducir -- a diferencia de `playMediaItem`, que
          // no está implementado en este proyecto y no hacía nada.
          await setQueue(
            [songActualizada],
            initialIndex: 0,
            initialPosition: posicionActual,
            autoplay: true,
          );
          debugPrint('¡Enlace refrescado con éxito! Reanudando reproducción...');
        }
      } catch (e) {
        debugPrint('No se pudo refrescar el enlace automáticamente: $e');
      }
    });

    audioHandler.mediaItem.listen((item) {
      if (item != null) {
        final song = _queue.firstWhere(
          (s) => s.id == item.id,
          orElse: () => _queue.isNotEmpty
              ? _queue[_currentIndex]
              : Song(
                  id: item.id,
                  title: item.title,
                  artist: item.artist ?? '',
                  album: item.album ?? '',
                  url: '',
                  coverUrl: item.artUri?.toString() ?? '',
                ),
        );
        if (song.id.isNotEmpty) {
          _currentSong = song;
          _registrarEnHistorial(song.id);
          notifyListeners();
        }
      }
    });

    _cargarHistorial();
    _cargarTiempoEscuchado();
    _descargasListas = _cargarDescargas();
  }

  // ========== RECOMENDACIONES ==========
  List<Song> getRecommendations(List<Song> allSongs) {
    if (allSongs.isEmpty) return [];
    
    final noEscuchadas = allSongs.where((song) => !_historial.contains(song.id)).toList();
    if (noEscuchadas.isNotEmpty) {
      noEscuchadas.shuffle();
      return noEscuchadas.take(10).toList();
    }
    
    final copia = List<Song>.from(allSongs);
    copia.shuffle();
    return copia.take(10).toList();
  }

  // ========== HISTORIAL ==========
  static const String _historialKey = 'player_history_v1';
  static const String _conteoKey = 'player_playcount_v1';

  void _registrarEnHistorial(String songId) {
    _historial.remove(songId);
    _historial.insert(0, songId);
    if (_historial.length > 30) {
      _historial = _historial.sublist(0, 30);
    }
    _conteoReproducciones[songId] = (_conteoReproducciones[songId] ?? 0) + 1;
    _guardarHistorial();
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
    _tiempoEscuchaTimer?.cancel();
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

      final respuesta = await http.get(Uri.parse(song.url)).timeout(const Duration(minutes: 5));
      if (respuesta.statusCode == 200) {
        await archivo.writeAsBytes(respuesta.bodyBytes);
        _rutasDescargadas[song.id] = archivo.path;
        _cancionesDescargadas[song.id] = song;
        await _guardarDescargas();
        exito = true;
      }
    } catch (e) {
      debugPrint('Error descargando ${song.title}: $e');
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
    // Invalida cualquier refresco de enlace de YouTube que haya quedado
    // en vuelo para la canción anterior -- si no, cuando ese refresco
    // viejo termine, puede pisar la canción que se está por poner acá.
    _playbackRequestId++;
    // Un pedido explícito de reproducir algo (el usuario tocó play de
    // nuevo, por ejemplo) siempre arranca con presupuesto de reintentos
    // fresco, aunque esa misma canción ya haya agotado el suyo antes.
    _refreshGuard.reset();
    _queue = songs;
    _currentIndex = initialIndex.clamp(0, _queue.isNotEmpty ? _queue.length - 1 : 0);
    _currentSong = _queue.isNotEmpty ? _queue[_currentIndex] : null;

    final cancionesParaReproducir = songs
        .map((s) => Song(
              id: s.id,
              title: s.title,
              artist: s.artist,
              album: s.album,
              url: _urlParaReproducir(s),
              coverUrl: s.coverUrl,
              playlists: s.playlists,
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
      debugPrint('setQueue: no se pudo cargar el audio: $e');
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
      debugPrint('Error guardando estado: $e');
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
      debugPrint('Error restaurando sesión: $e');
    }
  }

  Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final position = audioHandler.player.position;
    await prefs.setInt('last_position', position.inMilliseconds);
    await _persistState();
  }
}