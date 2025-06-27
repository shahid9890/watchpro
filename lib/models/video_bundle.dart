import 'video.dart';

class VideoBundle {
  final String id;
  final String name;
  final int videoCount;
  final double price;
  final double totalEarnings;
  final double rewardPerVideo;
  final int dailyLimit;
  final List<String> videoIds;
  final List<Video>? videos;

  const VideoBundle({
    required this.id,
    required this.name,
    required this.videoCount,
    required this.price,
    required this.totalEarnings,
    required this.rewardPerVideo,
    required this.dailyLimit,
    required this.videoIds,
    this.videos,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'video_count': videoCount,
      'price': price,
      'reward': rewardPerVideo,
      'daily_limit': dailyLimit,
      'video_ids': videoIds,
      'videos': videos?.map((v) => v.toJson()).toList(),
    };
  }

  factory VideoBundle.fromJson(Map<String, dynamic> json) {
    final videosList = (json['videos'] as List?)?.map((v) => Video.fromJson(v)).toList();
    return VideoBundle(
      id: json['id'] as String,
      name: json['name'] as String,
      videoCount: json['video_count'] as int,
      price: (json['price'] as num).toDouble(),
      totalEarnings: (json['reward'] as num).toDouble() * (json['video_count'] as int),
      rewardPerVideo: (json['reward'] as num).toDouble(),
      dailyLimit: json['daily_limit'] as int,
      videoIds: (json['video_ids'] as List?)?.cast<String>() ?? [],
      videos: videosList,
    );
  }
} 