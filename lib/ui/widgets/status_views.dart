import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// A plain-language problem message with an optional second line of advice.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.hint = ''});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hint.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen "working on it" state used while a person is being fetched.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  /// Optional wording; defaults to a translated "Loading family…".
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 20),
          Text(
            message ?? AppLocalizations.of(context).loadingFamily,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
