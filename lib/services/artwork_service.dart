import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Busca la carátula real de una canción por título + artista usando la
/// API pública de iTunes Search (gratuita, sin API key).
///
/// Resultados en caché de memoria (rápido dentro de la misma sesión)
/// y también en SharedPreferences (sobrevive a cerrar la app). Como
/// aquí solo guardamos texto (URLs), no bytes de imagen, es liviano
/// y seguro guardarlo así — a diferencia de las carátulas ID3, que
/// van a disco por su tamaño.
class ArtworkService {
  ArtworkService._();
  static final ArtworkService instance = ArtworkService._();

  final Map<String, String?> _cache = {};

  String _prefKey(String key) => 'artwork_cache_$key';

  Future<String?> getCoverUrl(String title, String artist) async {
    final key = '${title.toLowerCase()}|${artist.toLowerCase()}';
    if (_cache.containsKey(key)) return _cache[key];

    // 1) ¿Ya lo buscamos en una sesión anterior?
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefKey = _prefKey(key);
      if (prefs.containsKey(prefKey)) {
        final guardado = prefs.getString(prefKey);
        // String vacío = "ya se buscó, no se encontró nada" (evita
        // repetir la búsqueda a iTunes en cada apertura de la app).
        final resultado = (guardado != null && guardado.isNotEmpty) ? guardado : null;
        _cache[key] = resultado;
        return resultado;
      }
    } catch (_) {
      // Si falla la lectura, seguimos igual por red.
    }

    // 2) No estaba guardado: lo buscamos en iTunes, como antes.
    try {
      final term = Uri.encodeComponent('$artist $title');
      final url = Uri.parse(
        'https://itunes.apple.com/search?term=$term&entity=song&limit=1',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          var art = results.first['artworkUrl100'] as String?;
          // iTunes devuelve la miniatura de 100x100 por defecto;
          // pedimos una resolución más grande para que se vea nítida.
          art = art?.replaceAll('100x100bb', '600x600bb');
          _cache[key] = art;
          _guardar(key, art ?? '');
          return art;
        }
      }
    } catch (_) {
      // Sin internet o iTunes caído: seguimos con el fallback genérico.
    }

    _cache[key] = null;
    _guardar(key, ''); // marca "ya se buscó, no hay resultado"
    return null;
  }

  Future<void> _guardar(String key, String valor) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey(key), valor);
    } catch (_) {}
  }
}