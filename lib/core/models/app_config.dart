/// Firestore system/general dokümanındaki uygulama konfigürasyonu
class AppConfig {
  final String geminiApiKey;
  final String modelName;
  final String googleAppleButtons; // "close", "test", "open"
  final String groqApiKey;
  final String groqModelName;
  final String slackInfoURL;

  const AppConfig({
    required this.geminiApiKey,
    required this.modelName,
    this.googleAppleButtons = 'close',
    this.groqApiKey = '',
    this.groqModelName = 'llama-3.3-70b-versatile',
    this.slackInfoURL = '',
  });

  /// Firestore dokümanından AppConfig oluşturur
  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      geminiApiKey: map['geminiApiKey'] as String? ?? '',
      modelName: map['modelName'] as String? ?? 'gemini-2.5-flash',
      googleAppleButtons: map['googleAppleButtons'] as String? ?? 'close',
      groqApiKey: map['groqKey'] as String? ?? '',
      groqModelName: map['groqModel'] as String? ?? 'llama-3.3-70b-versatile',
      slackInfoURL: map['slackInfoURL'] as String? ?? '',
    );
  }
}
