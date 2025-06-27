import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_client.dart';
import '../models/user.dart' as app_user;
import '../models/transaction.dart';
import '../models/video_bundle.dart';
import '../models/video.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  final SupabaseClient _client = SupabaseConfig.client;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  String _generateReferralCode() {
    return const Uuid().v4().substring(0, 8).toUpperCase();
  }

  // User operations
  Future<app_user.User?> getUser(String email, String password) async {
    try {
      final hashedPassword = _hashPassword(password);
      final response = await _client
          .from('profile')
          .select()
          .eq('email', email)
          .eq('password', hashedPassword)
          .single();
      
      // Get purchased bundles
      final purchases = await _client
          .from('purchases')
          .select('bundle_id')
          .eq('user_id', response['id'])
          .eq('is_active', true);

      final user = app_user.User.fromJson(response);
      if (purchases != null) {
        user.purchasedBundles = (purchases as List)
            .map((p) => p['bundle_id'].toString())
            .toList();
      }
      return user;
    } catch (e) {
      debugPrint('Login error: $e');
      if (e is PostgrestException) {
        if (e.message.contains('Invalid single()') || 
            e.code == 'PGRST116') {
          return null; // User not found
        }
        throw Exception('Database error occurred. Please try again.');
      }
      throw Exception('Login failed. Please try again.');
    }
  }

  Future<app_user.User?> createUser(app_user.User user, String password) async {
    try {
      // First check if email already exists
      final existingUser = await _client
          .from('profile')
          .select('email')
          .eq('email', user.email)
          .maybeSingle();
      
      if (existingUser != null) {
        throw Exception('Email already registered');
      }

      String? referrerId;
      String referralCode = _generateReferralCode();
      int maxAttempts = 3;
      int currentAttempt = 0;

      while (currentAttempt < maxAttempts) {
        try {
          // Only process referral if a code is provided
          if (user.referredBy != null && user.referredBy!.isNotEmpty) {
            final referrer = await _client
                .from('profile')
                .select('id, referral_code')
                .eq('referral_code', user.referredBy!)  // Use non-null assertion since we checked above
                .maybeSingle();
            
            if (referrer != null) {
              referrerId = referrer['id'];
            } else {
              debugPrint('Invalid referral code provided: ${user.referredBy}');
            }
          }

          final userData = {
            'name': user.name,
            'email': user.email,
            'password': _hashPassword(password),
            'referral_code': referralCode,
            'referred_by': user.referredBy,
            'referrer_id': referrerId,
            'wallet_balance': 1000.0, // Default balance
            'referral_earnings': 0.0,
          };

          final response = await _client
              .from('profile')
              .insert(userData)
              .select()
              .single();
          
          return app_user.User.fromJson(response);
        } catch (e) {
          debugPrint('Registration attempt error: $e');
          if (e is PostgrestException) {
            if (e.code == '23505') { // Unique violation
              if (e.message.contains('email')) {
                throw Exception('Email already registered');
              } else if (e.message.contains('referral_code')) {
                // Generate a new referral code and try again
                referralCode = _generateReferralCode();
                currentAttempt++;
                if (currentAttempt >= maxAttempts) {
                  throw Exception('Failed to generate unique referral code after $maxAttempts attempts');
                }
                continue; // Try again with new referral code
              }
            }
            throw Exception('Database error occurred. Please try again.');
          }
          throw Exception('Registration failed. Please try again.');
        }
      }
      
      throw Exception('Failed to create user after $maxAttempts attempts');
    } catch (e) {
      debugPrint('Registration error: $e');
      rethrow;
    }
  }

  Future<void> updateUser(app_user.User user) async {
    try {
      await _client
          .from('profile')
          .update({
            'name': user.name,
            'wallet_balance': user.balance,
          })
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Update user error: $e');
      throw Exception('Failed to update user profile');
    }
  }

  // Bundle operations
  Future<List<VideoBundle>> getBundles() async {
    try {
      final response = await _client
          .from('bundles')
          .select('''
            *,
            videos (
              id, title, url, thumbnail_url, duration, 
              bundle_id, created_at, is_youtube_video
            )
          ''')
          .order('price');
      
      return (response as List).map((json) {
        final videos = (json['videos'] as List?)?.map((v) => Video.fromJson(v)).toList() ?? [];
        return VideoBundle(
          id: json['id'],
          name: json['name'],
          videoCount: json['video_count'] ?? 0,
          price: (json['price'] as num).toDouble(),
          totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
          rewardPerVideo: (json['reward_per_video'] as num).toDouble(),
          dailyLimit: json['daily_limit'] ?? 2,
          videoIds: videos.map((v) => v.id).toList(),
          videos: videos,
        );
      }).toList();
    } catch (e) {
      debugPrint('Get bundles error: $e');
      throw Exception('Failed to fetch video bundles');
    }
  }

  Future<bool> addVideoToBundle(String bundleId, String videoId) async {
    try {
      await _client
          .from('bundle_videos')
          .insert({
            'bundle_id': bundleId,
            'video_id': videoId,
          });
      return true;
    } catch (e) {
      debugPrint('Add video to bundle error: $e');
      throw Exception('Failed to add video to bundle');
    }
  }

  // Promotion operations
  Future<bool> submitPromotion(
    String userId,
    String videoUrl,
    String title,
  ) async {
    try {
      await _client.from('promotions').insert({
        'user_id': userId,
        'video_url': videoUrl,
        'title': title,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Submit promotion error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPromotions(String userId) async {
    try {
      final response = await _client
          .from('promotions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Get promotions error: $e');
      throw Exception('Failed to fetch promotions');
    }
  }

  // Wallet operations
  Future<void> updateWalletBalance(String userId, double amount) async {
    try {
      await _client.rpc('update_user_wallet_balance', params: {
        'p_user_id': userId,
        'p_amount': amount,
      });
    } catch (e) {
      debugPrint('Update wallet balance error: $e');
      throw Exception('Failed to update wallet balance');
    }
  }

  // Purchase operations
  Future<bool> purchaseBundle(String userId, VideoBundle bundle) async {
    try {
      // Start a transaction
      await _client.rpc('start_transaction');

      // Check user balance
      final user = await _client
          .from('profile')
          .select('wallet_balance')
          .eq('id', userId)
          .single();

      final balance = (user['wallet_balance'] as num).toDouble();
      if (balance < bundle.price) {
        throw Exception('Insufficient balance');
      }

      // Create purchase record
      await _client.from('purchases').insert({
        'user_id': userId,
        'bundle_id': bundle.id,
        'price': bundle.price,
        'is_active': true,
        'purchased_at': DateTime.now().toIso8601String(),
      });

      // Create transaction record
      await _client.from('transactions').insert({
        'user_id': userId,
        'amount': -bundle.price,
        'type': 'bundle_purchase',
        'status': 'completed',
        'description': 'Purchase of ${bundle.name}',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update user balance
      await _client.rpc(
        'update_user_wallet_balance',
        params: {
          'p_user_id': userId,
          'p_amount': -bundle.price,
        },
      );

      // Commit transaction
      await _client.rpc('commit_transaction');
      return true;
    } catch (e) {
      debugPrint('Purchase bundle error: $e');
      await _client.rpc('rollback_transaction');
      return false;
    }
  }

  Future<List<String>> getPurchasedBundles(String userId) async {
    try {
      final response = await _client
          .from('purchases')
          .select('bundle_id')
          .eq('user_id', userId)
          .eq('is_active', true);
      
      return (response as List)
          .map((json) => json['bundle_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('Get purchased bundles error: $e');
      throw Exception('Failed to fetch purchased bundles');
    }
  }

  // Video watch tracking
  Future<List<String>> getWatchedVideos(String userId, String bundleId) async {
    try {
      final response = await _client
          .from('watched_videos')
          .select('video_url')
          .eq('user_id', userId)
          .eq('bundle_id', bundleId)
          .eq('completed', true);
      
      return (response as List)
          .map((json) => json['video_url'] as String)
          .toList();
    } catch (e) {
      debugPrint('Get watched videos error: $e');
      throw Exception('Failed to fetch watched videos');
    }
  }

  Future<bool> recordVideoWatch(
    String userId,
    String bundleId,
    String videoId,
    int watchTimeSeconds,
  ) async {
    try {
      // Check if video exists in bundle
      final video = await _client
          .from('videos')
          .select()
          .eq('id', videoId)
          .eq('bundle_id', bundleId)
          .single();

      if (video == null) {
        throw Exception('Video not found in bundle');
      }

        // Record video watch
        await _client.from('watched_videos').insert({
          'user_id': userId,
          'bundle_id': bundleId,
        'video_id': videoId,
        'watch_time': watchTimeSeconds,
          'completed': true,
        'watched_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Update user's wallet balance with reward
      final bundle = await getBundleWithVideos(bundleId);
      if (bundle != null) {
        await updateWalletBalance(userId, bundle.rewardPerVideo);
      }

      return true;
    } catch (e) {
      debugPrint('Watch video error: $e');
      return false;
    }
  }

  Future<int> getWatchedVideosCountToday(String userId, String bundleId) async {
    try {
      final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
      final response = await _client
          .from('watched_videos')
          .select('id')
          .eq('user_id', userId)
          .eq('bundle_id', bundleId)
          .eq('completed', true)
          .gte('watched_at', '$today 00:00:00')
          .lte('watched_at', '$today 23:59:59');
      
      return (response as List).length;
    } catch (e) {
      debugPrint('Get watched videos count error: $e');
      return 0;
    }
  }

  // Transaction operations
  Future<List<Transaction>> getTransactions(String userId) async {
    try {
      final response = await _client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => Transaction.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Get transactions error: $e');
      throw Exception('Failed to fetch transactions');
    }
  }

  Future<void> addTransaction(String userId, Transaction transaction) async {
    try {
      await _client.from('wallet_transactions').insert({
        'user_id': userId,
        'type': transaction.type.toString().split('.').last,
        'amount': transaction.amount,
        'description': transaction.description,
      });
    } catch (e) {
      debugPrint('Add transaction error: $e');
      throw Exception('Failed to add transaction');
    }
  }

  // Withdrawal operations
  Future<bool> requestWithdrawal(String userId, double amount, String upiId) async {
    try {
      // Start a transaction
      await _client.rpc('start_transaction');

      // Check user balance
      final user = await _client
          .from('profile')
          .select('wallet_balance')
          .eq('id', userId)
          .single();

      final balance = (user['wallet_balance'] as num).toDouble();
      if (balance < amount) {
        throw Exception('Insufficient balance');
      }

      // Create withdrawal record
      await _client.from('withdrawals').insert({
        'user_id': userId,
        'amount': amount,
        'upi_id': upiId,
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      });

      // Create transaction record
      await _client.from('transactions').insert({
        'user_id': userId,
        'amount': -amount,
        'type': 'withdrawal',
        'status': 'pending',
        'description': 'Withdrawal request to UPI: $upiId',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update user balance immediately
      await _client.rpc(
        'update_user_wallet_balance',
        params: {
          'p_user_id': userId,
          'p_amount': -amount,
        },
      );

      // Commit transaction
      await _client.rpc('commit_transaction');
      return true;
    } catch (e) {
      debugPrint('Request withdrawal error: $e');
      await _client.rpc('rollback_transaction');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getWithdrawalHistory(String userId) async {
    try {
      final response = await _client
          .from('withdrawals')
          .select()
          .eq('user_id', userId)
          .order('requested_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Get withdrawal history error: $e');
      throw Exception('Failed to fetch withdrawal history');
    }
  }

  Future<double> getUserBalance(String userId) async {
    try {
      final response = await _client
          .from('profile')
          .select('wallet_balance')
          .eq('id', userId)
          .single();
      
      return (response['wallet_balance'] as num).toDouble();
    } catch (e) {
      debugPrint('Get user balance error: $e');
      throw Exception('Failed to fetch user balance');
    }
  }

  // Video operations
  Future<bool> createVideo({
    required String title,
    required String url,
    required String bundleId,
    String? thumbnailUrl,
    required int duration,
  }) async {
    try {
      final videoId = const Uuid().v4();
      
      await _client.rpc('start_transaction');

      try {
        await _client.from('videos').insert({
          'id': videoId,
          'title': title,
          'url': url,
          'thumbnail_url': thumbnailUrl,
          'duration': duration,
          'bundle_id': bundleId,
        });

        // Add video to bundle_videos table
        await _client.from('bundle_videos').insert({
          'bundle_id': bundleId,
          'video_id': videoId,
        });

        // Update video count in bundles table
        await _client.rpc('increment_bundle_video_count', params: {
          'bundle_id_param': bundleId,
        });

        await _client.rpc('commit_transaction');
        return true;
      } catch (e) {
        await _client.rpc('rollback_transaction');
        debugPrint('Create video transaction error: $e');
        throw Exception('Failed to create video');
      }
    } catch (e) {
      debugPrint('Create video error: $e');
      rethrow;
    }
  }

  Future<List<Video>> getBundleVideos(String bundleId) async {
    try {
      final response = await _client
          .from('videos')
          .select()
          .eq('bundle_id', bundleId)
          .order('created_at');
      
      return (response as List)
          .map((json) => Video.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Get bundle videos error: $e');
      throw Exception('Failed to fetch bundle videos');
    }
  }

  Future<bool> deleteVideo(String videoId, String bundleId) async {
    try {
      await _client.rpc('start_transaction');

      try {
        // Remove video from bundle_videos table
        await _client
            .from('bundle_videos')
            .delete()
            .eq('video_id', videoId);

        // Delete video from videos table
        await _client
            .from('videos')
            .delete()
            .eq('id', videoId);

        // Update video count in bundles table
        await _client.rpc('decrement_bundle_video_count', params: {
          'bundle_id_param': bundleId,
        });

        await _client.rpc('commit_transaction');
        return true;
      } catch (e) {
        await _client.rpc('rollback_transaction');
        debugPrint('Delete video transaction error: $e');
        throw Exception('Failed to delete video');
      }
    } catch (e) {
      debugPrint('Delete video error: $e');
      rethrow;
    }
  }

  Future<bool> updateVideo({
    required String videoId,
    String? title,
    String? url,
    String? thumbnailUrl,
    int? duration,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (url != null) updates['url'] = url;
      if (thumbnailUrl != null) updates['thumbnail_url'] = thumbnailUrl;
      if (duration != null) updates['duration'] = duration;

      if (updates.isEmpty) {
        return true; // No updates needed
      }

      await _client
          .from('videos')
          .update(updates)
          .eq('id', videoId);

      return true;
    } catch (e) {
      debugPrint('Update video error: $e');
      throw Exception('Failed to update video');
    }
  }

  Future<VideoBundle?> getBundleWithVideos(String bundleId) async {
    try {
      final response = await _client
          .from('bundles')
          .select('''
            *,
            videos (
              id, title, url, thumbnail_url, duration, 
              bundle_id, created_at, is_youtube_video
            )
          ''')
          .eq('id', bundleId)
          .single();

      if (response == null) return null;

      final videos = (response['videos'] as List?)?.map((v) => Video.fromJson(v)).toList() ?? [];
      return VideoBundle(
        id: response['id'],
        name: response['name'],
        videoCount: response['video_count'] ?? 0,
        price: (response['price'] as num).toDouble(),
        totalEarnings: (response['total_earnings'] as num?)?.toDouble() ?? 0.0,
        rewardPerVideo: (response['reward_per_video'] as num).toDouble(),
        dailyLimit: response['daily_limit'] ?? 2,
        videoIds: videos.map((v) => v.id).toList(),
        videos: videos,
      );
    } catch (e) {
      debugPrint('Get bundle with videos error: $e');
      return null;
    }
  }

  Future<app_user.User?> getUserById(String userId) async {
    try {
      final userData = await _client
          .from('profile')
          .select()
          .eq('id', userId)
          .single();
      
      return app_user.User.fromJson(userData);
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      if (e is PostgrestException && e.code == 'PGRST116') {
        return null; // User not found
      }
      throw Exception('Failed to fetch user');
    }
  }

  Future<List<Transaction>> getTransactionHistory(String userId) async {
    try {
      final List<dynamic> response = await _client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((json) => Transaction(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      )).toList();
    } catch (e) {
      debugPrint('Error getting transaction history: $e');
      throw Exception('Failed to fetch transaction history');
    }
  }

  Future<bool> createTransaction(Transaction transaction) async {
    try {
      await _client.from('transactions').insert({
        'id': transaction.id,
        'user_id': transaction.userId,
        'amount': transaction.amount,
        'description': transaction.description,
        'created_at': transaction.createdAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error creating transaction: $e');
      throw Exception('Failed to create transaction');
    }
  }

  Future<Video> getVideo(String videoId) async {
    try {
      final response = await _client
          .from('videos')
          .select()
          .eq('id', videoId)
          .single();
      
      return Video.fromJson(response);
    } catch (e) {
      debugPrint('Get video error: $e');
      throw Exception('Failed to fetch video');
    }
  }

  Future<String> getVideoUrl(String videoId) async {
    try {
      final video = await getVideo(videoId);
      return video.url;
    } catch (e) {
      debugPrint('Get video URL error: $e');
      throw Exception('Failed to fetch video URL');
    }
  }

  // Watch video
  Future<bool> watchVideo({
    required String userId,
    required String bundleId,
    required String videoId,
    required int watchTimeSeconds,
  }) async {
    try {
      // Check if video exists in bundle
      final video = await _client
          .from('videos')
          .select()
          .eq('id', videoId)
          .eq('bundle_id', bundleId)
          .single();
      
      if (video == null) {
        throw Exception('Video not found in bundle');
      }

      // Record video watch
      await _client.from('watched_videos').insert({
        'user_id': userId,
        'bundle_id': bundleId,
        'video_id': videoId,
        'watch_time': watchTimeSeconds,
        'completed': true,
        'watched_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Update user's wallet balance with reward
      final bundle = await getBundleWithVideos(bundleId);
      if (bundle != null) {
        await updateWalletBalance(userId, bundle.rewardPerVideo);
      }

      return true;
    } catch (e) {
      debugPrint('Watch video error: $e');
      return false;
    }
  }

  // Get watched video details
  Future<Map<String, dynamic>?> getWatchedVideo(
    String userId,
    String bundleId,
    String videoId,
  ) async {
    try {
      final response = await _client
          .from('watched_videos')
          .select()
          .eq('user_id', userId)
          .eq('bundle_id', bundleId)
          .eq('video_id', videoId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint('Get watched video error: $e');
      return null;
    }
  }
} 