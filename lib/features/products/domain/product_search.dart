String normalizeProductSearch(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Set<String> productSearchIndexGrams(String productName) {
  final grams = <String>{};
  for (final word in normalizeProductSearch(productName).split(' ')) {
    if (word.isEmpty) continue;
    final characters = word.runes.map(String.fromCharCode).toList();
    grams.addAll(characters);
    for (var index = 0; index + 1 < characters.length; index++) {
      grams.add('${characters[index]}${characters[index + 1]}');
    }
  }
  return grams;
}

List<Set<String>> productSearchQueryGrams(String query) {
  final words = normalizeProductSearch(query)
      .split(' ')
      .where((word) => word.isNotEmpty);
  return [
    for (final word in words)
      () {
        final characters = word.runes.map(String.fromCharCode).toList();
        if (characters.length == 1) return <String>{characters.single};
        return <String>{
          for (var index = 0; index + 1 < characters.length; index++)
            '${characters[index]}${characters[index + 1]}',
        };
      }(),
  ];
}

bool matchesProductSearch(String query, String productName) {
  final normalizedQuery = normalizeProductSearch(query);
  if (normalizedQuery.isEmpty) return true;

  final normalizedName = normalizeProductSearch(productName);
  if (normalizedName.contains(normalizedQuery)) return true;

  final queryWords = normalizedQuery.split(' ');
  final nameWords = normalizedName.split(' ');
  return queryWords.every(
    (queryWord) =>
        nameWords.any((nameWord) => _wordsAreSimilar(queryWord, nameWord)),
  );
}

bool _wordsAreSimilar(String query, String candidate) {
  if (candidate.contains(query)) return true;
  if (query.length < 3) return false;
  if (_isSubsequence(query, candidate)) return true;

  final allowedDistance = query.length >= 7 ? 2 : 1;
  return _levenshteinDistance(query, candidate) <= allowedDistance;
}

bool _isSubsequence(String query, String candidate) {
  var queryIndex = 0;
  for (final codeUnit in candidate.codeUnits) {
    if (queryIndex < query.length && query.codeUnitAt(queryIndex) == codeUnit) {
      queryIndex++;
    }
  }
  return queryIndex == query.length;
}

int _levenshteinDistance(String first, String second) {
  final previous = List<int>.generate(second.length + 1, (index) => index);
  for (var i = 1; i <= first.length; i++) {
    var diagonal = previous[0];
    previous[0] = i;
    for (var j = 1; j <= second.length; j++) {
      final above = previous[j];
      final replacementCost =
          first.codeUnitAt(i - 1) == second.codeUnitAt(j - 1) ? 0 : 1;
      previous[j] = [
        previous[j] + 1,
        previous[j - 1] + 1,
        diagonal + replacementCost,
      ].reduce((a, b) => a < b ? a : b);
      diagonal = above;
    }
  }
  return previous.last;
}
