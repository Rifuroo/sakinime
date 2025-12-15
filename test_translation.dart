// Test translation service
import 'lib/services/translation_service.dart';

void main() async {
  print('Testing translation service...');
  
  try {
    final result = await TranslationService.translateText('Hello world', 'id');
    print('Translation result: $result');
    
    final languages = TranslationService.supportedLanguages;
    print('Supported languages: ${languages.length}');
    
    print('Test completed successfully!');
  } catch (e) {
    print('Test failed: $e');
  }
}