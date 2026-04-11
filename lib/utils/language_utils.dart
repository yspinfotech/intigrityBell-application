class LanguageUtils {
  static const Map<String, String> _isoToName = {
    'en': 'English',
    'hi': 'Hindi हिंदी',
    'mr': 'Marathi मराठी',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'el': 'Greek',
    'he': 'Hebrew',
    'tr': 'Turkish',
    'vi': 'Vietnamese',
    'th': 'Thai',
    'nl': 'Dutch',
    'sv': 'Swedish',
    'gu': 'Gujarati',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'kn': 'Kannada',
    'ml': 'Malayalam',
    'pa': 'Punjabi',
  };

  static const Map<String, String> _isoToFlag = {
    'en': '🇺🇸',
    'hi': '🇮🇳',
    'mr': '🇮🇳',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'it': '🇮🇹',
    'pt': '🇵🇹',
    'ru': '🇷🇺',
    'zh': '🇨🇳',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'ar': '🇸🇦',
    'el': '🇬🇷',
    'he': '🇮🇱',
    'tr': '🇹🇷',
    'vi': '🇻🇳',
    'th': '🇹🇭',
    'nl': '🇳🇱',
    'sv': '🇸🇪',
    'gu': '🇮🇳',
    'bn': '🇮🇳',
    'ta': '🇮🇳',
    'te': '🇮🇳',
    'kn': '🇮🇳',
    'ml': '🇮🇳',
    'pa': '🇮🇳',
  };

  static String getLanguageName(String isoCode) {
    return _isoToName[isoCode.toLowerCase()] ?? isoCode.toUpperCase();
  }

  static String getLanguageFlag(String isoCode) {
    return _isoToFlag[isoCode.toLowerCase()] ?? '🌐';
  }

  static String getLanguageLabel(String isoCode) {
    final name = getLanguageName(isoCode);
    final flag = getLanguageFlag(isoCode);
    return '$name $flag';
  }
}
