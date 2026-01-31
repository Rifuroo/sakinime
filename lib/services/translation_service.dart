// services/translation_service.dart - AI Translation Service
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();
  
  // Supported languages for translation
  static const Map<String, String> supportedLanguages = {
    'id': 'Bahasa Indonesia',
    'ja': '日本語 (Japanese)',
    'ko': '한국어 (Korean)',
    'zh': '中文 (Chinese)',
    'th': 'ไทย (Thai)',
    'vi': 'Tiếng Việt',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'ru': 'Русский',
    'ar': 'العربية',
    'hi': 'हिन्दी',
    'pt': 'Português',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'tr': 'Türkçe',
    'jv': 'Basa Jawa (Javanese)',
    'su': 'Basa Sunda (Sundanese)',
    'ms': 'Bahasa Melayu (Malay)',
  };
  
  // Cache for translated subtitles
  static final Map<String, Map<String, String>> _translationCache = {};
  
  // Public getter for cache (for optimization checks)
  static Map<String, Map<String, String>> get translationCache => _translationCache;
  
  // Rate limiting
  static DateTime _lastAICall = DateTime.now().subtract(const Duration(seconds: 2));
  static const Duration _aiCallDelay = Duration(milliseconds: 1500); // 1.5 second delay between AI calls
  
  // Auto-disable AI if too many failures
  static int _consecutiveAIFailures = 0;
  static const int _maxAIFailures = 5;
  // ignore: unused_field
  static bool _aiTemporarilyDisabled = false;
  
  /// Translate subtitle text to target language with AI styling
  static Future<String> translateText(String text, String targetLang, {String style = 'anime'}) async {
    if (text.trim().isEmpty) return text;
    
    // Check cache first (include style in cache key)
    final cacheKey = '${text.hashCode}_${targetLang}_$style';
    if (_translationCache.containsKey(targetLang) && 
        _translationCache[targetLang]!.containsKey(cacheKey)) {
      return _translationCache[targetLang]![cacheKey]!;
    }
    
    try {
      // Step 1: Clean text for better translation
      String cleanText = _cleanTextForTranslation(text);
      
      // Step 2: Basic translation
      String translatedText = '';
      try {
        final translation = await _translator.translate(
          cleanText,
          from: 'en', // Assume English source
          to: targetLang,
        );
        translatedText = translation.text;
      } catch (e) {
        // Fallback to LibreTranslate if Google Translator fails
        if (kDebugMode) {
          print('⚠️ Google Translator failed, trying LibreTranslate: $e');
        }
        translatedText = await translateWithLibre(cleanText, targetLang);
      }
      
      // Step 3: Basic Enhancement (AI disabled for now)
      if (targetLang == 'id' && style == 'anime') {
        // Use basic anime enhancement instead of AI
        translatedText = _basicAnimeEnhancement(translatedText);
        if (kDebugMode) {
          print('🎌 Basic anime enhancement applied: "$cleanText" -> "$translatedText"');
        }
      }
      
      // Step 4: Basic post-processing
      translatedText = _basicPostProcess(translatedText, targetLang);
      
      // Cache the result
      _translationCache[targetLang] ??= {};
      _translationCache[targetLang]![cacheKey] = translatedText;
      
      if (kDebugMode) {
        print('🌐 Translated: "$cleanText" -> "$translatedText" ($targetLang, $style)');
      }
      
      return translatedText;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Translation error: $e');
      }
      return text; // Return original if translation fails
    }
  }
  
  /// Batch translate multiple texts in parallel (optimized for subtitle streams)
  static Future<Map<String, String>> batchTranslateTexts(
    List<String> texts, 
    String targetLang, 
    {String style = 'anime'}
  ) async {
    if (texts.isEmpty) return {};
    
    final results = <String, String>{};
    final uniqueTexts = texts.toSet().toList(); // Remove duplicates
    
    // Check cache first
    final uncachedTexts = <String>[];
    for (final text in uniqueTexts) {
      final cacheKey = '${text.hashCode}_${targetLang}_$style';
      if (_translationCache.containsKey(targetLang) && 
          _translationCache[targetLang]!.containsKey(cacheKey)) {
        results[text] = _translationCache[targetLang]![cacheKey]!;
      } else {
        uncachedTexts.add(text);
      }
    }
    
    if (uncachedTexts.isEmpty) return results;
    
    // Translate in parallel batches of 5 to avoid overwhelming the API
    const batchSize = 5;
    for (var i = 0; i < uncachedTexts.length; i += batchSize) {
      final batch = uncachedTexts.skip(i).take(batchSize).toList();
      
      // Translate batch in parallel
      final futures = batch.map((text) => translateText(text, targetLang, style: style));
      final translations = await Future.wait(futures);
      
      // Store results
      for (var j = 0; j < batch.length; j++) {
        results[batch[j]] = translations[j];
      }
      
      // Small delay between batches to avoid rate limiting
      if (i + batchSize < uncachedTexts.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    return results;
  }
  
  /// Enhance translation with AI styling
  // ignore: unused_element
  static Future<String> _enhanceWithAI(String translatedText, String style) async {
    try {
      // Rate limiting: wait between AI calls
      final now = DateTime.now();
      final timeSinceLastCall = now.difference(_lastAICall);
      if (timeSinceLastCall < _aiCallDelay) {
        final waitTime = _aiCallDelay - timeSinceLastCall;
        await Future.delayed(waitTime);
      }
      _lastAICall = DateTime.now();
      
      // Use AI to improve anime-style translation
      final aiPrompt = _buildAIPrompt(translatedText, style);
      final enhancedText = await _callAIService(aiPrompt);
      
      if (enhancedText.isNotEmpty && enhancedText != translatedText) {
        // Reset failure counter on success
        _consecutiveAIFailures = 0;
        _aiTemporarilyDisabled = false;
        
        if (kDebugMode) {
          print('🤖 AI Enhanced: "$translatedText" -> "$enhancedText"');
        }
        return enhancedText;
      }
    } catch (e) {
      // Increment failure counter
      _consecutiveAIFailures++;
      
      if (kDebugMode) {
        print('⚠️ AI enhancement failed ($e): $_consecutiveAIFailures/$_maxAIFailures');
      }
      
      // Temporarily disable AI if too many failures
      if (_consecutiveAIFailures >= _maxAIFailures) {
        _aiTemporarilyDisabled = true;
        if (kDebugMode) {
          print('🚫 AI temporarily disabled due to consecutive failures');
        }
      }
      
      // Return basic enhanced version as fallback
      return _basicAnimeEnhancement(translatedText);
    }
    
    return translatedText; // Return original if AI fails
  }
  
  /// Basic anime enhancement without AI (fallback)
  static String _basicAnimeEnhancement(String text) {
    // Simple replacements for anime-style Indonesian using word boundaries
    final Map<String, String> replacements = {
      'saya': 'aku',
      'Saya': 'Aku',
      'Anda': 'kamu',
      'anda': 'kamu',
      'tidak': 'gak',
      'Tidak': 'Gak',
      'bagaimana': 'gimana',
      'Bagaimana': 'Gimana',
      'kenapa': 'kok',
      'Kenapa': 'Kok',
      'mengapa': 'kenapa',
      'Mengapa': 'Kenapa',
      'apakah': 'apa',
      'Apakah': 'Apa',
      'seharusnya': 'harusnya',
      'Seharusnya': 'Harusnya',
      'seseorang': 'orang',
      'Seseorang': 'Orang',
      'akan': 'bakal',
      'Akan': 'Bakal',
    };

    String result = text;
    replacements.forEach((key, value) {
      // Use word boundaries \b to avoid replacing parts of words (like 'mengandalkan' -> 'mengkamulkan')
      result = result.replaceAll(RegExp('\\b$key\\b', caseSensitive: false), value);
    });
    
    return result;
  }
  
  /// Build AI prompt for anime-style enhancement
  static String _buildAIPrompt(String text, String style) {
    switch (style) {
      case 'anime':
        return 'Improve this Indonesian anime subtitle to sound more natural: "$text". Use casual anime language (aku/kamu), keep anime terms, max 2 lines. Reply only with the improved translation:';
      
      case 'casual':
        return 'Make this Indonesian text more casual and trendy: "$text". Use slang (gue/lu, gak), informal style. Reply only with the casual version:';
      
      case 'formal':
        return 'Make this Indonesian text more formal and polite: "$text". Use formal language (saya/Anda, tidak). Reply only with the formal version:';
      
      default:
        return text;
    }
  }
  
  /// Call AI service for text enhancement
  static Future<String> _callAIService(String prompt) async {
    try {
      switch (AIConfig.preferredProvider) {
        case 'groq':
          return await _callGroqAPI(prompt);
        case 'openai':
          return await _callOpenAI(prompt);
        case 'ollama':
          return await _callOllama(prompt);
        case 'huggingface':
          return await _callHuggingFace(prompt);
        case 'cohere':
          return await _callCohere(prompt);
        default:
          return await _callGroqAPI(prompt);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AI service error: $e');
      }
      return '';
    }
  }
  
  /// Call Groq API with fallback models
  static Future<String> _callGroqAPI(String prompt) async {
    // List of models to try (in order of preference) - Updated December 2024
    final models = [
      'llama-3.3-70b-versatile', // Primary: Latest Llama model
      'llama-3.1-8b-instant',    // Fallback 1: Fast and efficient
      'llama3-8b-8192',          // Fallback 2: Alternative naming
      'llama3-70b-8192',         // Fallback 3: Larger model
    ];
    
    for (int i = 0; i < models.length; i++) {
      final model = models[i];
      try {
        if (kDebugMode && i > 0) {
          debugPrint('🔄 Trying fallback model: $model');
        }
        
        final response = await http.post(
          Uri.parse(AIConfig.groqBaseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AIConfig.groqApiKey}',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content': 'You are a professional anime subtitle translator. Respond only with the improved translation, no explanations.',
              },
              {
                'role': 'user',
                'content': prompt,
              }
            ],
            'max_tokens': AIConfig.maxTokens,
            'temperature': AIConfig.temperature,
            'stream': false,
          }),
        );
        
        if (kDebugMode) {
          debugPrint('🤖 Groq API Response ($model): ${response.statusCode}');
          if (response.statusCode != 200) {
            debugPrint('   Error body: ${response.body}');
          }
        }
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            final content = data['choices'][0]['message']['content'];
            if (kDebugMode && i > 0) {
              debugPrint('✅ Success with fallback model: $model');
            }
            return content.trim();
          }
          throw Exception('Empty response from Groq');
        }
        
        // Handle specific error codes
        if (response.statusCode == 429) {
          throw Exception('Rate limit exceeded. Please wait a moment.');
        } else if (response.statusCode == 401) {
          throw Exception('Invalid API key');
        } else if (response.statusCode == 400) {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error']?['message'] ?? 'Bad request';
          
          // If model is decommissioned, try next model
          if (errorMessage.contains('decommissioned') || errorMessage.contains('not found')) {
            if (kDebugMode) {
              print('⚠️ Model $model is decommissioned, trying next...');
            }
            continue; // Try next model
          }
          
          throw Exception('Request error: $errorMessage');
        }
        
        throw Exception('Groq API error: ${response.statusCode}');
        
      } catch (e) {
        if (kDebugMode) {
          print('❌ Model $model failed: $e');
        }
        
        // If this is the last model, rethrow the error
        if (i == models.length - 1) {
          rethrow;
        }
        
        // Otherwise, continue to next model
        continue;
      }
    }
    
    throw Exception('All Groq models failed');
  }
  
  /// Call OpenAI API
  static Future<String> _callOpenAI(String prompt) async {
    final response = await http.post(
      Uri.parse(AIConfig.openaiBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AIConfig.openaiApiKey}',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'max_tokens': AIConfig.maxTokens,
        'temperature': AIConfig.temperature,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      return content.trim();
    }
    
    throw Exception('OpenAI API error: ${response.statusCode}');
  }
  
  /// Call Ollama (local AI)
  static Future<String> _callOllama(String prompt) async {
    final response = await http.post(
      Uri.parse(AIConfig.ollamaBaseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': AIConfig.ollamaModel,
        'prompt': prompt,
        'stream': false,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'].trim();
    }
    
    throw Exception('Ollama error: ${response.statusCode}');
  }
  
  /// Call Hugging Face API
  static Future<String> _callHuggingFace(String prompt) async {
    final response = await http.post(
      Uri.parse(AIConfig.huggingFaceBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AIConfig.huggingFaceApiKey}',
      },
      body: jsonEncode({
        'inputs': prompt,
        'parameters': {
          'max_length': AIConfig.maxTokens,
          'temperature': AIConfig.temperature,
        }
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty) {
        return data[0]['generated_text'].trim();
      }
    }
    
    throw Exception('Hugging Face error: ${response.statusCode}');
  }
  
  /// Call Cohere API
  static Future<String> _callCohere(String prompt) async {
    final response = await http.post(
      Uri.parse(AIConfig.cohereBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AIConfig.cohereApiKey}',
      },
      body: jsonEncode({
        'model': 'command-light',
        'prompt': prompt,
        'max_tokens': AIConfig.maxTokens,
        'temperature': AIConfig.temperature,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['generations'] != null && data['generations'].isNotEmpty) {
        return data['generations'][0]['text'].trim();
      }
    }
    
    throw Exception('Cohere error: ${response.statusCode}');
  }
  

  
  /// Translate multiple subtitle texts in batch (Parallel)
  static Future<List<String>> translateBatch(
    List<String> texts, 
    String targetLang, {
    int batchSize = 10,
  }) async {
    if (texts.isEmpty) return [];
    
    final List<String> results = List.filled(texts.length, '');
    
    // Process in smaller chunks to avoid overwhelming APIs or rate limits
    for (int i = 0; i < texts.length; i += batchSize) {
      final end = (i + batchSize < texts.length) ? i + batchSize : texts.length;
      final chunk = texts.sublist(i, end);
      
      if (kDebugMode) {
        print('📡 Translating batch chunk: ${i ~/ batchSize + 1} (${chunk.length} items)');
      }
      
      // Parallel execution for this chunk
      final translatedChunk = await Future.wait(
        chunk.map((text) => translateText(text, targetLang))
      );
      
      for (int j = 0; j < translatedChunk.length; j++) {
        results[i + j] = translatedChunk[j];
      }
      
      // Small cooldown between chunks if there are more
      if (end < texts.length) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    
    return results;
  }
  
  /// Clean text before translation for better results
  static String _cleanTextForTranslation(String text) {
    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Remove excessive whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Remove speaker names in brackets
    text = text.replaceAll(RegExp(r'^\[.*?\]\s*'), '');
    
    // Remove sound effects in parentheses
    text = text.replaceAll(RegExp(r'\([^)]*sound[^)]*\)', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\([^)]*music[^)]*\)', caseSensitive: false), '');
    
    // Don't skip any text - display everything like React Native does
    return text;
  }
  
  /// Check if text has corrupted encoding
  /*
  static bool _isCorruptedEncoding(String text) {
    // Check for common corrupted encoding patterns
    if (text.contains(RegExp(r'Ø[Ø§-Ù]+'))) return true; // Arabic corruption
    if (text.contains(RegExp(r'[Ã¢â‚¬â„¢]+'))) return true; // UTF-8 corruption
    if (text.contains(RegExp(r'[ï¿½]+'))) return true; // Replacement character
    
    return false;
  }
  */
  
  /// Basic post-processing (simplified)
  static String _basicPostProcess(String text, String targetLang) {
    // Fix common translation issues per language
    switch (targetLang) {
      case 'id': // Indonesian - Basic fixes only
        // Fix obvious translation errors
        text = text.replaceAll('Aku akan', 'Aku akan');
        text = text.replaceAll('tidak ', 'gak ');
        text = text.replaceAll('Tidak ', 'Gak ');
        break;
      case 'ja': // Japanese
        // Ensure proper Japanese punctuation
        text = text.replaceAll('。。', '。');
        text = text.replaceAll('！！', '！');
        break;
      case 'ko': // Korean
        // Fix Korean spacing
        text = text.replaceAll(RegExp(r'([가-힣])\s+([가-힣])'), r'$1$2');
        break;
    }
    
    return text.trim();
  }
  

  
  /// Get language name from code
  static String getLanguageName(String langCode) {
    return supportedLanguages[langCode] ?? langCode.toUpperCase();
  }
  
  /// Check if language is supported
  static bool isLanguageSupported(String langCode) {
    return supportedLanguages.containsKey(langCode);
  }
  
  /// Clear translation cache
  static void clearCache() {
    _translationCache.clear();
    if (kDebugMode) {
      print('🗑️ Translation cache cleared');
    }
  }
  
  /// Get cache size for debugging
  static int getCacheSize() {
    int totalSize = 0;
    _translationCache.forEach((lang, cache) {
      totalSize += cache.length;
    });
    return totalSize;
  }
  
  /// Alternative translation using LibreTranslate (free, self-hosted option)
  static Future<String> translateWithLibre(
    String text, 
    String targetLang, {
    String apiUrl = 'https://libretranslate.de/translate',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'source': 'en',
          'target': targetLang,
          'format': 'text',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['translatedText'] ?? text;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ LibreTranslate error: $e');
      }
    }
    
    // Fallback to MyMemory API (free, no API key needed)
    return await translateWithMyMemory(text, targetLang);
  }
  
  /// Alternative translation using MyMemory API (free, no API key)
  static Future<String> translateWithMyMemory(String text, String targetLang) async {
    try {
      final encodedText = Uri.encodeComponent(text);
      final url = 'https://api.mymemory.translated.net/get?q=$encodedText&langpair=en|$targetLang';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['responseStatus'] == 200) {
          final translatedText = data['responseData']['translatedText'];
          if (translatedText != null && translatedText.isNotEmpty) {
            return _basicPostProcess(translatedText, targetLang);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ MyMemory translation error: $e');
      }
    }
    
    return text; // Return original if all translation methods fail
  }
  
  /// Detect language of text
  static Future<String> detectLanguage(String text) async {
    try {
      final detection = await _translator.translate(text, to: 'en');
      return detection.sourceLanguage.code;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Language detection error: $e');
      }
      return 'en'; // Default to English
    }
  }
}