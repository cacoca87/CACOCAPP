/// Cómo se busca dentro de la biblioteca.
///
/// POR QUÉ NO ALCANZABA CON `toLowerCase().contains(...)`
///
/// Era lo que había, y en una biblioteca en castellano deja afuera
/// medio catálogo: **la tilde cuenta como otra letra**. Buscando
/// `corazon` no aparecía "Corazón", buscando `amen` no aparecía "Amén",
/// buscando `nino` no aparecía "El Niño".
///
/// Y es al revés de lo que conviene: escribir la tilde en el teclado
/// del celular cuesta más que no escribirla, así que lo natural es
/// justo lo que no funcionaba. Es un fallo que no se nota programando
/// --uno prueba con el nombre bien escrito-- y que en el uso diario
/// aparece todo el tiempo.
///
/// Además, ahora el orden de las palabras no importa: `stereo soda`
/// encuentra "Soda Stereo". Antes había que escribirlo tal cual estaba
/// guardado.
///
/// Esto no cambia nada de lo que ya funcionaba: todo lo que antes
/// aparecía sigue apareciendo. Solo aparece más.
library;

/// Letras con tilde, diéresis o virgulilla, y su equivalente sin nada.
/// Se escribe como dos textos alineados letra por letra porque así es
/// imposible que uno tenga una de más.
const _conMarca = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
const _sinMarca = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';

/// El mismo texto en minúsculas y sin tildes, listo para comparar.
String paraBuscar(String texto) {
  final resultado = StringBuffer();
  for (final letra in texto.toLowerCase().split('')) {
    final i = _conMarca.indexOf(letra);
    resultado.write(i == -1 ? letra : _sinMarca[i]);
  }
  return resultado.toString();
}

/// `true` si [consulta] se encuentra en alguno de los [campos].
///
/// Cada palabra de la consulta tiene que estar en alguna parte; el
/// orden no importa. Una consulta vacía encuentra todo.
bool coincideLaBusqueda(String consulta, List<String> campos) {
  final palabras = paraBuscar(consulta).split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (palabras.isEmpty) return true;

  final texto = campos.map(paraBuscar).join(' ');
  return palabras.every(texto.contains);
}

/// Los nombres distintos de [valores], sin los vacíos y en orden
/// alfabético.
///
/// Lo usan las grillas de Artistas y de Álbumes.
///
/// El orden ignora las tildes por el mismo motivo que la búsqueda: para
/// la computadora la "Á" no está cerca de la "A" --está después de la
/// "Z"--, así que "Ángel" caía al final de la lista. Cuando dos nombres
/// solo se diferencian en la tilde, decide el texto original, para que
/// el orden sea siempre el mismo y no dependa de cuál se leyó primero.
///
/// Los nombres se devuelven **tal cual vinieron**, sin recortarles los
/// espacios. Es a propósito: al tocar una tarjeta, la app busca las
/// canciones cuyo artista o álbum sea exactamente ese texto. Si acá se
/// devolviera recortado, un nombre con un espacio de más no coincidiría
/// con ninguna canción y la tarjeta abriría una lista vacía.
List<String> nombresOrdenados(Iterable<String> valores) {
  final unicos = <String>{};
  for (final v in valores) {
    // Los vacíos --y los de puros espacios-- armaban una tarjeta sin
    // nombre en la grilla. Pasa con los MP3 que no traen el dato, que
    // son muchos.
    if (v.trim().isNotEmpty) unicos.add(v);
  }
  final lista = unicos.toList();
  lista.sort((a, b) {
    final porTexto = paraBuscar(a).compareTo(paraBuscar(b));
    return porTexto != 0 ? porTexto : a.compareTo(b);
  });
  return lista;
}
