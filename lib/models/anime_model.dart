// models/anime_model.dart - FIXED: Genre parsing that was causing crashes
import 'package:flutter/foundation.dart';

class StreamLink {
  final String provider;
  final String url;
  final String type;
  final String? quality;
  final String? size;
  final String? source;
  final String? serverId;
  final String? format;
  final String? note;
  final Map<String, String>? headers;

  StreamLink({
    required this.provider,
    required this.url,
    required this.type,
    this.quality,
    this.size,
    this.source,
    this.serverId,
    this.format,
    this.note,
    this.headers,
  });

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    return StreamLink(
      provider: json['provider'] ?? json['server'] ?? json['name'] ?? 'Unknown',
      url: json['url'] ?? json['link'] ?? '',
      type: json['type'] ?? json['format'] ?? 'iframe',
      quality: json['quality'] ?? json['resolution'],
      size: json['size'],
      source: json['source'],
      serverId: json['serverId'] ?? json['id'] ?? json['post'],
      format: json['format'],
      note: json['note'],
      headers: json['headers'] != null ? Map<String, String>.from(json['headers']) : null,
    );
  }

  bool get isIframe => type.toLowerCase() == 'iframe' || type.toLowerCase() == 'embed';
  bool get isDirect => type == 'mp4' || type == 'hls';
  bool get isDownload => type.toLowerCase() == 'download';
  String get displayQuality => quality ?? 'Auto';
  
  String get displayType {
    switch (type.toLowerCase()) {
      case 'iframe':
      case 'embed':
        return 'Stream';
      case 'mp4':
        return 'MP4';
      case 'hls':
        return 'HLS';
      case 'download':
        return 'Download';
      default:
        return type.toUpperCase();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'url': url,
      'type': type,
      'quality': quality,
      'size': size,
      'source': source,
      'serverId': serverId,
      'format': format,
      'note': note,
      'headers': headers,
    };
  }
}

// ✅ FIXED: Safe genre parsing that handles all API response formats
List<String>? _parseGenreList(dynamic genreList) {
  if (genreList == null) return null;
  
  try {
    // Case 1: Already a List
    if (genreList is List) {
      final result = <String>[];
      
      // ✅ FIX: Use standard for loop instead of iterator to avoid index errors
      for (var i = 0; i < genreList.length; i++) {
        try {
          final item = genreList[i];
          
          if (item is Map) {
            final title = item['title']?.toString() ?? 
                         item['name']?.toString() ?? 
                         item['genreId']?.toString() ?? '';
            if (title.isNotEmpty) {
              result.add(title);
            }
          } else if (item is String && item.isNotEmpty) {
            result.add(item);
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Skipping genre at index $i: $e');
          continue;
        }
      }
      
      return result.isEmpty ? null : result;
    }
    
    // Case 2: Single Map object
    if (genreList is Map) {
      final title = genreList['title']?.toString() ?? 
                   genreList['name']?.toString() ?? 
                   genreList['genreId']?.toString() ?? '';
      if (title.isNotEmpty) {
        return [title];
      }
    }
    
    // Case 3: Single String
    if (genreList is String && genreList.isNotEmpty) {
      return [genreList];
    }
    
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Error parsing genreList: $e');
      print('   genreList type: ${genreList.runtimeType}');
    }
  }
  
  return null;
}

class Anime {
  final String id;
  final String title;
  final String poster;
  final String? synopsis;
  final String? latestEpisode;
  final String? url;
  final String? episode;
  final int? totalEpisodes;
  final String? status;
  final String? rating;
  final String? type;
  final String? score;
  final List<String>? genres;
  final String? nextEpisodeDate; // ISO string for countdown
  final String? bannerImage;
  final String? description; // Alias for synopsis to match some UI calls

  Anime({
    required this.id,
    required this.title,
    required this.poster,
    this.synopsis,
    this.latestEpisode,
    this.url,
    this.episode,
    this.totalEpisodes,
    this.status,
    this.rating,
    this.type,
    this.score,
    this.genres,
    this.nextEpisodeDate,
    this.bannerImage,
    this.description,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    try {
      // ✅ STEP 1: Extract animeId - HiAnime API uses 'id' field
      String animeId = '';
      
      // Priority: id > slug > animeId
      if (json['id'] != null && json['id'].toString().isNotEmpty) {
        animeId = json['id'].toString();
      } else if (json['slug'] != null && json['slug'].toString().isNotEmpty) {
        animeId = json['slug'].toString();
      } else if (json['animeId'] != null && json['animeId'].toString().isNotEmpty) {
        animeId = json['animeId'].toString();
      } else if (json['href'] != null) {
        animeId = json['href'].toString().replaceAll('/anime/', '').split('/').last;
      }
      
      animeId = animeId.replaceAll('/', '').trim();
      
      if (kDebugMode) print('   ✅ animeId: $animeId');
      
      // ✅ STEP 2: Extract title - HiAnime uses 'title' or 'alternativeTitle'
      String animeTitle = json['title']?.toString() ?? 
                         json['alternativeTitle']?.toString() ?? 
                         json['anime_name']?.toString() ?? '';
      
      // ✅ STEP 3: Extract poster - HiAnime uses 'poster'
      String posterImage = json['poster']?.toString() ?? json['image']?.toString() ?? '';
      
      if (posterImage.isEmpty) {
        final shortTitle = animeTitle.length > 20 
            ? animeTitle.substring(0, 20) + "..." 
            : animeTitle;
        posterImage = 'https://placehold.co/300x400/1a1f3a/white?text=${Uri.encodeComponent(shortTitle)}';
      }
      
      if (kDebugMode) print('   ✅ Title & poster OK');
      
      // ✅ STEP 4: Extract episodes - HiAnime uses 'episodes' object with sub/dub/eps
      int? totalEps;
      if (json['episodes'] is Map) {
        // HiAnime format: { sub: 10, dub: 8, eps: 10 }
        final eps = json['episodes'];
        totalEps = eps['eps'] ?? eps['sub'] ?? eps['dub'];
      } else if (json['episode_count'] != null) {
        totalEps = int.tryParse(json['episode_count'].toString());
      } else if (json['total_episode'] != null) {
        totalEps = int.tryParse(json['total_episode'].toString());
      } else if (json['episodes'] != null) {
        totalEps = int.tryParse(json['episodes'].toString());
      }
      
      if (kDebugMode) print('   ✅ Episodes OK');
      
      // ✅ STEP 5: Extract latest episode
      String? latestEp;
      try {
        latestEp = json['current_episode']?.toString() ?? 
                   json['newest_release_date']?.toString() ??
                   json['last_release_date']?.toString() ??
                   json['releasedOn']?.toString();
      } catch (e) {
        latestEp = null;
      }

      if (kDebugMode) print('   🎬 Parsing genres...');
      
      // ✅ STEP 6: Parse genres safely
      List<String>? genreList;
      try {
        // Support both legacy `genreList` and Zoro's `genres` (array of strings)
        genreList = _parseGenreList(json['genreList'] ?? json['genres']);
      } catch (e) {
        if (kDebugMode) print('   ⚠️ Genre parse error: $e');
        genreList = null;
      }

      if (kDebugMode) {
        if (genreList != null && genreList.isNotEmpty) {
          print('   ✅ Genres: ${genreList.join(", ")}');
        } else {
          print('   ℹ️ No genres found');
        }
      }

      // ✅ STEP 7: Extract all other fields safely
      String? synopsisText;
      try {
        synopsisText = json['synopsis']?.toString() ?? json['description']?.toString();
      } catch (e) {
        synopsisText = null;
      }
      
      String? animeUrl;
      try {
        animeUrl = json['samehadakuUrl']?.toString() ?? json['otakudesuUrl']?.toString();
      } catch (e) {
        animeUrl = null;
      }
      
      String? episodeText;
      try {
        episodeText = json['episode']?.toString();
      } catch (e) {
        episodeText = null;
      }
      
      String? statusText;
      try {
        statusText = json['status']?.toString();
      } catch (e) {
        statusText = null;
      }
      
      String? typeText;
      try {
        typeText = json['type']?.toString();
      } catch (e) {
        typeText = null;
      }
      
      // ✅ STEP 8: Extract rating/score safely - Match Expo's extensive fallbacks
      String? ratingText;
      String? scoreText;
      
      try {
        // Check list of possible score/rating fields
        final possibleFields = [
          'malScore', 'averageScore', 'MAL_score', 'rating', 'score', 'stats.rating', 'moreInfo.score'
        ];

        for (var field in possibleFields) {
           dynamic val;
           if (field.contains('.')) {
              final parts = field.split('.');
              val = json[parts[0]]?[parts[1]];
           } else {
              val = json[field];
           }

           if (val != null && val.toString().isNotEmpty && val.toString() != 'null') {
              if (val is Map && val['value'] != null) {
                ratingText = val['value'].toString();
                break;
              } else {
                ratingText = val.toString();
                break;
              }
           }
        }
        scoreText = ratingText;
      } catch (e) {
        if (kDebugMode) print('   ⚠️ Rating/Score parse error: $e');
        ratingText = null;
        scoreText = null;
      }

      if (kDebugMode) print('   ✅ Creating Anime object...');

      // ✅ STEP 9: Create Anime object
      return Anime(
        id: animeId,
        title: animeTitle,
        poster: posterImage,
        synopsis: synopsisText,
        latestEpisode: latestEp,
        url: animeUrl,
        episode: episodeText,
        totalEpisodes: totalEps,
        status: statusText,
        rating: ratingText,
        type: typeText,
        score: scoreText,
        genres: genreList,
        nextEpisodeDate: json['nextEpisodeDate']?.toString() ?? 
                         json['airing_at']?.toString() ?? 
                         json['next_episode_at']?.toString(),
        bannerImage: json['bannerImage']?.toString() ?? json['image']?.toString(),
        description: synopsisText,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ ERROR in Anime.fromJson:');
        print('   Error: $e');
        final lines = stackTrace.toString().split('\n');
        if (lines.isNotEmpty) {
          print('   Stack: ${lines[0]}');
          if (lines.length > 1) print('          ${lines[1]}');
        }
      }
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster': poster,
      'synopsis': synopsis,
      'latestEpisode': latestEpisode,
      'url': url,
      'episode': episode,
      'totalEpisodes': totalEpisodes,
      'status': status,
      'rating': rating,
      'type': type,
      'score': score,
      'genres': genres,
      'nextEpisodeDate': nextEpisodeDate,
      'bannerImage': bannerImage,
      'description': description,
    };
  }
}

class AnimeDetail {
  final String id;
  final String title;
  final String poster;
  final String synopsis;
  final List<Episode> episodes;
  final Map<String, String> info;
  final String? status;
  final String? rating;
  final List<String>? genres;
  final Map<String, dynamic>? batch;
  final String? type;
  final String? score;
  final String? bannerImage;

  final List<Anime> relatedAnime;
  final List<Anime> recommendedAnime;
  final String? nextEpisodeDate;

  AnimeDetail({
    required this.id,
    required this.title,
    required this.poster,
    required this.synopsis,
    required this.episodes,
    required this.info,
    this.status,
    this.rating,
    this.genres,
    this.batch,
    this.type,
    this.score,
    this.relatedAnime = const [],
    this.recommendedAnime = const [],
    this.nextEpisodeDate,
    this.bannerImage,
  });

  factory AnimeDetail.fromJson(Map<String, dynamic> json) {
    // Better title handling with priority
    String animeTitle = json['title']?.toString().trim() ?? '';
    
    if (animeTitle.isEmpty) {
      if (json['english'] != null && json['english'].toString().trim().isNotEmpty) {
        animeTitle = json['english'].toString().trim();
      } else if (json['japanese'] != null && json['japanese'].toString().trim().isNotEmpty) {
        animeTitle = json['japanese'].toString().trim();
      } else if (json['synonyms'] != null && json['synonyms'].toString().trim().isNotEmpty) {
        animeTitle = json['synonyms'].toString().trim();
      } else {
        animeTitle = 'Unknown Title';
      }
    }

    // Extract anime ID
    String animeId = json['slug'] ?? json['animeId'] ?? json['id'] ?? '';
    animeId = animeId.replaceAll('/', '').trim();

    // ✅ FIX: Parse episodes dengan multiple field names
    final episodes = <Episode>[];
    
    // Try berbagai field names yang mungkin digunakan API
    final episodesList = json['episode_lists'] ?? 
                        json['episodeList'] ?? 
                        json['episodes'] ?? 
                        [];
    
    if (kDebugMode) {
      print('🎬 Parsing episodes from: ${episodesList.runtimeType}');
      if (episodesList is List) {
        print('   Found ${episodesList.length} episodes');
        // ✅ CRITICAL: Print first episode structure
        if (episodesList.isNotEmpty) {
          print('   📋 First episode structure:');
          print('      ${episodesList[0]}');
        }
      }
    }
    
    if (episodesList is List && episodesList.isNotEmpty) {
      for (var i = 0; i < episodesList.length; i++) {
        try {
          final ep = episodesList[i];
          if (kDebugMode) print('   Parsing episode $i: ${ep.runtimeType}');
          episodes.add(Episode.fromJson(ep));
        } catch (e) {
          if (kDebugMode) print('   ⚠️ Failed to parse episode $i: $e');
        }
      }
    }
    
    if (kDebugMode) {
      print('✅ Successfully parsed ${episodes.length} episodes');
      if (episodes.isNotEmpty) {
        print('   🎯 Sample URLs:');
        final sampleCount = episodes.length < 3 ? episodes.length : 3;
        for (var i = 0; i < sampleCount; i++) {
          print('      Ep ${episodes[i].episodeNumber}: "${episodes[i].url}"');
        }
      }
    }

    // Build info map
    final info = <String, String>{};
    
    if (json['score'] != null) {
      if (json['score'] is Map && json['score']['value'] != null) {
        info['Score'] = json['score']['value'].toString();
      } else {
        info['Score'] = json['score'].toString();
      }
    }
    
    if (json['rating'] != null) info['Rating'] = json['rating'].toString();
    if (json['type'] != null) info['Type'] = json['type'].toString();
    if (json['status'] != null) info['Status'] = json['status'].toString();
    if (json['status'] != null) info['Status'] = json['status'].toString();
    // ✅ Use totalEpisodes instead of episodes array
    if (json['totalEpisodes'] != null) info['Total Episodes'] = json['totalEpisodes'].toString();
    if (json['duration'] != null) info['Duration'] = json['duration'].toString();
    
    // ✅ Formatting Aired Date
    if (json['aired'] != null) {
      final airedData = json['aired'];
      if (airedData is Map) {
        final from = airedData['from']?.toString() ?? '';
        final to = airedData['to']?.toString() ?? '';
        if (from.isNotEmpty && to.isNotEmpty) {
          info['Aired'] = '$from - $to';
        } else if (from.isNotEmpty) {
          info['Aired'] = from;
        } else {
          info['Aired'] = 'Unknown';
        }
      } else {
        info['Aired'] = airedData.toString();
      }
    }
    
    if (json['premiered'] != null) info['Premiered'] = json['premiered'].toString();
    
    // ✅ FIX: Handle studios/producers as List or String
    if (json['studios'] != null) {
      if (json['studios'] is List) {
        info['Studio'] = (json['studios'] as List).map((e) => e is Map ? e['name'] ?? e.toString() : e.toString()).join(', ');
      } else {
        info['Studio'] = json['studios'].toString();
      }
    }
    if (json['producers'] != null) {
      if (json['producers'] is List) {
        info['Producers'] = (json['producers'] as List).map((e) => e is Map ? e['name'] ?? e.toString() : e.toString()).join(', ');
      } else {
        info['Producers'] = json['producers'].toString();
      }
    }
    
    if (json['season'] != null) info['Season'] = json['season'].toString();
    if (json['source'] != null) info['Source'] = json['source'].toString();
    // ✅ Add subOrDub info from Zoro
    if (json['subOrDub'] != null) info['Sub/Dub'] = json['subOrDub'].toString();
    // ✅ Add MAL score
    if (json['MAL_score'] != null) info['MAL Score'] = json['MAL_score'].toString();

    // ✅ Synopsis - check both description and synopsis
    String synopsisText = 'Synopsis not available.';
    
    // Priority 1: description field (Zoro API)
    if (json['description'] != null && json['description'].toString().trim().isNotEmpty) {
      synopsisText = json['description'].toString().trim();
    }
    // Priority 2: synopsis field
    else if (json['synopsis'] != null) {
      final synopsisData = json['synopsis'];
      if (synopsisData is Map && synopsisData['paragraphs'] is List) {
        final paragraphs = synopsisData['paragraphs'] as List;
        if (paragraphs.isNotEmpty) {
          synopsisText = paragraphs.join('\n\n');
        }
      } else if (synopsisData is String && synopsisData.isNotEmpty) {
        synopsisText = synopsisData;
      }
    }

    // ✅ FIXED: Use safe genre parsing - Match Expo's fallbacks
    final genreList = _parseGenreList(
      json['genreList'] ?? json['genres'] ?? json['moreInfo']?['genres']
    );

    // Batch info
    Map<String, dynamic>? batchInfo;
    if (json['batch'] is Map) {
      batchInfo = Map<String, dynamic>.from(json['batch']);
    }

    // Poster
    String posterImage = json['poster'] ?? json['image'] ?? '';
    if (posterImage.isEmpty) {
      final shortTitle = animeTitle.length > 20 
          ? animeTitle.substring(0, 20) + "..." 
          : animeTitle;
      posterImage = 'https://placehold.co/300x400/1a1f3a/white?text=${Uri.encodeComponent(shortTitle)}';
    }

    // ✅ Related & Recommended
    final related = <Anime>[];
    if (json['relatedAnimes'] is List) {
      for (var item in json['relatedAnimes']) {
        try { related.add(Anime.fromJson(Map<String, dynamic>.from(item))); } catch (_) {}
      }
    }
    
    final recommended = <Anime>[];
    if (json['recommendedAnimes'] is List) {
      for (var item in json['recommendedAnimes']) {
        try { recommended.add(Anime.fromJson(Map<String, dynamic>.from(item))); } catch (_) {}
      }
    }

    return AnimeDetail(
      id: animeId,
      title: animeTitle,
      poster: posterImage,
      synopsis: synopsisText,
      episodes: episodes,
      info: info,
      status: json['status'],
      rating: json['score']?['value']?.toString() ?? json['rating']?.toString(),
      genres: genreList,
      batch: batchInfo,
      type: json['type'],
      score: json['score']?['value']?.toString() ?? json['rating']?.toString(),
      relatedAnime: related,
      recommendedAnime: recommended,
      nextEpisodeDate: json['nextEpisodeDate']?.toString() ?? 
                         json['airing_at']?.toString() ?? 
                         json['next_episode_at']?.toString(),
      bannerImage: json['bannerImage']?.toString() ?? json['image']?.toString(),
    );
  }

  // Helpers for UI
  String? get japanese => info['Japanese'];
  String? get synonyms => info['Synonyms'];
  String? get aired => info['Aired'];
  String? get studios => info['Studio'];
  String? get producers => info['Producers'];
  String? get duration => info['Duration'];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster': poster,
      'synopsis': synopsis,
      'episodes': episodes.map((e) => e.toJson()).toList(),
      'info': info,
      'status': status,
      'rating': rating,
      'genres': genres,
      'batch': batch,
      'type': type,
      'score': score,
    };
  }
}

class Character {
  final String id;
  final String name;
  final String? image;
  final String? role;

  Character({
    required this.id,
    required this.name,
    this.image,
    this.role,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id']?.toString() ?? json['character_id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['character_name']?.toString() ?? 'Unknown',
      image: json['imageUrl']?.toString() ?? json['image']?.toString() ?? json['poster']?.toString(),
      role: json['role']?.toString(),
    );
  }
}



class Episode {
  final String number;
  final String date;
  final String url;
  final String? title;
  final int? episodeNumber;

  Episode({
    required this.number,
    required this.date,
    required this.url,
    this.title,
    this.episodeNumber,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('🔍 Episode.fromJson: $json');
    }
    
    String episodeTitle = '';
    int? episodeNum;
    
    // ✅ HiAnime uses episodeNumber directly
    if (json['episodeNumber'] != null) {
      if (json['episodeNumber'] is int) {
        episodeNum = json['episodeNumber'] as int;
      } else {
        episodeNum = int.tryParse(json['episodeNumber'].toString());
      }
      if (kDebugMode) print('   📍 episodeNumber: $episodeNum');
    }
    // ✅ Zoro fields fallback
    else if (json['number'] != null) {
      if (json['number'] is int) {
        episodeNum = json['number'] as int;
      } else {
        episodeNum = int.tryParse(json['number'].toString());
      }
      if (kDebugMode) print('   📍 number: $episodeNum');
    }

    // Title
    if (json['title'] != null && json['title'].toString().isNotEmpty) {
      episodeTitle = json['title'].toString();
    } else if (episodeNum != null) {
      episodeTitle = 'Episode $episodeNum';
    }
    
    // Legacy fallback
    if (episodeNum == null && json['episode_number'] != null) {
      episodeNum = int.tryParse(json['episode_number'].toString());
      if (episodeTitle.isEmpty && episodeNum != null) episodeTitle = 'Episode $episodeNum';
    }
    
    String episodeUrl = '';
    
    // ✅ Zoro uses `id` for episode id - Match Expo's episodeId fallback
    if (json['id'] != null && json['id'].toString().isNotEmpty) {
      episodeUrl = json['id'].toString();
      if (kDebugMode) print('   ✅ URL from id: $episodeUrl');
    } else if (json['episodeId'] != null && json['episodeId'].toString().isNotEmpty) {
      episodeUrl = json['episodeId'].toString();
      if (kDebugMode) print('   ✅ URL from episodeId: $episodeUrl');
    } else if (json['slug'] != null && json['slug'].toString().isNotEmpty) {
      episodeUrl = json['slug'].toString();
      if (kDebugMode) print('   ✅ URL from slug: $episodeUrl');
    } else if (json['href'] != null && json['href'].toString().isNotEmpty) {
      final href = json['href'].toString();
      final match = RegExp(r'/episode/([^/]+)').firstMatch(href);
      if (match != null) {
        episodeUrl = match.group(1)!;
        if (kDebugMode) print('   ✅ URL from href: $episodeUrl');
      }
    }
    
    // Clean URL
    episodeUrl = episodeUrl.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    
    String episodeDate = json['otakudesu_url'] ?? json['samehadakuUrl'] ?? '';
    
    if (kDebugMode) {
      print('   🎯 FINAL: Ep $episodeNum -> "$episodeUrl"');
    }
    
    return Episode(
      number: episodeNum?.toString() ?? json['number']?.toString() ?? '?',
      date: episodeDate,
      url: episodeUrl,
      title: episodeTitle,
      episodeNumber: episodeNum,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'date': date,
      'url': url,
      'title': title,
      'episodeNumber': episodeNumber,
    };
  }
}

class ScheduleItem {
  final String? id;
  final String time;
  final String name;
  final String? jname;
  final String episode;

  ScheduleItem({
    this.id,
    required this.time,
    required this.name,
    this.jname,
    required this.episode,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    // Convert time from JST to WIB (JST is UTC+9, WIB is UTC+7, so -2 hours)
    String convertedTime = json['time']?.toString() ?? '';
    if (convertedTime.isNotEmpty) {
      try {
        final parts = convertedTime.split(':');
        if (parts.length == 2) {
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1]);
          
          // Subtract 2 hours for WIB
          hour -= 2;
          if (hour < 0) hour += 24;
          
          convertedTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        // Keep original time if conversion fails
      }
    }
    
    return ScheduleItem(
      id: json['id']?.toString(),
      time: convertedTime,
      name: json['title']?.toString() ?? json['name']?.toString() ?? '',
      jname: json['alternativeTitle']?.toString() ?? json['jname']?.toString(),
      episode: 'Episode ${json['episode']?.toString() ?? ''}',
    );
  }
}

class Watch2GetherRoom {
  final String id;
  final String? animeId;
  final String? animeTitle;
  final String? roomTitle;
  final String? poster;
  final String? episode;
  final String? type;
  final String status;
  final String? createdBy;
  final String? createdAt;
  final String? url;

  Watch2GetherRoom({
    required this.id,
    this.animeId,
    this.animeTitle,
    this.roomTitle,
    this.poster,
    this.episode,
    this.type,
    required this.status,
    this.createdBy,
    this.createdAt,
    this.url,
  });

  factory Watch2GetherRoom.fromJson(Map<String, dynamic> json) {
    return Watch2GetherRoom(
      id: json['id']?.toString() ?? '',
      animeId: json['animeId']?.toString(),
      animeTitle: json['animeTitle']?.toString(),
      roomTitle: json['roomTitle']?.toString(),
      poster: json['poster']?.toString(),
      episode: json['episode']?.toString(),
      type: json['type']?.toString(),
      status: json['status']?.toString() ?? 'On-air',
      createdBy: json['createdBy']?.toString(),
      createdAt: json['createdAt']?.toString(),
      url: json['url']?.toString(),
    );
  }
}
