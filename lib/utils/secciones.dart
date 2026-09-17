/// Los nombres de las secciones de la app.
///
/// POR QUÉ SON CONSTANTES Y NO TEXTOS SUELTOS
///
/// Estos textos no son solo lo que se lee en la barra lateral: son las
/// CLAVES con las que la app decide qué pantalla dibujar. La barra
/// lateral manda uno, y la pantalla principal lo compara con `==` para
/// elegir entre Estadísticas, Juegos, Noticias, Descubrir y las demás.
///
/// Estaban escritos a mano 68 veces entre todos los archivos. Eso
/// significa que una sola letra distinta en cualquiera de los dos
/// lados --el que manda o el que compara-- hacía que esa sección
/// dejara de abrirse. Y sin ningún aviso: no es un error de
/// programación, simplemente dos textos que no coinciden. Tocás
/// "Álbumes" y no pasa nada.
///
/// El riesgo no es teórico: [albumes] y [estadisticas] llevan acento y
/// [musicaDescargada] lleva acento y dos palabras. Son justo las que
/// más fácil se escriben mal.
///
/// Escritas una sola vez, el editor completa el nombre y un error de
/// tipeo deja de compilar en vez de romper la app en silencio.
library;

/// La pantalla de Inicio y la biblioteca. En la barra lateral se
/// muestra como "Inicio", pero la clave es esta -- ver el parámetro
/// `etiqueta` de `BarraLateral._buildItemMenu`.
const String seccionBiblioteca = 'Tu Biblioteca';

const String seccionPlaylists = 'Playlists';
const String seccionArtistas = 'Artistas';
const String seccionAlbumes = 'Álbumes';
const String seccionEstadisticas = 'Estadísticas';
const String seccionJuegos = 'Juegos';
const String seccionNoticias = 'Noticias';
const String seccionRecomendaciones = 'Recomendaciones';
const String seccionDescubrir = 'Descubrir';
const String seccionBuscadorOnline = 'Buscador Online';
const String seccionMusicaDescargada = 'Música Descargada';
