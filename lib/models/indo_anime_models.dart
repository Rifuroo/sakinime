// models/indo_anime_models.dart
import 'anime_model.dart';

/// Models specifically for OtakuDesu and Kuramanime sources
/// as they have native structures different from HiAnime.

class IndoHomeResponse {
  final List<Anime> ongoing;
  final List<Anime> completed;
  final List<Anime>? movies; // Specific to Kuramanime

  IndoHomeResponse({
    required this.ongoing,
    required this.completed,
    this.movies,
  });

  factory IndoHomeResponse.fromOtakuDesu(Map<String, dynamic> json) {
    final ongoing = (json['ongoing']?['animeList'] as List?)
            ?.map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    final completed = (json['completed']?['animeList'] as List?)
            ?.map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    return IndoHomeResponse(ongoing: ongoing, completed: completed);
  }

  factory IndoHomeResponse.fromKuramanime(Map<String, dynamic> json) {
    final ongoing = (json['ongoing']?['episodeList'] as List?)
            ?.map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    final completed = (json['completed']?['animeList'] as List?)
            ?.map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    final movies = (json['movie']?['animeList'] as List?)
            ?.map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    return IndoHomeResponse(
        ongoing: ongoing, completed: completed, movies: movies);
  }
}

class IndoEpisode {
  final String id;
  final String title;
  final String? number;

  IndoEpisode({
    required this.id,
    required this.title,
    this.number,
  });

  factory IndoEpisode.fromJson(Map<String, dynamic> json) {
    return IndoEpisode(
      id: json['id']?.toString() ?? json['episodeId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      number: json['number']?.toString() ?? json['episodeNumber']?.toString(),
    );
  }
}
