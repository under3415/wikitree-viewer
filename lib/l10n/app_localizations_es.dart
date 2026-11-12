// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'WikiTree Viewer';

  @override
  String get tagline => 'Tu árbol familiar, un toque a la vez.';

  @override
  String get disclaimer =>
      'Visor no oficial. Los datos familiares provienen de WikiTree.com y siguen sujetos a sus términos. En este dispositivo no se edita ni se guarda nada.';

  @override
  String get loadingFamily => 'Cargando familia…';

  @override
  String get lookupLabel => 'Código familiar o enlace';

  @override
  String get lookupClear => 'Borrar';

  @override
  String get lookupSubmit => 'Ver árbol familiar';

  @override
  String get lookupBusy => 'Buscando…';

  @override
  String get lookupPaste => 'Pegar un enlace';

  @override
  String get lookupExamplePrompt =>
      '¿Primera vez aquí? Prueba un ejemplo para ver cómo es un árbol.';

  @override
  String lookupTryExample(String code) {
    return 'Probar $code';
  }

  @override
  String lookupOrTry(String code) {
    return 'o $code';
  }

  @override
  String treeHomeTooltip(String name) {
    return 'Volver a $name';
  }

  @override
  String get treeTipsTitle => 'Cómo usar el árbol';

  @override
  String get treeTipsSwipe => 'Arrastra con un dedo para moverte por el árbol';

  @override
  String get treeTipsZoom => 'Pellizca o separa dos dedos para hacer zoom';

  @override
  String get treeTipsTap => 'Toca a una persona para ponerla en el centro';

  @override
  String get treeTipsLongPress =>
      'Mantén pulsada una persona para ver sus datos';

  @override
  String get treeTipsDismiss => 'Entendido';

  @override
  String moreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count más',
      one: '1 más',
    );
    return '$_temp0';
  }

  @override
  String get moreUnknown => 'Más';

  @override
  String get shareTooltip => 'Compartir esta familia';

  @override
  String get shareSheetTitle => 'Compartir esta familia';

  @override
  String get shareWithApp => 'Compartir con una app';

  @override
  String get shareWithAppSubtitle => 'Mensajes, correo, WhatsApp y demás';

  @override
  String get shareCopyLink => 'Copiar el enlace';

  @override
  String get shareCopyLinkSubtitle => 'Pégalo donde quieras';

  @override
  String get shareCopied => 'Enlace copiado. Pégalo donde quieras.';

  @override
  String get shareFailed =>
      'Este dispositivo no puede compartir. Intenta copiar el enlace.';

  @override
  String shareSubject(String name) {
    return 'Árbol familiar: $name';
  }

  @override
  String shareTitleWithDates(
    String name,
    String lifeSpan,
    String app,
    String link,
  ) {
    return 'Ver el árbol familiar de $name ($lifeSpan) en $app: $link';
  }

  @override
  String shareTitle(String name, String app, String link) {
    return 'Ver el árbol familiar de $name en $app: $link';
  }

  @override
  String shareInstall(String app, String url) {
    return '¿Aún no tienes $app? Consíguela aquí: $url';
  }

  @override
  String get privateProfile => 'Perfil privado';

  @override
  String get notPublic => 'No público';

  @override
  String nameLater(String name, String surname) {
    return '$name (después $surname)';
  }

  @override
  String yearRange(int birth, int death) {
    return '$birth–$death';
  }

  @override
  String bornYear(int year) {
    return 'n. $year';
  }

  @override
  String diedYear(int year) {
    return 'f. $year';
  }

  @override
  String get datesUnknown => 'Fechas desconocidas';

  @override
  String get unknown => 'Desconocido';

  @override
  String married(String date) {
    return 'c. $date';
  }

  @override
  String marriedAndEnded(String start, String end) {
    return 'c. $start, terminó $end';
  }

  @override
  String personSemantics(String name, String lifeSpan) {
    return '$name, $lifeSpan';
  }

  @override
  String get treeMiddleSemantics => 'centro del árbol';

  @override
  String get treeNotPublicSemantics => 'perfil no público';

  @override
  String get born => 'Nacimiento';

  @override
  String get died => 'Fallecimiento';

  @override
  String get living => 'Vivo';

  @override
  String get notRecorded => 'No registrado';

  @override
  String ageAtDeath(int age) {
    return '$age años';
  }

  @override
  String get parents => 'Padres';

  @override
  String get noParents => 'No hay padres registrados en WikiTree';

  @override
  String get spouses => 'Cónyuges';

  @override
  String get siblings => 'Hermanos y hermanas';

  @override
  String get halfSiblings => 'Medios hermanos y medias hermanas';

  @override
  String get children => 'Hijos';

  @override
  String get noChildren => 'No hay hijos registrados en WikiTree';

  @override
  String get openOnWikiTree => 'Abrir en WikiTree';

  @override
  String get couldNotOpenWikiTree => 'No se pudo abrir WikiTree.';

  @override
  String get privateProfileNotice =>
      'WikiTree limita lo que comparte de este perfil. Pueden faltar fechas y lugares, y es posible que no aparezcan los familiares.';

  @override
  String get marriageEndedNote =>
      'Un matrimonio que terminó se muestra con su fecha de fin.';

  @override
  String get errorEmptyKey =>
      'Introduce un ID de WikiTree o un enlace de perfil.';

  @override
  String get errorTooLongKey =>
      'Eso es demasiado largo para un ID de WikiTree. Normalmente tiene la forma Einstein-1.';

  @override
  String get errorNoIdFound =>
      'No encontramos ningún ID de WikiTree ahí. Prueba con algo como Einstein-1.';

  @override
  String get errorAmbiguousKey =>
      'Parece haber más de un ID de WikiTree. Introduce solo uno.';

  @override
  String get errorSpaceProfile =>
      'Es una página libre, no una persona. Esta app solo muestra personas.';

  @override
  String get errorUnsupportedHost =>
      'Ese enlace no es un enlace de perfil de WikiTree.';

  @override
  String get errorMalformedKey =>
      'Ese ID de WikiTree no parece correcto. Ejemplo: Einstein-1';

  @override
  String get hintPasteLink =>
      'También puedes pegar un enlace como https://www.wikitree.com/wiki/Einstein-1';

  @override
  String get hintLinkStart =>
      'Los enlaces deben empezar por https://www.wikitree.com/wiki/';

  @override
  String get errorNotFound => 'No encontramos a esa persona en WikiTree.';

  @override
  String get hintNotFound => 'Revisa el código o pega el enlace del perfil.';

  @override
  String get errorPrivate => 'Ese perfil es privado.';

  @override
  String get hintPrivate =>
      'WikiTree limita lo que se comparte sobre personas vivas.';

  @override
  String get errorTimeout => 'WikiTree tardó demasiado en responder.';

  @override
  String get errorNetwork => 'No se puede conectar con WikiTree.';

  @override
  String get hintNetwork =>
      'Comprueba tu conexión a internet e inténtalo de nuevo.';

  @override
  String get errorRateLimit => 'WikiTree nos pidió que bajáramos el ritmo.';

  @override
  String get hintRateLimit => 'Espera un minuto e inténtalo de nuevo.';

  @override
  String get errorServer => 'WikiTree tuvo un problema al responder.';

  @override
  String get hintServer => 'Suele ser temporal. Inténtalo de nuevo.';

  @override
  String get errorParse => 'No pudimos leer la respuesta de WikiTree.';

  @override
  String get hintParse => 'Inténtalo de nuevo en un momento.';
}
