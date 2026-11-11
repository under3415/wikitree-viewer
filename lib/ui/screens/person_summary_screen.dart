import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/person.dart';
import '../../data/wikitree_repository.dart';
import '../../l10n/app_localizations.dart';
import '../format/person_text.dart';
import '../widgets/photo_avatar.dart';

/// The immediate family of the starting person.
///
/// This is the screen the tree view grows out of: it proves the data pipeline
/// end to end and doubles as the "details" surface for a person.
class PersonSummaryScreen extends StatelessWidget {
  const PersonSummaryScreen({super.key, required this.bundle});

  final FocusBundle bundle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final text = PersonText.of(context);
    final focus = bundle.focus;
    final age = focus.ageAtDeath;

    return Scaffold(
      appBar: AppBar(
        title: Text(text.displayName(focus), overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          _PersonHeader(person: focus),
          if (focus.isLimited) ...<Widget>[
            const SizedBox(height: 16),
            const _PrivateNotice(),
          ],
          const SizedBox(height: 20),
          _FactRow(
            icon: Icons.cake_outlined,
            label: l10n.born,
            value: text.birthDescription(focus),
            detail: focus.birthLocation,
          ),
          const SizedBox(height: 12),
          _FactRow(
            icon: Icons.local_florist_outlined,
            label: focus.isLiving ? l10n.living : l10n.died,
            value: focus.isLiving
                ? l10n.notRecorded
                : text.deathDescription(focus),
            detail: focus.deathLocation,
            trailing: focus.isLiving || age == null
                ? null
                : l10n.ageAtDeath(age),
          ),
          const SizedBox(height: 24),
          _PeopleSection(
            title: l10n.parents,
            people: bundle.parents,
            emptyLabel: l10n.noParents,
          ),
          _SpouseSection(spouses: bundle.spouses),
          _PeopleSection(
            title: l10n.siblings,
            people: bundle.siblings,
            emptyLabel: '',
          ),
          _PeopleSection(
            title: l10n.halfSiblings,
            people: bundle.halfSiblings,
            emptyLabel: '',
          ),
          _PeopleSection(
            title: l10n.children,
            people: bundle.children,
            emptyLabel: l10n.noChildren,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openProfile(context, focus),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.openOnWikiTree),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.disclaimer,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProfile(BuildContext context, Person person) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final opened = await launchUrl(
      Uri.parse(person.profileUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.couldNotOpenWikiTree)),
      );
    }
  }
}

class _PersonHeader extends StatelessWidget {
  const _PersonHeader({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = PersonText.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          PhotoAvatar(person: person, size: 88),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(text.fullName(person), style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  text.lifeSpan(person),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  person.wikiTreeId,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateNotice extends StatelessWidget {
  const _PrivateNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.lock_outline, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.privateProfileNotice,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detailText = detail;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: scheme.onSurfaceVariant),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                ),
              ),
              Text(value, style: theme.textTheme.bodyLarge),
              if (detailText != null && detailText.isNotEmpty)
                Text(
                  detailText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({
    required this.title,
    required this.people,
    required this.emptyLabel,
  });

  final String title;
  final List<Person> people;

  /// When empty, the whole section is hidden; when set, it is shown with this
  /// message so "no parents recorded" is visible rather than ambiguous.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty && emptyLabel.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              if (people.isNotEmpty)
                Text(
                  '${people.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (people.isEmpty)
            Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ...people.map((person) => _RelativeTile(person: person)),
        ],
      ),
    );
  }
}

class _SpouseSection extends StatelessWidget {
  const _SpouseSection({required this.spouses});

  final List<SpouseLink> spouses;

  @override
  Widget build(BuildContext context) {
    if (spouses.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final text = PersonText.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.spouses, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...spouses.map(
            (link) => _RelativeTile(
              person: link.person,
              caption: text.marriageDescription(link),
            ),
          ),
          if (spouses.any((link) => link.marriageEnded))
            Text(
              l10n.marriageEndedNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _RelativeTile extends StatelessWidget {
  const _RelativeTile({required this.person, this.caption = ''});

  final Person person;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = PersonText.of(context);
    final lifeSpan = text.lifeSpan(person);
    final secondLine = caption.isEmpty ? lifeSpan : '$caption \u00B7 $lifeSpan';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          PhotoAvatar(person: person, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text.displayName(person),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  secondLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
