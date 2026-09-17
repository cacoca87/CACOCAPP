import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/una_sola_vez.dart';

/// Busca la carátula real de una canción por título + artista usando la
/// API pública de iTunes Search (gratuita, sin API key).
///
/// Resultados en caché de memoria (rápido dentro de la misma sesión)
/// y también en SharedPreferences (sobrevive a cerrar la app). Como
/// aquí solo guardamos texto (URLs), no bytes de imagen, es liviano
/// y seguro guardarlo así — a diferencia de las carátulas ID3, que
/// van a disco por su tamaño.
class ArtworkService {
  // Mismo patrón que `JamendoService`, `LyricsService` y
  // `NoticiasService`: el cliente HTTP entra por el constructor privado
  // para poder probar esta clase sin red real. Era la única de las
  // cuatro que no lo tenía, y justamente por eso su fallo de caché
  // (marcar toda la biblioteca como "sin carátula" tras una apertura
  // sin internet) no lo agarró ningún test.
  ArtworkService._({http.Client? client}) : _client = client ?? http.Client();

  /// Instancia real que usa el resto de la app.
  static final ArtworkService instance = ArtworkService._();

  /// SOLO PARA TESTS: permite inyectar un cliente falso.
  factory ArtworkService.testable(http.Client client) =>
      ArtworkService._(client: client);

  final http.Client _client;

  final Map<String, String?> _cache = {};

  /// La `v2` sube de versión a propósito, para descartar lo guardado
  /// con la regla vieja.
  ///
  /// Hasta la vuelta 29 se anotaba en disco "esta canción no tiene
  /// carátula" también cuando lo que había fallado era la CONEXIÓN. Una
  /// sola apertura de la app sin internet dejaba la biblioteca entera
  /// marcada así, y como lo guardado se lee antes de pedir nada, esas
  /// canciones se seguirían viendo con el dibujito gris para siempre.
  /// Con el nombre nuevo se vuelven a consultar una vez.
  String _prefKey(String key) => 'artwork_cache_v2_$key';

  static const String _prefijoViejo = 'artwork_cache_';
  // Por instancia y no `static`: en la app hay una sola (`instance`),
  // asi que se limpia una vez igual, pero deja de depender del orden en
  // que corren los tests.
  bool _yaSeLimpioLoViejo = false;

  /// Borra de una sola vez lo guardado con la regla vieja, para no
  /// dejarlo ocupando lugar.
  Future<void> _limpiarLoGuardadoConLaReglaVieja(
      SharedPreferences prefs) async {
    if (_yaSeLimpioLoViejo) return;
    _yaSeLimpioLoViejo = true;
    try {
      for (final clave in prefs.getKeys().toList()) {
        if (clave.startsWith(_prefijoViejo) &&
            !clave.startsWith('artwork_cache_v2_')) {
          await prefs.remove(clave);
        }
      }
    } catch (_) {}
  }

  /// Junta los pedidos simultáneos de la misma canción.
  ///
  /// La misma canción puede estar dibujada en cuatro lugares a la vez:
  /// la fila de la lista, el mini reproductor de abajo, y los carruseles
  /// de "Recientes", "Favoritas" y "Recomendado" de la pantalla de
  /// Inicio. Las cuatro piden su carátula en el mismo instante, ninguna
  /// la encuentra guardada todavía, y las cuatro salían a preguntarle a
  /// iTunes exactamente lo mismo. Ver `utils/una_sola_vez.dart`.
  final UnaSolaVez<String?> _juntarPedidos = UnaSolaVez<String?>();

  String _clave(String title, String artist) =>
      '${title.toLowerCase()}|${artist.toLowerCase()}';

  Future<String?> getCoverUrl(String title, String artist) {
    final key = _clave(title, artist);
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _juntarPedidos.hacer(key, () => _buscarCoverUrl(key, title, artist));
  }

  /// `true` si ya se sabe, sin esperar nada, qué carátula le toca a
  /// esta canción (o que no tiene). Mismo motivo que
  /// `Id3CoverService.seSabeLaRuta`: evitar el cuadro de ruedita en
  /// cada fila que aparece al desplazar la lista.
  bool seSabeLaUrl(String title, String artist) =>
      _cache.containsKey(_clave(title, artist));

  /// La dirección ya conocida. Solo tiene sentido si [seSabeLaUrl] dijo
  /// que sí: `null` acá significa "iTunes no tiene esta canción".
  String? urlYaConocida(String title, String artist) =>
      _cache[_clave(title, artist)];

  Future<String?> _buscarCoverUrl(
      String key, String title, String artist) async {
    // Otro pedido de la misma canción pudo resolverla mientras este
    // esperaba su turno.
    if (_cache.containsKey(key)) return _cache[key];

    // 1) ¿Ya lo buscamos en una sesión anterior?
    try {
      final prefs = await SharedPreferences.getInstance();
      await _limpiarLoGuardadoConLaReglaVieja(prefs);
      final prefKey = _prefKey(key);
      if (prefs.containsKey(prefKey)) {
        final guardado = prefs.getString(prefKey);
        // String vacío = "ya se buscó, no se encontró nada" (evita
        // repetir la búsqueda a iTunes en cada apertura de la app).
        final resultado =
            (guardado != null && guardado.isNotEmpty) ? guardado : null;
        _cache[key] = resultado;
        return resultado;
      }
    } catch (_) {
      // Si falla la lectura, seguimos igual por red.
    }

    // 2) No estaba guardado: lo buscamos en iTunes, como antes.
    // `respuestaValida` distingue "iTunes contesto y no tiene esta
    // cancion" de "no hubo internet". Antes los dos casos se guardaban
    // igual en disco, asi que abrir la app una sola vez sin conexion
    // dejaba TODA la biblioteca marcada como "sin caratula" para
    // siempre, con el dibujito gris en cada fila.
    var respuestaValida = false;
    try {
      final term = Uri.encodeComponent('$artist $title');
      final url = Uri.parse(
        'https://itunes.apple.com/search?term=$term&entity=song&limit=1',
      );
      final response =
          await _client.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        respuestaValida = true;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        // Se comprueba la FORMA de lo que llegó antes de meterle mano.
        //
        // Antes se hacía `results.first['artworkUrl100']` directo sobre
        // algo sin tipo: si iTunes devolviera una lista de cualquier
        // otra cosa, eso explota. Quedaba tapado por el `catch` de más
        // abajo, así que no se rompía la app --pero la canción se
        // quedaba sin carátula sin que nadie supiera por qué--.
        final primero =
            results == null || results.isEmpty ? null : results.first;
        if (primero is Map) {
          var art = primero['artworkUrl100'];
          if (art is String) {
            // iTunes devuelve la miniatura de 100x100 por defecto;
            // pedimos una resolución más grande para que se vea nítida.
            art = art.replaceAll('100x100bb', '600x600bb');
            _cache[key] = art;
            unawaited(_guardar(key, art));
            return art;
          }
        }
      }
    } catch (_) {
      // Sin internet o iTunes caído: seguimos con el fallback genérico.
    }

    // El "no hay" queda en memoria siempre (para no repetir la consulta
    // cincuenta veces en la misma sesion), pero solo baja a disco si la
    // respuesta fue de verdad.
    _cache[key] = null;
    if (respuestaValida) unawaited(_guardar(key, ''));
    return null;
  }

  Future<void> _guardar(String key, String valor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey(key), valor);
    } catch (_) {}
  }
}
