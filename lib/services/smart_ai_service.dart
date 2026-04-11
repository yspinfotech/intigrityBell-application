import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

class SmartAiService {
  static const String _openAiApiKey = 'YOUR_OPENAI_API_KEY_HERE';
  static const String _openAiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o-mini';

  // Specific script detection
  static final RegExp _devanagariRegex = RegExp(r'[\u0900-\u097F]');
  static final RegExp _cyrillicRegex = RegExp(r'[\u0400-\u04FF]');
  static final RegExp _arabicRegex = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _japaneseRegex = RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]');
  static final RegExp _koreanRegex = RegExp(r'[\uAC00-\uD7AF]');
  static final RegExp _greekRegex = RegExp(r'[\u0370-\u03FF]');

  // Common Hindi/Marathi words for fine-tuning detection
  static const Set<String> _marathiKeywords = {
    'आणि', 'पण', 'आहे', 'हो', 'नाही', 'काय', 'कुठे', 'कधी', 'कसं', 'तुम्ही',
    'आम्ही', 'करतो', 'जातो', 'येतो', 'आला', 'गेला', 'झाला', 'बघितला', 'सांगितला',
    'असेल', 'केले', 'केला', 'का', 'होते', 'होतो', 'होती', 'तर', 'जर', 'मुलगा'
  };

  static const Set<String> _hindiKeywords = {
    'और', 'लेकिन', 'है', 'हाँ', 'नहीं', 'क्या', 'कहाँ', 'कब', 'कैसे', 'आप',
    'हम', 'करता', 'जाता', 'आता', 'आया', 'गया', 'हुआ', 'देखा', 'बोला',
    'होगा', 'किया', 'था', 'थी', 'थे', 'रहा', 'रही', 'रहे', 'बेटा'
  };

  static const List<String> _marathiSuffixes = [
    'च्या', 'साठी', 'कडून', 'मध्ये', 'कडे', 'ला', 'ली', 'ले', 'ल्या', 'तून'
  ];

  static const List<String> _hindiSuffixes = [
    'का', 'की', 'के', 'में', 'पर', 'से', 'को', 'ने', 'तक', 'वाला'
  ];

  /// Smart language detection with hybrid fallback mechanism (ReNote AI Standard)
  static Future<String> detectLanguageSmart(String text) async {
    final cleanedText = _cleanAndNormalizeText(text);
    if (cleanedText.length < 5) return 'en';

    // 1. Script Ratio & Mixed Detection
    final charCount = cleanedText.length;
    final latinCount = RegExp(r'[a-zA-Z]').allMatches(cleanedText).length;
    final devanagariCount = _devanagariRegex.allMatches(cleanedText).length;
    
    final bool isMixed = (latinCount / charCount > 0.3) && (devanagariCount / charCount > 0.3);

    // 2. Script Detection (RegEx)
    bool hasDevanagari = devanagariCount > 0;
    bool hasCyrillic = _cyrillicRegex.hasMatch(cleanedText);
    bool hasArabic = _arabicRegex.hasMatch(cleanedText);
    bool hasJapanese = _japaneseRegex.hasMatch(cleanedText);
    bool hasKorean = _koreanRegex.hasMatch(cleanedText);
    bool hasGreek = _greekRegex.hasMatch(cleanedText);

    bool needsAiForScript = hasCyrillic || hasArabic || hasJapanese || hasKorean || hasGreek;

    // 3. ML Kit Primary Check
    String mlKitLang = 'en';
    double mlKitConfidence = 0.0;
    final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.3);
    
    try {
      final List<IdentifiedLanguage> languages = await languageIdentifier.identifyPossibleLanguages(cleanedText);
      if (languages.isNotEmpty) {
        mlKitLang = languages.first.languageTag;
        mlKitConfidence = languages.first.confidence;
      }
    } catch (e) {
      debugPrint('ML Kit Error: $e');
    } finally {
      languageIdentifier.close();
    }

    // 4. Glyph-Based Deep Analysis (Marathi vs Hindi Hallmarks)
    if (hasDevanagari) {
      // Hallmark: 'ळ' is uniquely Marathi in Devanagari context
      if (cleanedText.contains('ळ')) return 'mr';
      
      int marathiScore = 0;
      int hindiScore = 0;
      final words = cleanedText.toLowerCase().split(RegExp(r'\s+'));
      
      for (var word in words) {
        // Keyword checking
        if (_marathiKeywords.contains(word)) marathiScore += 2;
        if (_hindiKeywords.contains(word)) hindiScore += 2;

        // Suffix checking
        for (var suffix in _marathiSuffixes) {
          if (word.endsWith(suffix)) marathiScore++;
        }
        for (var suffix in _hindiSuffixes) {
          if (word.endsWith(suffix)) hindiScore++;
        }
      }

      if (marathiScore > (hindiScore + 1)) return 'mr';
      if (hindiScore > (marathiScore + 1)) return 'hi';
    }

    // 5. OpenAI Fallback (Final Tier for accuracy)
    if (mlKitConfidence < 0.8 || mlKitLang == 'und' || needsAiForScript || isMixed) {
      try {
        String prompt = 'Identify the language of this excerpt. ';
        if (isMixed) prompt += 'The text seems to be mixed (multilingual). Identify the dominant language. ';
        prompt += 'Respond ONLY with the ISO 639-1 code.\n\n$cleanedText';

        final result = await _callOpenAi(prompt, maxTokens: 5);
        final detected = result.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        if (detected.length >= 2) return detected.substring(0, 2);
      } catch (_) {}
    }

    return mlKitLang == 'und' ? 'en' : mlKitLang;
  }

  static String _cleanAndNormalizeText(String text) {
    if (text.isEmpty) return "";
    // Remove numbers and noisy symbols common in bad OCR
    return text
        .replaceAll(RegExp(r'[0-9!@#$%^&*()_+={}\[\]:;"<>,.?/\\|`~]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// AI Feature: Summarize Note
  static Future<String> summarize(String text) async {
    return _callOpenAi('Summarize the following note clearly and concisely:\n\n$text');
  }

  /// AI Feature: Rewrite Note
  static Future<String> rewrite(String text) async {
    return _callOpenAi('Rewrite the following note in a more professional and clearer tone:\n\n$text');
  }

  /// AI Feature: Convert to Bullet Points
  static Future<String> convertToBulletPoints(String text) async {
    return _callOpenAi('Convert the following note into a list of key bullet points:\n\n$text');
  }

  /// AI Feature: Translate Note
  static Future<String> translate(String text, String targetLang) async {
    return _callOpenAi('Translate the following text into $targetLang, maintaining the original meaning and tone:\n\n$text');
  }

  /// AI Feature: Convert to Numbered List
  static Future<String> convertToNumberedList(String text) async {
    return _callOpenAi('Structure the following note into a clear, sequential numbered list. Remove any OCR noise or duplication:\n\n$text');
  }

  /// AI Feature: Convert to Table
  static Future<String> convertToTable(String text) async {
    return _callOpenAi('Analyze the following text and detect structured data patterns like dates, names, costs, or key-value pairs. Format the result as a clean Markdown table. If the data is unstructured, create a basic 2-column table of key information. Respond ONLY with the table.\n\nText: $text');
  }

  /// AI Feature: OCR Fallback (GPT-4o Vision)
  static Future<String> performAiOcr(String imagePath) async {
    if (_openAiApiKey == 'YOUR_OPENAI_API_KEY_HERE') {
      throw Exception('OpenAI API Key not configured. Please add your key in SmartAiService.');
    }

    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(_openAiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAiApiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Perform highly accurate OCR on this image. Extract ALL text, including handwritten notes. IMPORTANT: Maintain the original layout, line breaks, and indentation exactly as seen in the image. Respond ONLY with the extracted text.'
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image'
                  }
                }
              ]
            }
          ],
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        throw Exception('OpenAI OCR Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('OpenAI OCR API Call Error: $e');
      rethrow;
    }
  }

  /// Helper to call OpenAI API
  static Future<String> _callOpenAi(String prompt, {int maxTokens = 500}) async {
    if (_openAiApiKey == 'YOUR_OPENAI_API_KEY_HERE') {
      throw Exception('OpenAI API Key not configured. Please add your key in SmartAiService.');
    }

    try {
      final response = await http.post(
        Uri.parse(_openAiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAiApiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': 'You are a helpful AI assistant for note-taking.'},
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': maxTokens,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        throw Exception('OpenAI Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('OpenAI API Call Error: $e');
      rethrow;
    }
  }
}
