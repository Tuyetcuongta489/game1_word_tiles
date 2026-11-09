import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/offline_dictionary_data.dart';
import '../models/word_definition_model.dart';
import 'game_storage.dart';

/// Multi-language Dictionary Service for looking up definitions with 5-tier architecture:
/// 1. Memory Cache (instant, 0ms)
/// 2. Persistent Storage Cache (SharedPreferences)
/// 3. Bundled Offline Dictionary for English (1,380+ words, 0ms, zero network)
/// 4. Primary Multi-language Network API: FreeDictionaryAPI (https://freedictionaryapi.com/api/v1/entries/{lang}/{word})
/// 5. Secondary Network Fallbacks: Datamuse API (en) / Wikimedia Wiktionary REST API (all languages)
class DictionaryService {
  DictionaryService._();

  static const String _freeDictBaseUrl = 'https://freedictionaryapi.com/api/v1/entries/';

  // In-memory cache: key = "${langCode}_${cleanWord}"
  static final Map<String, WordDefinitionModel?> _memoryCache = {};

  // Testing mock dictionary map
  @visibleForTesting
  static final Map<String, WordDefinitionModel?> mockDefinitions = {};

  /// Convert verbose language string (e.g. 'english', 'french') to ISO 2-letter code
  static String normalizeLanguageCode(String? lang) {
    if (lang == null || lang.isEmpty) return 'en';
    final l = lang.trim().toLowerCase();
    switch (l) {
      case 'en':
      case 'english':
        return 'en';
      case 'fr':
      case 'french':
        return 'fr';
      case 'es':
      case 'spanish':
        return 'es';
      case 'de':
      case 'german':
        return 'de';
      case 'it':
      case 'italian':
        return 'it';
      case 'pt':
      case 'portuguese':
        return 'pt';
      case 'ru':
      case 'russian':
        return 'ru';
      case 'tr':
      case 'turkish':
        return 'tr';
      default:
        return 'en';
    }
  }

  /// Lookup word definition with multi-tier caching and reliable multi-language network fallbacks
  static Future<WordDefinitionModel?> getDefinition(
    String word, {
    String language = 'en',
  }) async {
    final cleanWord = word.trim().toLowerCase();
    if (cleanWord.isEmpty) return null;
    final langCode = normalizeLanguageCode(language);
    final cacheKey = '${langCode}_$cleanWord';

    // 0. Check mock definitions for unit testing
    if (mockDefinitions.containsKey(cleanWord)) {
      return mockDefinitions[cleanWord];
    }
    if (mockDefinitions.containsKey(cacheKey)) {
      return mockDefinitions[cacheKey];
    }

    // 1. Check in-memory cache
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // 2. Check persistent SharedPreferences cache
    try {
      final cachedJson = GameStorage.getCachedWordDefinition(cacheKey) ??
          (langCode == 'en' ? GameStorage.getCachedWordDefinition(cleanWord) : null);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        final model = WordDefinitionModel.fromJson(decoded);
        _memoryCache[cacheKey] = model;
        return model;
      }
    } catch (_) {}

    // 3. Check bundled offline dictionary (instant, reliable, works without internet for English)
    if (langCode == 'en' && kOfflineDictionaryData.containsKey(cleanWord)) {
      final data = kOfflineDictionaryData[cleanWord];
      if (data != null) {
        final model = WordDefinitionModel.fromJson(data);
        _memoryCache[cacheKey] = model;
        return model;
      }
    }

    // 4. Primary Multi-language Network API: freedictionaryapi.com (Wiktionary JSON API)
    try {
      final uri = Uri.parse('$_freeDictBaseUrl$langCode/${Uri.encodeComponent(cleanWord)}');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Mozilla/5.0');
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final model = _parseFreeDictionaryApiResponse(cleanWord, responseBody);
        if (model != null) {
          _memoryCache[cacheKey] = model;
          await GameStorage.setCachedWordDefinition(cacheKey, jsonEncode(model.toJson()));
          client.close();
          return model;
        }
      }
      client.close();
    } catch (e) {
      debugPrint('[DictionaryService] freedictionaryapi.com error for "$cleanWord" ($langCode): $e');
    }

    // 5. Secondary Network Fallbacks:
    if (langCode == 'en') {
      // 5A. Datamuse API (for English - Wiktionary backed, 99.99% uptime, <100ms)
      try {
        final datamuseUri = Uri.parse('https://api.datamuse.com/words?sp=${Uri.encodeComponent(cleanWord)}&md=dp&max=1');
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

        final request = await client.getUrl(datamuseUri);
        request.headers.set('User-Agent', 'Mozilla/5.0');
        request.headers.set('Accept', 'application/json');

        final response = await request.close().timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final model = _parseDatamuseResponse(cleanWord, responseBody);
          if (model != null) {
            _memoryCache[cacheKey] = model;
            await GameStorage.setCachedWordDefinition(cacheKey, jsonEncode(model.toJson()));
            client.close();
            return model;
          }
        }
        client.close();
      } catch (e) {
        debugPrint('[DictionaryService] Datamuse fallback error for "$cleanWord": $e');
      }
    } else {
      // 5B. Wikimedia REST API (official Wikipedia / Wiktionary API for all other languages)
      try {
        final wikiUri = Uri.parse('https://$langCode.wiktionary.org/api/rest_v1/page/definition/${Uri.encodeComponent(cleanWord)}');
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

        final request = await client.getUrl(wikiUri);
        request.headers.set('User-Agent', 'Wordnect-App/1.0 (https://mobgame.mobi)');
        request.headers.set('Accept', 'application/json');

        final response = await request.close().timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final model = _parseWiktionaryResponse(cleanWord, langCode, responseBody);
          if (model != null) {
            _memoryCache[cacheKey] = model;
            await GameStorage.setCachedWordDefinition(cacheKey, jsonEncode(model.toJson()));
            client.close();
            return model;
          }
        }
        client.close();
      } catch (e) {
        debugPrint('[DictionaryService] Wiktionary fallback error for "$cleanWord" ($langCode): $e');
      }
    }

    return null;
  }

  /// Parse freedictionaryapi.com response into WordDefinitionModel
  static WordDefinitionModel? _parseFreeDictionaryApiResponse(String cleanWord, String responseBody) {
    try {
      final dynamic parsed = jsonDecode(responseBody);
      if (parsed is Map<String, dynamic> && parsed['entries'] is List) {
        final entries = parsed['entries'] as List;
        if (entries.isEmpty) return null;

        String? phonetic;
        final meaningsList = <WordMeaning>[];

        for (final entry in entries) {
          if (entry is! Map<String, dynamic>) continue;
          final pos = (entry['partOfSpeech'] as String? ?? 'general').toLowerCase();

          // Get phonetic text
          if (phonetic == null && entry['pronunciations'] is List) {
            for (final pr in entry['pronunciations'] as List) {
              if (pr is Map && pr['text'] is String && (pr['text'] as String).isNotEmpty) {
                phonetic = pr['text'] as String;
                break;
              }
            }
          }

          // Get definitions
          final defItems = <WordDefinitionItem>[];
          if (entry['senses'] is List) {
            for (final s in entry['senses'] as List) {
              if (s is Map<String, dynamic>) {
                final defText = s['definition'] as String? ?? '';
                if (defText.trim().isNotEmpty) {
                  String? example;
                  if (s['examples'] is List && (s['examples'] as List).isNotEmpty) {
                    example = (s['examples'] as List).first as String?;
                  }
                  defItems.add(WordDefinitionItem(
                    definition: defText.trim(),
                    example: example,
                  ));
                  if (defItems.length >= 3) break;
                }
              }
            }
          }

          if (defItems.isNotEmpty) {
            meaningsList.add(WordMeaning(
              partOfSpeech: pos,
              definitions: defItems,
            ));
          }
        }

        if (meaningsList.isNotEmpty) {
          return WordDefinitionModel(
            word: cleanWord,
            phonetic: phonetic,
            audioUrl: null,
            meanings: meaningsList,
          );
        }
      }
    } catch (e) {
      debugPrint('[DictionaryService] Error parsing freedictionaryapi.com: $e');
    }
    return null;
  }

  /// Parse Datamuse definition items into WordDefinitionModel
  static WordDefinitionModel? _parseDatamuseResponse(String cleanWord, String responseBody) {
    try {
      final dynamic parsed = jsonDecode(responseBody);
      if (parsed is List && parsed.isNotEmpty && parsed.first is Map<String, dynamic>) {
        final entry = parsed.first as Map<String, dynamic>;
        final defs = entry['defs'];
        if (defs is List && defs.isNotEmpty) {
          final Map<String, List<WordDefinitionItem>> meaningsByPos = {};
          final posMap = {
            'n': 'noun',
            'v': 'verb',
            'adj': 'adjective',
            'adv': 'adverb',
            'u': 'noun',
          };

          for (final d in defs) {
            if (d is String) {
              final tabIndex = d.indexOf('\t');
              if (tabIndex != -1) {
                final tag = d.substring(0, tabIndex).trim();
                final defText = d.substring(tabIndex + 1).trim();
                final pos = posMap[tag] ?? 'noun';
                meaningsByPos.putIfAbsent(pos, () => []);
                if (meaningsByPos[pos]!.length < 3) {
                  meaningsByPos[pos]!.add(WordDefinitionItem(definition: defText));
                }
              }
            }
          }

          if (meaningsByPos.isNotEmpty) {
            final meaningsList = meaningsByPos.entries.map((e) {
              return WordMeaning(partOfSpeech: e.key, definitions: e.value);
            }).toList();

            return WordDefinitionModel(
              word: cleanWord,
              phonetic: null,
              audioUrl: null,
              meanings: meaningsList,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Parse official Wikimedia Wiktionary REST API response into WordDefinitionModel
  static WordDefinitionModel? _parseWiktionaryResponse(
    String cleanWord,
    String langCode,
    String responseBody,
  ) {
    try {
      final dynamic parsed = jsonDecode(responseBody);
      if (parsed is Map<String, dynamic>) {
        // Wiktionary wraps definitions by language key, e.g. parsed['en'] or parsed[langCode]
        final langList = parsed[langCode] ?? parsed['en'] ?? (parsed.values.isNotEmpty ? parsed.values.first : null);
        if (langList is List && langList.isNotEmpty) {
          final meaningsList = <WordMeaning>[];
          for (final item in langList) {
            if (item is! Map<String, dynamic>) continue;
            final pos = (item['partOfSpeech'] as String? ?? 'general').toLowerCase();
            final defs = item['definitions'];
            final defItems = <WordDefinitionItem>[];

            if (defs is List) {
              for (final d in defs) {
                if (d is Map<String, dynamic>) {
                  var rawDef = d['definition'] as String? ?? '';
                  // Strip HTML tags from Wiktionary HTML definition string
                  rawDef = rawDef.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
                  if (rawDef.isNotEmpty) {
                    defItems.add(WordDefinitionItem(definition: rawDef));
                    if (defItems.length >= 3) break;
                  }
                }
              }
            }

            if (defItems.isNotEmpty) {
              meaningsList.add(WordMeaning(partOfSpeech: pos, definitions: defItems));
            }
          }

          if (meaningsList.isNotEmpty) {
            return WordDefinitionModel(
              word: cleanWord,
              phonetic: null,
              audioUrl: null,
              meanings: meaningsList,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[DictionaryService] Error parsing Wiktionary response: $e');
    }
    return null;
  }

  /// Concurrently fetch definitions for a list of words
  static Future<Map<String, WordDefinitionModel?>> getDefinitionsForWords(
    List<String> words, {
    String language = 'en',
  }) async {
    final Map<String, WordDefinitionModel?> results = {};
    final futures = words.map((w) async {
      final def = await getDefinition(w, language: language);
      results[w.toUpperCase()] = def;
    });
    await Future.wait(futures);
    return results;
  }

  /// Clear in-memory cache
  static void clearMemoryCache() {
    _memoryCache.clear();
  }
}
