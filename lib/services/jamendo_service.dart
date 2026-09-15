import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

/// Busca música en el catálogo de Jamendo — canciones completas con
/// licencia Creative Commons, de artistas independientes — y arma
/// objetos [Song] normales, listos para reproducir con el MISMO
/// reproductor de toda la app.
///
/// El audio nunca sale de Cacocapp ni abre el navegador o la web de
/// Jamendo: usamos su URL de streaming directo como fuente de audio
/// para tu propio `AudioPlayer`, exactamente igual que con las
/// canciones de tu Cloudflare R2. Una vez buscada, una canción de
/// Jamendo es indistinguible del resto: se puede favoritear, agregar
/// a una playlist, o descargar para escuchar offline sin código
/// aparte, porque para el resto de la app es un [Song] más.
///
/// Para usar esto hace falta un client_id GRATUITO de Jamendo:
/// 1. Entrá a https://devportal.jamendo.com y creá una cuenta (es
///    inmediato, a diferencia de Spotify/SoundCloud que requieren
///    aprobación manual).
/// 2. Registrá una "aplicación" (podés poner cualquier nombre, ej.
///    "Cacocapp"), aceptando los términos de uso de la API.
/// 3. Copiá el "Client ID" que te dan y pegalo abajo, reemplazando
///    _clientId.
class JamendoService {
  // Constructor privado: acepta un http.Client opcional para poder
  // testear esta clase sin red real (ver JamendoService.testable más
  // abajo). Si no se pasa ninguno (el caso normal de la app), se crea
  // un http.Client de verdad.
  JamendoService._({http.Client? client}) : _client = client ?? http.Client();

  /// Instancia real que usa el resto de la app (`JamendoService.instance`).
  static final JamendoService instance = JamendoService._();

  /// SOLO PARA TESTS: permite inyectar un http.Client falso/mockeado
  /// (ej. con el paquete `mocktail` o `http_mock_adapter`) para
  /// testear `buscar`/`buscarPorGenero` sin depender de la red.
  /// No usar esto en código de la app -- ahí siempre se usa `.instance`.
  factory JamendoService.testable(http.Client client) => JamendoService._(client: client);

  final http.Client _client;

  static const String _clientId = '519a1b23';

  static const String _baseUrl = 'https://api.jamendo.com/v3.0/tracks/';

  bool get configurado => _clientId != 'TU_CLIENT_ID' && _clientId.isNotEmpty;

  /// Géneros "featured" oficiales de Jamendo (confirmados en su propia
  /// documentación) — sirven para el parámetro `tags` y dan resultados
  /// mucho más relevantes que buscar la palabra del género como texto
  /// (ej. "house" como texto casi no aparece en títulos, pero
  /// tags=electronic sí trae música electrónica de verdad).
  static const Map<String, String> generos = {
    'Rock': 'rock',
    'Pop': 'pop',
    'Electrónica': 'electronic',
    'HipHop': 'hiphop',
    'Jazz': 'jazz',
    'Metal': 'metal',
    'Clásica': 'classical',
    'Chill': 'lounge',
    'Relajación': 'relaxation',
    'Cantautor': 'songwriter',
    'Bandas sonoras': 'soundtrack',
    'Mundo': 'world',
  };

  /// Ícono representativo de cada género, para que los chips de
  /// Descubrir se vean más que texto plano.
  static const Map<String, IconData> generosIconos = {
    'Rock': Icons.electric_bolt_rounded,
    'Pop': Icons.star_rounded,
    'Electrónica': Icons.graphic_eq_rounded,
    'HipHop': Icons.mic_rounded,
    'Jazz': Icons.piano_rounded,
    'Metal': Icons.bolt_rounded,
    'Clásica': Icons.music_note_rounded,
    'Chill': Icons.nightlight_round,
    'Relajación': Icons.spa_rounded,
    'Cantautor': Icons.edit_note_rounded,
    'Bandas sonoras': Icons.movie_rounded,
    'Mundo': Icons.public_rounded,
  };

  /// Color de acento de cada género (se usa como fondo del chip
  /// cuando está seleccionado), para diferenciarlos de un vistazo en
  /// vez de que todos se vean igual con el mismo amarillo genérico.
  static const Map<String, Color> generosColores = {
    'Rock': Color(0xFFB23B3B),
    'Pop': Color(0xFFD9962E),
    'Electrónica': Color(0xFF3B7FB2),
    'HipHop': Color(0xFF6E5233),
    'Jazz': Color(0xFF7A3E6E),
    'Metal': Color(0xFF4A4A4A),
    'Clásica': Color(0xFF8A5A3B),
    'Chill': Color(0xFF2E5C6B),
    'Relajación': Color(0xFF3E7A5E),
    'Cantautor': Color(0xFF9C4A2E),
    'Bandas sonoras': Color(0xFF3B3B7A),
    'Mundo': Color(0xFF2E7A6B),
  };

  Future<List<Song>> buscar(String consulta, {int limite = 30}) {
    if (consulta.trim().isEmpty) return Future.value([]);
    return _consultar({'search': consulta}, limite: limite);
  }

  /// Busca por género real (parámetro `tags` de Jamendo), no por texto
  /// — usar esto para los chips de género en vez de mandar el nombre
  /// del género como si fuera una búsqueda de texto libre.
  Future<List<Song>> buscarPorGenero(String tag, {int limite = 30}) {
    return _consultar({
      'tags': tag,
      'order': 'popularity_total', // trae primero lo más escuchado de ese género
    }, limite: limite);
  }

  Future<List<Song>> _consultar(Map<String, String> parametros, {required int limite}) async {
    if (!configurado) {
      throw Exception(
        'Falta configurar el client_id de Jamendo en jamendo_service.dart '
        '(conseguilo gratis en https://devportal.jamendo.com)',
      );
    }

    final url = Uri.parse(_baseUrl).replace(queryParameters: {
      'client_id': _clientId,
      'format': 'json',
      'limit': '$limite',
      'audioformat': 'mp32', // buena calidad, VBR
      ...parametros,
    });

    final respuesta = await _client.get(url).timeout(const Duration(seconds: 10));
    if (respuesta.statusCode != 200) {
      throw Exception('Jamendo respondió ${respuesta.statusCode}');
    }

    final data = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final resultados = (data['results'] as List?) ?? [];

    return resultados
        .map((item) => _construirSong(item as Map<String, dynamic>))
        .where((s) => s.url.isNotEmpty)
        .toList();
  }

  Song _construirSong(Map<String, dynamic> track) {
    final id = track['id']?.toString() ?? '';
    return Song(
      id: 'jamendo_$id',
      title: _limpiar(track['name'], 'Sin título'),
      artist: _limpiar(track['artist_name'], 'Artista independiente'),
      album: _limpiar(track['album_name'], 'Jamendo'),
      url: (track['audio'] as String?) ?? '',
      coverUrl: (track['image'] as String?) ?? '',
    );
  }

  String _limpiar(dynamic valor, String porDefecto) {
    final texto = (valor as String?)?.trim() ?? '';
    return texto.isEmpty ? porDefecto : texto;
  }
}