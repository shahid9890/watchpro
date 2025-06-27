class Video {
  final String id;
  final String title;
  final String url;
  final String? thumbnailUrl;
  final int duration; // in seconds
  final String bundleId;
  final DateTime createdAt;
  final bool isYoutubeVideo;

  const Video({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnailUrl,
    required this.duration,
    required this.bundleId,
    required this.createdAt,
    this.isYoutubeVideo = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'duration': duration,
      'bundle_id': bundleId,
      'created_at': createdAt.toIso8601String(),
      'is_youtube_video': isYoutubeVideo,
    };
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String;
    final isYoutube = url.contains('youtube.com') || url.contains('youtu.be');
    
    return Video(
      id: json['id'] as String,
      title: json['title'] as String,
      url: url,
      thumbnailUrl: json['thumbnail_url'] as String?,
      duration: json['duration'] as int,
      bundleId: json['bundle_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isYoutubeVideo: json['is_youtube_video'] as bool? ?? isYoutube,
    );
  }

  String get playbackUrl {
    if (!isYoutubeVideo) return url;
    
    // Extract YouTube video ID
    String? videoId;
    if (url.contains('youtube.com')) {
      videoId = Uri.parse(url).queryParameters['v'];
    } else if (url.contains('youtu.be')) {
      videoId = url.split('/').last;
    }
    
    // Return the direct YouTube URL
    return videoId != null ? 'https://www.youtube.com/watch?v=$videoId' : url;
  }

  String? get embedUrl {
    if (!isYoutubeVideo) return null;
    
    // Extract YouTube video ID
    String? videoId;
    if (url.contains('youtube.com')) {
      videoId = Uri.parse(url).queryParameters['v'];
    } else if (url.contains('youtu.be')) {
      videoId = url.split('/').last;
    }
    
    // Return the embed URL
    return videoId != null ? 'https://www.youtube.com/embed/$videoId' : null;
  }
}