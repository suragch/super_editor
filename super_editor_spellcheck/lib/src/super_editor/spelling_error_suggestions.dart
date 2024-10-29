import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor_spellcheck/src/super_editor/spell_checker_popover_controller.dart';

/// Spelling error correction suggestions for all mis-spelled words within
/// a [Document].
///
/// A [SpellingErrorSuggestions] is a repository for spelling error suggestions
/// shared between the [Document], [Editor], overlays, etc.
class SpellingErrorSuggestions with ChangeNotifier implements Editable {
  /// A map from nodes to spelling error suggestions.
  ///
  /// Each spelling error suggestion is a map from the text range of the mis-spelled word
  /// to the suggested replacements for that word.
  final _suggestions = <String, Map<TextRange, SpellingErrorSuggestion>>{};

  /// Returns spelling correction suggestions for the word at the given [offset],
  /// or `null` if there's no spelling error at the given [offset], or no suggestions
  /// for the mis-spelled word at the given [offset].
  SpellingErrorSuggestion? getSuggestionsAtTextOffset(String nodeId, int offset) {
    final suggestionsForNode = _suggestions[nodeId];
    if (suggestionsForNode == null) {
      return null;
    }

    final matchingRanges = suggestionsForNode.keys.where((range) => range.start <= offset && range.end >= offset);
    if (matchingRanges.isEmpty) {
      return null;
    }
    if (matchingRanges.length > 1) {
      // It shouldn't be possible to have multiple spelling errors at the same
      // text offset. We don't know what to do. Fizzle.
      return null;
    }

    final wordRange = matchingRanges.first;
    return suggestionsForNode[wordRange];
  }

  /// Returns suggestions for the mis-spelled [word], which occupies the given [textRange],
  /// within a node with the given [nodeId].
  ///
  /// If the given mis-spelled [word] doesn't exist in [textRange], `null` is returned.
  ///
  /// If the given mis-spelled [word] isn't mis-spelled, or the spell checker has
  /// no suggestions, then `null` is returned.
  ///
  /// If the spelling suggestions are still being obtained from the spell checker,
  /// `null` is returned.
  SpellingErrorSuggestion? getSuggestionsForWord(String nodeId, TextRange range) {
    _suggestions[nodeId] ??= <TextRange, SpellingErrorSuggestion>{};
    return _suggestions[nodeId]![range];
  }

  /// Replaces all existing spelling suggestions for the node with the given [nodeId] with
  /// the given [spellingSuggestions].
  void putSuggestions(String nodeId, Map<TextRange, SpellingErrorSuggestion> spellingSuggestions) {
    _suggestions[nodeId] ??= <TextRange, SpellingErrorSuggestion>{};
    _suggestions[nodeId]!
      ..clear()
      ..addAll(spellingSuggestions);

    notifyListeners();
  }

  /// Clears all spelling suggestions for text within the node with the given [nodeId].
  void clearNode(String nodeId) {
    if (_suggestions[nodeId] == null) {
      return;
    }

    _suggestions.remove(nodeId);
    notifyListeners();
  }

  /// Clears all spelling suggestions for all text in the document.
  void clear() {
    if (_suggestions.isEmpty) {
      return;
    }

    _suggestions.clear();
    notifyListeners();
  }

  @override
  void onTransactionEnd(List<EditEvent> edits) {}

  @override
  void onTransactionStart() {}

  @override
  void reset() {
    clear();
  }
}
