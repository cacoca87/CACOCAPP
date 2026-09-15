# MiMúsica — App tipo Spotify (Flutter)

App base de reproductor de música con:
- ▶️ Play / Pause / Siguiente / Anterior
- 🎚️ Barra de progreso (seek)
- 📝 Letras sincronizadas con el tiempo de la canción
- ❤️ Favoritos
- 🎵 Playlists propias (crear, agregar y quitar canciones)
- Compatible con Android e iOS desde el mismo código

## Requisitos previos

1. Instalar Flutter: https://docs.flutter.dev/get-started/install
2. Verifica que todo esté bien configurado:
   ```
   flutter doctor
   ```
   Esto te dirá si falta Android Studio, Xcode (solo en Mac, para iOS), etc.

## Cómo correr el proyecto

1. Descarga/copia esta carpeta `musicapp` a tu computadora.
2. Abre una terminal dentro de la carpeta y ejecuta:
   ```
   flutter pub get
   ```
   Esto descarga las dependencias (just_audio, provider, etc).
3. Conecta un celular o abre un emulador (Android Studio o Xcode).
4. Ejecuta:
   ```
   flutter run
   ```

## Estructura del proyecto

```
lib/
  main.dart                  -> punto de entrada
  models/
    song.dart                -> modelo de canción + letras
    playlist.dart             -> modelo de playlist
  providers/
    player_provider.dart      -> lógica del reproductor (just_audio)
    playlist_provider.dart    -> lógica de playlists y favoritos
  screens/
    home_screen.dart          -> biblioteca principal
    playlists_screen.dart     -> pantalla de playlists
    player_screen.dart        -> reproductor a pantalla completa + letras
  widgets/
    mini_player.dart          -> barra de reproducción mini (abajo)
  data/
    sample_data.dart          -> canciones de ejemplo (reemplázalas por las tuyas)
```

## Cómo agregar tus propias canciones

Edita `lib/data/sample_data.dart`. Cada canción necesita:
- Un `audioUrl` (puede ser una URL de streaming o un archivo local en `assets/`)
- Una lista `lyrics` con el texto y el momento (`Duration`) en que aparece cada línea

Para usar archivos locales en vez de URLs:
1. Coloca tus mp3 en una carpeta `assets/audio/`
2. Decláralos en `pubspec.yaml` bajo `flutter: assets:`
3. Usa `AudioSource.asset('assets/audio/cancion.mp3')` en vez de `setUrl()` dentro de `player_provider.dart`

## Próximos pasos sugeridos

- **Persistencia real**: usar `shared_preferences` (ya incluido) o una base de datos como Hive/SQLite para que las playlists no se pierdan al cerrar la app.
- **Backend propio**: si quieres subir canciones y compartir playlists entre usuarios, necesitarás un backend (Firebase es la opción más rápida de integrar).
- **Descarga/streaming**: revisar límites de derechos de autor si planeas distribuir música de terceros.
- **Autenticación**: Firebase Auth o Supabase si quieres cuentas de usuario.

## Nota importante sobre distribución

Para publicar en Google Play y Apple App Store necesitarás:
- Cuenta de desarrollador de Google Play (pago único ~$25 USD)
- Cuenta de desarrollador de Apple (suscripción anual ~$99 USD, y una Mac con Xcode para compilar la versión iOS)
