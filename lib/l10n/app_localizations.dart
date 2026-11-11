import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
  ];

  /// The app name. A brand: keep it untranslated.
  ///
  /// In en, this message translates to:
  /// **'WikiTree Viewer'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your family tree, one tap at a time.'**
  String get tagline;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Unofficial viewer. Family data comes from WikiTree.com and remains subject to their terms. Nothing is edited or stored on this device.'**
  String get disclaimer;

  /// No description provided for @loadingFamily.
  ///
  /// In en, this message translates to:
  /// **'Loading family…'**
  String get loadingFamily;

  /// No description provided for @lookupLabel.
  ///
  /// In en, this message translates to:
  /// **'Family code or link'**
  String get lookupLabel;

  /// No description provided for @lookupHelper.
  ///
  /// In en, this message translates to:
  /// **'For example Einstein-1, or paste a wikitree.com/wiki link'**
  String get lookupHelper;

  /// No description provided for @lookupClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get lookupClear;

  /// No description provided for @lookupSubmit.
  ///
  /// In en, this message translates to:
  /// **'Show family tree'**
  String get lookupSubmit;

  /// No description provided for @lookupBusy.
  ///
  /// In en, this message translates to:
  /// **'Looking up…'**
  String get lookupBusy;

  /// No description provided for @lookupPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste a link'**
  String get lookupPaste;

  /// No description provided for @lookupExamplePrompt.
  ///
  /// In en, this message translates to:
  /// **'First time here? Try the example to see how a tree looks.'**
  String get lookupExamplePrompt;

  /// Button that opens the example profile.
  ///
  /// In en, this message translates to:
  /// **'Try {code}'**
  String lookupTryExample(String code);

  /// Tooltip on the home button of the tree; jumps back to the person the tree started on.
  ///
  /// In en, this message translates to:
  /// **'Back to {name}'**
  String treeHomeTooltip(String name);

  /// Label of the buttons that load another generation, where WikiTree knows how many people are waiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more} other{{count} more}}'**
  String moreCount(int count);

  /// Label used when the count of people waiting could not be fetched.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreUnknown;

  /// No description provided for @shareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share this family'**
  String get shareTooltip;

  /// No description provided for @shareSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Share this family'**
  String get shareSheetTitle;

  /// No description provided for @shareWithApp.
  ///
  /// In en, this message translates to:
  /// **'Share with an app'**
  String get shareWithApp;

  /// No description provided for @shareWithAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Messages, email, WhatsApp and the rest'**
  String get shareWithAppSubtitle;

  /// No description provided for @shareCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy the link'**
  String get shareCopyLink;

  /// No description provided for @shareCopyLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste it wherever you like'**
  String get shareCopyLinkSubtitle;

  /// No description provided for @shareCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied. Paste it anywhere.'**
  String get shareCopied;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'This device can\'t share. Try copying the link.'**
  String get shareFailed;

  /// Subject line handed to the share sheet.
  ///
  /// In en, this message translates to:
  /// **'Family tree: {name}'**
  String shareSubject(String name);

  /// First line of a shared message, for somebody with known dates.
  ///
  /// In en, this message translates to:
  /// **'{name} ({lifeSpan}) on WikiTree'**
  String shareTitleWithDates(String name, String lifeSpan);

  /// First line of a shared message, for somebody whose dates are unknown.
  ///
  /// In en, this message translates to:
  /// **'{name} on WikiTree'**
  String shareTitle(String name);

  /// No description provided for @shareOpenIn.
  ///
  /// In en, this message translates to:
  /// **'Open in {app}: {link}'**
  String shareOpenIn(String app, String link);

  /// No description provided for @shareInstall.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have {app} yet? {url}'**
  String shareInstall(String app, String url);

  /// Shown in place of a name when WikiTree releases nothing about a person except their id.
  ///
  /// In en, this message translates to:
  /// **'Private profile'**
  String get privateProfile;

  /// Second line under a name in the tree whose profile is not public.
  ///
  /// In en, this message translates to:
  /// **'Not public'**
  String get notPublic;

  /// Full name of somebody who took a different surname later in life.
  ///
  /// In en, this message translates to:
  /// **'{name} (later {surname})'**
  String nameLater(String name, String surname);

  /// Years of birth and death. Keep the en dash between the placeholders.
  ///
  /// In en, this message translates to:
  /// **'{birth}–{death}'**
  String yearRange(int birth, int death);

  /// Abbreviation of 'born', used when somebody has no death date.
  ///
  /// In en, this message translates to:
  /// **'b. {year}'**
  String bornYear(int year);

  /// Abbreviation of 'died', used when the birth date is unknown.
  ///
  /// In en, this message translates to:
  /// **'d. {year}'**
  String diedYear(int year);

  /// No description provided for @datesUnknown.
  ///
  /// In en, this message translates to:
  /// **'Dates unknown'**
  String get datesUnknown;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// Abbreviation of 'married', followed by the marriage date.
  ///
  /// In en, this message translates to:
  /// **'m. {date}'**
  String married(String date);

  /// A marriage that ended, by divorce or by death.
  ///
  /// In en, this message translates to:
  /// **'m. {start}, ended {end}'**
  String marriedAndEnded(String start, String end);

  /// Screen-reader label for a photo or monogram.
  ///
  /// In en, this message translates to:
  /// **'{name}, {lifeSpan}'**
  String personSemantics(String name, String lifeSpan);

  /// Screen-reader suffix for the person the tree is centred on.
  ///
  /// In en, this message translates to:
  /// **'middle of the tree'**
  String get treeMiddleSemantics;

  /// Screen-reader suffix for a person whose profile WikiTree keeps hidden.
  ///
  /// In en, this message translates to:
  /// **'profile not public'**
  String get treeNotPublicSemantics;

  /// No description provided for @born.
  ///
  /// In en, this message translates to:
  /// **'Born'**
  String get born;

  /// No description provided for @died.
  ///
  /// In en, this message translates to:
  /// **'Died'**
  String get died;

  /// No description provided for @living.
  ///
  /// In en, this message translates to:
  /// **'Living'**
  String get living;

  /// No description provided for @notRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get notRecorded;

  /// No description provided for @ageAtDeath.
  ///
  /// In en, this message translates to:
  /// **'age {age}'**
  String ageAtDeath(int age);

  /// No description provided for @parents.
  ///
  /// In en, this message translates to:
  /// **'Parents'**
  String get parents;

  /// No description provided for @noParents.
  ///
  /// In en, this message translates to:
  /// **'No parents recorded on WikiTree'**
  String get noParents;

  /// No description provided for @spouses.
  ///
  /// In en, this message translates to:
  /// **'Spouses'**
  String get spouses;

  /// No description provided for @siblings.
  ///
  /// In en, this message translates to:
  /// **'Brothers and sisters'**
  String get siblings;

  /// No description provided for @halfSiblings.
  ///
  /// In en, this message translates to:
  /// **'Half-brothers and half-sisters'**
  String get halfSiblings;

  /// No description provided for @children.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children;

  /// No description provided for @noChildren.
  ///
  /// In en, this message translates to:
  /// **'No children recorded on WikiTree'**
  String get noChildren;

  /// No description provided for @openOnWikiTree.
  ///
  /// In en, this message translates to:
  /// **'Open on WikiTree'**
  String get openOnWikiTree;

  /// No description provided for @couldNotOpenWikiTree.
  ///
  /// In en, this message translates to:
  /// **'Could not open WikiTree.'**
  String get couldNotOpenWikiTree;

  /// No description provided for @privateProfileNotice.
  ///
  /// In en, this message translates to:
  /// **'WikiTree limits what it shares about this profile. Dates and places may be missing, and relatives may not be listed.'**
  String get privateProfileNotice;

  /// No description provided for @marriageEndedNote.
  ///
  /// In en, this message translates to:
  /// **'A marriage that ended is shown with its end date.'**
  String get marriageEndedNote;

  /// No description provided for @errorEmptyKey.
  ///
  /// In en, this message translates to:
  /// **'Enter a WikiTree ID or a profile link.'**
  String get errorEmptyKey;

  /// No description provided for @errorTooLongKey.
  ///
  /// In en, this message translates to:
  /// **'That\'s too long to be a WikiTree ID. It usually looks like Einstein-1.'**
  String get errorTooLongKey;

  /// No description provided for @errorNoIdFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find a WikiTree ID in that. Try something like Einstein-1.'**
  String get errorNoIdFound;

  /// No description provided for @errorAmbiguousKey.
  ///
  /// In en, this message translates to:
  /// **'That looks like more than one WikiTree ID. Please enter just one.'**
  String get errorAmbiguousKey;

  /// No description provided for @errorSpaceProfile.
  ///
  /// In en, this message translates to:
  /// **'That\'s a free-space page, not a person. This app shows people only.'**
  String get errorSpaceProfile;

  /// No description provided for @errorUnsupportedHost.
  ///
  /// In en, this message translates to:
  /// **'That link isn\'t a WikiTree profile link.'**
  String get errorUnsupportedHost;

  /// No description provided for @errorMalformedKey.
  ///
  /// In en, this message translates to:
  /// **'That WikiTree ID doesn\'t look right. Example: Einstein-1'**
  String get errorMalformedKey;

  /// No description provided for @hintPasteLink.
  ///
  /// In en, this message translates to:
  /// **'You can also paste a link like https://www.wikitree.com/wiki/Einstein-1'**
  String get hintPasteLink;

  /// No description provided for @hintLinkStart.
  ///
  /// In en, this message translates to:
  /// **'Links need to start with https://www.wikitree.com/wiki/'**
  String get hintLinkStart;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that person on WikiTree.'**
  String get errorNotFound;

  /// No description provided for @hintNotFound.
  ///
  /// In en, this message translates to:
  /// **'Check the code, or paste the profile link instead.'**
  String get hintNotFound;

  /// No description provided for @errorPrivate.
  ///
  /// In en, this message translates to:
  /// **'That profile is private.'**
  String get errorPrivate;

  /// No description provided for @hintPrivate.
  ///
  /// In en, this message translates to:
  /// **'WikiTree limits what is shared about living people.'**
  String get hintPrivate;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'WikiTree took too long to answer.'**
  String get errorTimeout;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach WikiTree.'**
  String get errorNetwork;

  /// No description provided for @hintNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection, then try again.'**
  String get hintNetwork;

  /// No description provided for @errorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'WikiTree asked us to slow down.'**
  String get errorRateLimit;

  /// No description provided for @hintRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Please wait a minute, then try again.'**
  String get hintRateLimit;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'WikiTree had a problem answering that.'**
  String get errorServer;

  /// No description provided for @hintServer.
  ///
  /// In en, this message translates to:
  /// **'This is usually temporary. Please try again.'**
  String get hintServer;

  /// No description provided for @errorParse.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read WikiTree\'s answer.'**
  String get errorParse;

  /// No description provided for @hintParse.
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get hintParse;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
