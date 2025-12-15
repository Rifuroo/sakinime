# 🆓 FREE AI API SETUP GUIDE

## 🚀 GROQ (RECOMMENDED - SUPER FAST & FREE)

**Limits**: 6000 requests/hour (sangat banyak!)
**Speed**: < 1 detik response
**Model**: Llama3-8B (sangat bagus)

### Setup Steps:
1. **Buka**: [console.groq.com](https://console.groq.com)
2. **Sign Up** dengan email
3. **Verify email** dari inbox
4. **Login** → Dashboard
5. **Klik "API Keys"** di sidebar
6. **Create New Key** → nama: "anime-translator"
7. **Copy API Key** (format: `gsk_xxxxxxxxxxxxx`)
8. **Paste** di `lib/config/ai_config.dart`:
```dart
static const String groqApiKey = 'gsk_your_actual_key_here';
```

---

## 🤗 HUGGING FACE (FREE TIER)

**Limits**: 1000 requests/month
**Speed**: 3-5 detik response
**Model**: Various open source models

### Setup Steps:
1. **Buka**: [huggingface.co](https://huggingface.co)
2. **Sign Up** dengan email
3. **Profile** → **Settings** → **Access Tokens**
4. **New Token** → nama: "anime-translator" → **Read**
5. **Copy Token** (format: `hf_xxxxxxxxxxxxx`)
6. **Edit config**:
```dart
static const String preferredProvider = 'huggingface';
static const String huggingFaceApiKey = 'hf_your_actual_token_here';
```

---

## 🧠 COHERE (FREE TIER)

**Limits**: 1000 requests/month
**Speed**: 2-3 detik response
**Model**: Command-Light

### Setup Steps:
1. **Buka**: [cohere.ai](https://cohere.ai)
2. **Sign Up** dengan email
3. **Dashboard** → **API Keys**
4. **Create API Key** → nama: "anime-translator"
5. **Copy Key** (format: `co_xxxxxxxxxxxxx`)
6. **Edit config**:
```dart
static const String preferredProvider = 'cohere';
static const String cohereApiKey = 'co_your_actual_key_here';
```

---

## 📊 COMPARISON

| Provider | Free Limit | Speed | Quality | Setup |
|----------|------------|-------|---------|-------|
| **Groq** | 6000/hour | ⚡⚡⚡ | 🌟🌟🌟🌟 | Easy |
| Hugging Face | 1000/month | ⚡ | 🌟🌟🌟 | Easy |
| Cohere | 1000/month | ⚡⚡ | 🌟🌟🌟 | Easy |

---

## 🎯 RECOMMENDED SETUP

**For Heavy Usage**: Groq (6000/hour = 200 anime episodes/day)
**For Light Usage**: Cohere atau Hugging Face

**Best Strategy**: Setup Groq sebagai primary, Cohere sebagai backup

---

## 🔧 QUICK SETUP (GROQ)

1. **Get API Key**: [console.groq.com](https://console.groq.com) → API Keys → Create
2. **Edit File**: `lib/config/ai_config.dart`
3. **Replace**:
```dart
static const String groqApiKey = 'PASTE_YOUR_KEY_HERE';
```
4. **Done!** AI translation siap digunakan

---

## ❌ DISABLE AI (If No Setup)

Jika malas setup AI, bisa disable:
```dart
static const bool useAI = false;
```

Aplikasi tetap jalan dengan basic translation (tanpa AI enhancement).

---

## 🧪 TEST AI

Setelah setup, test dengan:
1. Buka anime
2. Pilih subtitle → AI Translation → Bahasa Indonesia
3. Lihat subtitle berubah jadi lebih natural!

**Before AI**: "Saya tidak bisa percaya ini!"
**After AI**: "Gak percaya ini bisa terjadi!"