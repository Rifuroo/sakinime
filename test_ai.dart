// Test AI configuration
import 'lib/config/ai_config.dart';

void main() {
  print('🤖 Testing AI Configuration...');
  print('');
  
  print('Provider: ${AIConfig.preferredProvider}');
  print('API Key: ${AIConfig.apiKey.substring(0, 10)}...');
  print('Base URL: ${AIConfig.baseUrl}');
  print('Use AI: ${AIConfig.useAI}');
  print('Is Configured: ${AIConfig.isConfigured}');
  print('Max Tokens: ${AIConfig.maxTokens}');
  print('Temperature: ${AIConfig.temperature}');
  
  if (AIConfig.isConfigured) {
    print('');
    print('✅ AI Configuration is READY!');
    print('🎌 Anime-style translation will be enhanced with AI');
  } else {
    print('');
    print('❌ AI Configuration is NOT ready');
    print('Please check your API key');
  }
}