import 'package:flutter/services.dart';

import '../../util/wikitree_id_case.dart';

/// Capitalises a WikiTree ID while it is typed.
///
/// The work itself is [capitaliseWikiTreeId]; this only keeps a pasted link out
/// of the way, because capitalising one would break it.
class WikiTreeIdCaseFormatter extends TextInputFormatter {
  const WikiTreeIdCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    // A link has its own spelling rules; capitalising it would break it.
    if (text.contains('://') || text.contains('/')) return newValue;

    final formatted = capitaliseWikiTreeId(text);
    if (formatted == text) return newValue;
    // The length never changes, so the cursor stays where the user left it.
    return newValue.copyWith(text: formatted);
  }
}
