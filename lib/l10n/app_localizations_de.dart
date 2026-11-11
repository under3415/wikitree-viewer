// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'WikiTree Viewer';

  @override
  String get tagline => 'Ihr Familienstammbaum, Tipp für Tipp.';

  @override
  String get disclaimer =>
      'Inoffizieller Betrachter. Die Familiendaten stammen von WikiTree.com und unterliegen weiterhin deren Bedingungen. Auf diesem Gerät wird nichts bearbeitet und nichts gespeichert.';

  @override
  String get loadingFamily => 'Familie wird geladen…';

  @override
  String get lookupLabel => 'Familiencode oder Link';

  @override
  String get lookupHelper =>
      'Zum Beispiel Einstein-1, oder einen Link auf wikitree.com/wiki einfügen';

  @override
  String get lookupClear => 'Leeren';

  @override
  String get lookupSubmit => 'Stammbaum anzeigen';

  @override
  String get lookupBusy => 'Wird gesucht…';

  @override
  String get lookupPaste => 'Link einfügen';

  @override
  String get lookupExamplePrompt =>
      'Zum ersten Mal hier? Probieren Sie das Beispiel aus, um zu sehen, wie ein Stammbaum aussieht.';

  @override
  String lookupTryExample(String code) {
    return '$code ausprobieren';
  }

  @override
  String treeHomeTooltip(String name) {
    return 'Zurück zu $name';
  }

  @override
  String moreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere Personen',
      one: '1 weitere Person',
    );
    return '$_temp0';
  }

  @override
  String get moreUnknown => 'Mehr';

  @override
  String get shareTooltip => 'Diese Familie teilen';

  @override
  String get shareSheetTitle => 'Diese Familie teilen';

  @override
  String get shareWithApp => 'Mit einer App teilen';

  @override
  String get shareWithAppSubtitle => 'Nachrichten, E-Mail, WhatsApp und andere';

  @override
  String get shareCopyLink => 'Link kopieren';

  @override
  String get shareCopyLinkSubtitle => 'Fügen Sie ihn ein, wo Sie möchten';

  @override
  String get shareCopied => 'Link kopiert. Fügen Sie ihn ein, wo Sie möchten.';

  @override
  String get shareFailed =>
      'Dieses Gerät kann nicht teilen. Versuchen Sie, den Link zu kopieren.';

  @override
  String shareSubject(String name) {
    return 'Stammbaum: $name';
  }

  @override
  String shareTitleWithDates(String name, String lifeSpan) {
    return '$name ($lifeSpan) auf WikiTree';
  }

  @override
  String shareTitle(String name) {
    return '$name auf WikiTree';
  }

  @override
  String shareOpenIn(String app, String link) {
    return 'In $app öffnen: $link';
  }

  @override
  String shareInstall(String app, String url) {
    return '$app noch nicht installiert? $url';
  }

  @override
  String get privateProfile => 'Privates Profil';

  @override
  String get notPublic => 'Nicht öffentlich';

  @override
  String nameLater(String name, String surname) {
    return '$name (später $surname)';
  }

  @override
  String yearRange(int birth, int death) {
    return '$birth–$death';
  }

  @override
  String bornYear(int year) {
    return 'geb. $year';
  }

  @override
  String diedYear(int year) {
    return 'gest. $year';
  }

  @override
  String get datesUnknown => 'Daten unbekannt';

  @override
  String get unknown => 'Unbekannt';

  @override
  String married(String date) {
    return 'verh. $date';
  }

  @override
  String marriedAndEnded(String start, String end) {
    return 'verh. $start, beendet $end';
  }

  @override
  String personSemantics(String name, String lifeSpan) {
    return '$name, $lifeSpan';
  }

  @override
  String get treeMiddleSemantics => 'Mitte des Stammbaums';

  @override
  String get treeNotPublicSemantics => 'Profil nicht öffentlich';

  @override
  String get born => 'Geboren';

  @override
  String get died => 'Gestorben';

  @override
  String get living => 'Lebend';

  @override
  String get notRecorded => 'Nicht erfasst';

  @override
  String ageAtDeath(int age) {
    return 'Alter $age';
  }

  @override
  String get parents => 'Eltern';

  @override
  String get noParents => 'Keine Eltern auf WikiTree erfasst';

  @override
  String get spouses => 'Ehepartner';

  @override
  String get siblings => 'Brüder und Schwestern';

  @override
  String get halfSiblings => 'Halbbrüder und Halbschwestern';

  @override
  String get children => 'Kinder';

  @override
  String get noChildren => 'Keine Kinder auf WikiTree erfasst';

  @override
  String get openOnWikiTree => 'Auf WikiTree öffnen';

  @override
  String get couldNotOpenWikiTree => 'WikiTree konnte nicht geöffnet werden.';

  @override
  String get privateProfileNotice =>
      'WikiTree beschränkt, was zu diesem Profil geteilt wird. Daten und Orte können fehlen, Angehörige möglicherweise nicht aufgeführt sein.';

  @override
  String get marriageEndedNote =>
      'Eine beendete Ehe wird mit ihrem Enddatum angezeigt.';

  @override
  String get errorEmptyKey =>
      'Geben Sie eine WikiTree-ID oder einen Profil-Link ein.';

  @override
  String get errorTooLongKey =>
      'Das ist zu lang für eine WikiTree-ID. Sie sieht meist wie Einstein-1 aus.';

  @override
  String get errorNoIdFound =>
      'Darin war keine WikiTree-ID zu finden. Versuchen Sie etwa Einstein-1.';

  @override
  String get errorAmbiguousKey =>
      'Das sieht nach mehr als einer WikiTree-ID aus. Bitte geben Sie nur eine ein.';

  @override
  String get errorSpaceProfile =>
      'Das ist eine freie Seite, keine Person. Diese App zeigt nur Personen.';

  @override
  String get errorUnsupportedHost =>
      'Dieser Link ist kein WikiTree-Profil-Link.';

  @override
  String get errorMalformedKey =>
      'Diese WikiTree-ID sieht nicht richtig aus. Beispiel: Einstein-1';

  @override
  String get hintPasteLink =>
      'Sie können auch einen Link wie https://www.wikitree.com/wiki/Einstein-1 einfügen';

  @override
  String get hintLinkStart =>
      'Links müssen mit https://www.wikitree.com/wiki/ beginnen';

  @override
  String get errorNotFound =>
      'Wir konnten diese Person auf WikiTree nicht finden.';

  @override
  String get hintNotFound =>
      'Prüfen Sie den Code oder fügen Sie stattdessen den Profil-Link ein.';

  @override
  String get errorPrivate => 'Dieses Profil ist privat.';

  @override
  String get hintPrivate =>
      'WikiTree beschränkt, was über lebende Personen geteilt wird.';

  @override
  String get errorTimeout => 'WikiTree hat zu lange nicht geantwortet.';

  @override
  String get errorNetwork => 'WikiTree ist nicht erreichbar.';

  @override
  String get hintNetwork =>
      'Prüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.';

  @override
  String get errorRateLimit => 'WikiTree hat uns gebeten, langsamer zu machen.';

  @override
  String get hintRateLimit =>
      'Bitte warten Sie eine Minute und versuchen Sie es erneut.';

  @override
  String get errorServer => 'Bei WikiTree ist ein Problem aufgetreten.';

  @override
  String get hintServer =>
      'Das ist meist vorübergehend. Bitte versuchen Sie es erneut.';

  @override
  String get errorParse => 'Wir konnten WikiTrees Antwort nicht lesen.';

  @override
  String get hintParse => 'Bitte versuchen Sie es gleich noch einmal.';
}
