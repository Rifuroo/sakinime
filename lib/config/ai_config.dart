// config/ai_config.dart - AI Service Configuration
class AIConfig {
  // Groq API (Free tier: 6000 requests/hour)
  static const String groqApiKey = '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';
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  // OpenAI API (Paid)
  static const String openaiApiKey = 'sk-YOUR_OPENAI_API_KEY_HERE';
  static const String openaiBaseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // Local Ollama (Free, self-hosted)
  static const String ollamaBaseUrl = 'http://localhost:11434/api/generate';
  static const String ollamaModel = 'llama3.2';
  
  // Hugging Face (Free tier available)
  static const String huggingFaceApiKey = 'hf_YOUR_HUGGING_FACE_API_KEY_HERE';
  static const String huggingFaceBaseUrl = 'https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium';
  
  // Configuration
  static const bool useAI = true; // Set to false to disable AI enhancement
  static const String preferredProvider = 'groq'; // 'groq', 'openai', 'ollama', 'huggingface', 'cohere'
  
  // Cohere API (Free tier: 1000 requests/month)
  static const String cohereApiKey = 'PASTE_YOUR_COHERE_API_KEY_HERE';
  static const String cohereBaseUrl = 'https://api.cohere.ai/v1/generate';
  static const int maxTokens = 50; // Reduced for subtitle translation
  static const double temperature = 0.1; // Lower for more consistent translation
  
  // Get API key for current provider
  static String get apiKey {
    switch (preferredProvider) {
      case 'groq':
        return groqApiKey;
      case 'openai':
        return openaiApiKey;
      case 'huggingface':
        return huggingFaceApiKey;
      case 'cohere':
        return cohereApiKey;
      default:
        return '';
    }
  }
  
  // Get base URL for current provider
  static String get baseUrl {
    switch (preferredProvider) {
      case 'groq':
        return groqBaseUrl;
      case 'openai':
        return openaiBaseUrl;
      case 'ollama':
        return ollamaBaseUrl;
      case 'huggingface':
        return huggingFaceBaseUrl;
      case 'cohere':
        return cohereBaseUrl;
      default:
        return groqBaseUrl;
    }
  }
  
  // Check if API key is configured
  static bool get isConfigured {
    final key = apiKey;
    return key.isNotEmpty && !key.contains('YOUR_') && !key.contains('_HERE');
  }
}