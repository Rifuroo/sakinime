// utils/image_proxy.dart
class ImageProxy {
  static const String baseUrl = 'https://apiconsumetorg-blond.vercel.app';
  
  /// Get proxied image URL with proper headers for Zoro images
  static String getProxiedUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    
    // If already using proxy, return as is
    if (imageUrl.contains('/image-proxy')) return imageUrl;
    
    // Encode the image URL
    final encodedUrl = Uri.encodeComponent(imageUrl);
    
    // Create headers object for Referer
    final headers = {
      'Referer': 'https://hianime.to/',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };
    
    final encodedHeaders = Uri.encodeComponent(headers.toString());
    
    // Return proxied URL
    return '$baseUrl/image-proxy?url=$encodedUrl&headers=$encodedHeaders';
  }
  
  /// Simple proxy for images that don't need special headers
  static String getSimpleProxy(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    if (imageUrl.contains('/image-proxy')) return imageUrl;
    
    final encodedUrl = Uri.encodeComponent(imageUrl);
    return '$baseUrl/image-proxy?url=$encodedUrl&headers={}';
  }
}
