/// Model representing a word entry from Free Dictionary API.
class WordDefinitionModel {
  final String word;
  final String? phonetic;
  final String? audioUrl;
  final List<WordMeaning> meanings;

  const WordDefinitionModel({
    required this.word,
    this.phonetic,
    this.audioUrl,
    required this.meanings,
  });

  factory WordDefinitionModel.fromJson(Map<String, dynamic> json) {
    final word = json['word'] as String? ?? '';
    final phonetic = json['phonetic'] as String?;

    String? audio;
    if (json['phonetics'] is List) {
      for (final p in json['phonetics'] as List) {
        if (p is Map && p['audio'] is String && (p['audio'] as String).isNotEmpty) {
          audio = p['audio'] as String;
          break;
        }
      }
    }

    final meaningsList = <WordMeaning>[];
    if (json['meanings'] is List) {
      for (final m in json['meanings'] as List) {
        if (m is Map<String, dynamic>) {
          meaningsList.add(WordMeaning.fromJson(m));
        }
      }
    }

    return WordDefinitionModel(
      word: word,
      phonetic: phonetic,
      audioUrl: audio,
      meanings: meaningsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'phonetic': phonetic,
      'audioUrl': audioUrl,
      'meanings': meanings.map((m) => m.toJson()).toList(),
    };
  }
}

class WordMeaning {
  final String partOfSpeech;
  final List<WordDefinitionItem> definitions;

  const WordMeaning({
    required this.partOfSpeech,
    required this.definitions,
  });

  factory WordMeaning.fromJson(Map<String, dynamic> json) {
    final partOfSpeech = json['partOfSpeech'] as String? ?? '';
    final defs = <WordDefinitionItem>[];
    if (json['definitions'] is List) {
      for (final d in json['definitions'] as List) {
        if (d is Map<String, dynamic>) {
          defs.add(WordDefinitionItem.fromJson(d));
        }
      }
    }
    return WordMeaning(
      partOfSpeech: partOfSpeech,
      definitions: defs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partOfSpeech': partOfSpeech,
      'definitions': definitions.map((d) => d.toJson()).toList(),
    };
  }
}

class WordDefinitionItem {
  final String definition;
  final String? example;

  const WordDefinitionItem({
    required this.definition,
    this.example,
  });

  factory WordDefinitionItem.fromJson(Map<String, dynamic> json) {
    return WordDefinitionItem(
      definition: json['definition'] as String? ?? '',
      example: json['example'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'definition': definition,
      'example': example,
    };
  }
}
