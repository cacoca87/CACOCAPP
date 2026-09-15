import 'package:share_plus/share_plus.dart';

/// Abre el selector nativo de "Compartir" de Android (el mismo que
/// usan Spotify/YouTube) para mandar lo que estás escuchando a
/// WhatsApp, X, Instagram, Telegram, etc. -- la app no elige a mano
/// una red social puntual, deja que el propio sistema muestre todas
/// las que el usuario tenga instaladas.
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  /// Comparte una canción de la biblioteca/Jamendo/descargas. A
  /// propósito NO se incluye la URL directa del archivo: para
  /// Drive/R2 esa URL permite descargar el MP3 completo, y compartirla
  /// sin querer regalaría copias del archivo a cualquiera que la
  /// reciba -- solo se comparte el texto promocional.
  Future<void> compartirCancion(
      {required String titulo, required String artista}) {
    return SharePlus.instance.share(
      ShareParams(
        text: '🎵 Estoy escuchando "$titulo" de $artista en Cacocapp',
      ),
    );
  }

  /// Comparte un video de YouTube que suena en Búsqueda Online. Acá sí
  /// se incluye el link real -- es la misma URL pública de YouTube
  /// (youtu.be/<id>), no algo que la app resuelve, así que no expone
  /// nada que la persona que lo recibe no pudiera buscar por su cuenta.
  Future<void> compartirVideoDeYoutube(
      {required String titulo, required String videoId}) {
    return SharePlus.instance.share(
      ShareParams(
        text:
            '🎵 Estoy escuchando "$titulo" en Cacocapp\nhttps://youtu.be/$videoId',
      ),
    );
  }
}
