// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'WikiTree Viewer';

  @override
  String get tagline => 'Sua árvore genealógica, um toque de cada vez.';

  @override
  String get disclaimer =>
      'Visualizador não oficial. Os dados de família vêm do WikiTree.com e continuam sujeitos aos termos deles. Nada é editado ou guardado neste dispositivo.';

  @override
  String get loadingFamily => 'Carregando família…';

  @override
  String get lookupLabel => 'Código de família ou link';

  @override
  String get lookupClear => 'Limpar';

  @override
  String get lookupSubmit => 'Ver árvore genealógica';

  @override
  String get lookupBusy => 'Procurando…';

  @override
  String get lookupPaste => 'Colar um link';

  @override
  String get lookupExamplePrompt =>
      'Primeira vez aqui? Experimente um exemplo para ver como é uma árvore.';

  @override
  String lookupTryExample(String code) {
    return 'Experimentar $code';
  }

  @override
  String lookupOrTry(String code) {
    return 'ou $code';
  }

  @override
  String treeHomeTooltip(String name) {
    return 'Voltar para $name';
  }

  @override
  String get treeTipsTitle => 'Como usar a árvore';

  @override
  String get treeTipsSwipe => 'Arraste com um dedo para se mover pela árvore';

  @override
  String get treeTipsZoom => 'Aproxime ou afaste dois dedos para ampliar';

  @override
  String get treeTipsTap => 'Toque em uma pessoa para colocá-la no centro';

  @override
  String get treeTipsLongPress =>
      'Mantenha uma pessoa pressionada para ver os detalhes';

  @override
  String get treeTipsDismiss => 'Entendi';

  @override
  String moreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count a mais',
      one: '1 a mais',
    );
    return '$_temp0';
  }

  @override
  String get moreUnknown => 'Mais';

  @override
  String get shareTooltip => 'Compartilhar esta família';

  @override
  String get shareSheetTitle => 'Compartilhar esta família';

  @override
  String get shareWithApp => 'Compartilhar com um app';

  @override
  String get shareWithAppSubtitle => 'Mensagens, e-mail, WhatsApp e outros';

  @override
  String get shareCopyLink => 'Copiar o link';

  @override
  String get shareCopyLinkSubtitle => 'Cole onde quiser';

  @override
  String get shareCopied => 'Link copiado. Cole onde quiser.';

  @override
  String get shareFailed =>
      'Este dispositivo não pode compartilhar. Tente copiar o link.';

  @override
  String shareSubject(String name) {
    return 'Árvore genealógica: $name';
  }

  @override
  String shareTitleWithDates(
    String name,
    String lifeSpan,
    String app,
    String link,
  ) {
    return 'Ver a árvore genealógica de $name ($lifeSpan) no $app: $link';
  }

  @override
  String shareTitle(String name, String app, String link) {
    return 'Ver a árvore genealógica de $name no $app: $link';
  }

  @override
  String shareInstall(String app, String url) {
    return 'Ainda não tem o $app? Obtenha aqui: $url';
  }

  @override
  String get privateProfile => 'Perfil privado';

  @override
  String get notPublic => 'Não público';

  @override
  String nameLater(String name, String surname) {
    return '$name (depois $surname)';
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
  String get datesUnknown => 'Datas desconhecidas';

  @override
  String get unknown => 'Desconhecido';

  @override
  String married(String date) {
    return 'c. $date';
  }

  @override
  String marriedAndEnded(String start, String end) {
    return 'c. $start, terminou $end';
  }

  @override
  String personSemantics(String name, String lifeSpan) {
    return '$name, $lifeSpan';
  }

  @override
  String get treeMiddleSemantics => 'centro da árvore';

  @override
  String get treeNotPublicSemantics => 'perfil não público';

  @override
  String get born => 'Nascimento';

  @override
  String get died => 'Falecimento';

  @override
  String get living => 'Vivo';

  @override
  String get notRecorded => 'Não registrado';

  @override
  String ageAtDeath(int age) {
    return '$age anos';
  }

  @override
  String get parents => 'Pais';

  @override
  String get noParents => 'Nenhum pai ou mãe registrado no WikiTree';

  @override
  String get spouses => 'Cônjuges';

  @override
  String get siblings => 'Irmãos e irmãs';

  @override
  String get halfSiblings => 'Meios-irmãos e meias-irmãs';

  @override
  String get children => 'Filhos';

  @override
  String get noChildren => 'Nenhum filho registrado no WikiTree';

  @override
  String get openOnWikiTree => 'Abrir no WikiTree';

  @override
  String get couldNotOpenWikiTree => 'Não foi possível abrir o WikiTree.';

  @override
  String get privateProfileNotice =>
      'O WikiTree limita o que compartilha deste perfil. Datas e locais podem faltar, e parentes podem não estar listados.';

  @override
  String get marriageEndedNote =>
      'Um casamento encerrado aparece com a data de término.';

  @override
  String get errorEmptyKey => 'Digite um ID do WikiTree ou um link de perfil.';

  @override
  String get errorTooLongKey =>
      'Isso é longo demais para um ID do WikiTree. Normalmente parece Einstein-1.';

  @override
  String get errorNoIdFound =>
      'Não encontramos um ID do WikiTree aí. Tente algo como Einstein-1.';

  @override
  String get errorAmbiguousKey =>
      'Parece haver mais de um ID do WikiTree. Digite apenas um.';

  @override
  String get errorSpaceProfile =>
      'É uma página livre, não uma pessoa. Este app mostra apenas pessoas.';

  @override
  String get errorUnsupportedHost =>
      'Esse link não é um link de perfil do WikiTree.';

  @override
  String get errorMalformedKey =>
      'Esse ID do WikiTree não parece certo. Exemplo: Einstein-1';

  @override
  String get hintPasteLink =>
      'Você também pode colar um link como https://www.wikitree.com/wiki/Einstein-1';

  @override
  String get hintLinkStart =>
      'Os links precisam começar com https://www.wikitree.com/wiki/';

  @override
  String get errorNotFound => 'Não encontramos essa pessoa no WikiTree.';

  @override
  String get hintNotFound => 'Verifique o código ou cole o link do perfil.';

  @override
  String get errorPrivate => 'Esse perfil é privado.';

  @override
  String get hintPrivate =>
      'O WikiTree limita o que é compartilhado sobre pessoas vivas.';

  @override
  String get errorTimeout => 'O WikiTree demorou demais para responder.';

  @override
  String get errorNetwork => 'Não é possível acessar o WikiTree.';

  @override
  String get hintNetwork =>
      'Verifique sua conexão com a internet e tente novamente.';

  @override
  String get errorRateLimit => 'O WikiTree pediu para diminuirmos o ritmo.';

  @override
  String get hintRateLimit => 'Aguarde um minuto e tente novamente.';

  @override
  String get errorServer => 'O WikiTree teve um problema ao responder.';

  @override
  String get hintServer => 'Isso costuma ser temporário. Tente novamente.';

  @override
  String get errorParse => 'Não conseguimos ler a resposta do WikiTree.';

  @override
  String get hintParse => 'Tente novamente em instantes.';
}
