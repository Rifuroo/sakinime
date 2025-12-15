# AI Translation Setup

Aplikasi ini menggunakan AI untuk meningkatkan kualitas terjemahan subtitle anime agar lebih natural dan sesuai konteks.

## Pilihan AI Provider

### 1. Groq (Recommended - Free & Fast)
- **Gratis**: 6000 requests/hour
- **Cepat**: Response time < 1 detik
- **Model**: Llama3-8B-8192

**Setup:**
1. Daftar di [console.groq.com](https://console.groq.com)
2. Buat API key
3. Edit `lib/config/ai_config.dart`:
```dart
static const String groqApiKey = 'gsk_your_actual_api_key_here';
```

### 2. OpenAI (Paid - High Quality)
- **Berbayar**: ~$0.002 per request
- **Kualitas tinggi**: GPT-3.5-turbo
- **Stabil**: Selalu available

**Setup:**
1. Daftar di [platform.openai.com](https://platform.openai.com)
2. Top up balance minimal $5
3. Buat API key
4. Edit `lib/config/ai_config.dart`:
```dart
static const String preferredProvider = 'openai';
static const String openaiApiKey = 'sk-your_actual_api_key_here';
```

### 3. Ollama (Free - Local)
- **Gratis**: 100% local, no internet needed
- **Private**: Data tidak keluar dari komputer
- **Requirement**: RAM 8GB+

**Setup:**
1. Install Ollama dari [ollama.ai](https://ollama.ai)
2. Download model: `ollama pull llama3.2`
3. Edit `lib/config/ai_config.dart`:
```dart
static const String preferredProvider = 'ollama';
```

### 4. Hugging Face (Free Tier)
- **Gratis**: 1000 requests/month
- **Open Source**: Berbagai model tersedia
- **Lambat**: Response time 3-5 detik

**Setup:**
1. Daftar di [huggingface.co](https://huggingface.co)
2. Buat access token
3. Edit `lib/config/ai_config.dart`:
```dart
static const String preferredProvider = 'huggingface';
static const String huggingFaceApiKey = 'hf_your_actual_token_here';
```

## Disable AI (Fallback)

Jika tidak ingin setup AI, set:
```dart
static const bool useAI = false;
```

Aplikasi akan tetap berfungsi dengan terjemahan basic tanpa AI enhancement.

## AI Prompt Examples

**Input**: "I can't believe this is happening!"
**Basic Translation**: "Saya tidak bisa percaya ini terjadi!"
**AI Enhanced**: "Gak percaya ini bisa terjadi!"

**Input**: "Thank you, senpai!"
**Basic Translation**: "Terima kasih, senpai!"
**AI Enhanced**: "Makasih, senpai!"

## Troubleshooting

### Error: API Key Invalid
- Pastikan API key benar dan tidak expired
- Check quota/balance untuk paid services

### Error: Network Timeout
- Check internet connection
- Try different provider (Ollama for offline)

### Error: Rate Limit
- Groq: Wait 1 hour atau upgrade plan
- OpenAI: Top up balance
- Hugging Face: Wait until next month

### AI Enhancement Not Working
- Check `AIConfig.isConfigured` returns true
- Check logs untuk error messages
- Fallback ke basic translation otomatis

## Performance Tips

1. **Cache**: AI results di-cache, tidak translate ulang
2. **Batch**: Multiple subtitles di-process bersamaan
3. **Timeout**: 5 detik timeout untuk AI calls
4. **Fallback**: Selalu ada fallback ke basic translation

## Privacy

- **Groq/OpenAI/HuggingFace**: Data dikirim ke server mereka
- **Ollama**: 100% local, data tidak keluar dari komputer
- **Cache**: Hasil AI disimpan local untuk performa