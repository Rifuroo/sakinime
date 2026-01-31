import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class OCRService {
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Recognizes text from image bytes
  static Future<String?> recognizeText(Uint8List imageBytes) async {
    try {
      // Create a temporary file to store the image
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ocr_frame.jpg');
      await file.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFile(file);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Clean up
      if (await file.exists()) {
        await file.delete();
      }

      if (recognizedText.text.trim().isEmpty) return null;

      // Filter and clean the recognized text
      // We focus on the bottom part of the image where subtitles usually are
      // But for simplicity, we'll return the whole text and let the translator handle it
      return _cleanRecognizedText(recognizedText.text);
    } catch (e) {
      if (kDebugMode) print('❌ OCR Error: $e');
      return null;
    }
  }

  /// Clean recognized text (remove noise, typical OCR errors)
  static String _cleanRecognizedText(String text) {
    // Remove individual characters that are likely noise
    List<String> lines = text.split('\n');
    List<String> filteredLines = [];

    for (var line in lines) {
      String cleanLine = line.trim();
      if (cleanLine.length < 2) continue; // Skip single characters
      
      // Basic cleaning (OCR often misinterprets pipe symbols etc)
      cleanLine = cleanLine.replaceAll('|', 'I');
      cleanLine = cleanLine.replaceAll('0', 'O'); // Sometimes O/0 confusion
      
      filteredLines.add(cleanLine);
    }

    return filteredLines.join(' ');
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
