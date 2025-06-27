import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user.dart';
import '../models/video_bundle.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';
import 'package:flutter/foundation.dart';

class AppProvider extends ChangeNotifier {
  static const String _userKey = 'user_data';
  final Box _box;
  final SupabaseService _service;
  User? _user;
  List<Transaction> _transactions = [];
  List<VideoBundle> _bundles = [];
  List<Map<String, dynamic>> _promotions = [];
  bool _isLoading = false;

  AppProvider() : 
    _box = Hive.box('appBox'),
    _service = SupabaseService() {
    _loadData();
  }

  User? get user => _user;
  List<VideoBundle> get bundles => List.unmodifiable(_bundles);
  List<Transaction> get transactions => List.unmodifiable(_transactions);
  List<Map<String, dynamic>> get promotions => List.unmodifiable(_promotions);
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _loadData() async {
    _setLoading(true);
    try {
      final userData = await _box.get(_userKey);
      if (userData != null) {
        final Map<String, dynamic> userMap = jsonDecode(userData);
        _user = User.fromJson(userMap);
        await _loadUserData();
      }
      await loadBundles();
    } catch (e) {
      debugPrint('Error loading data: $e');
      await _box.delete(_userKey);
      _user = null;
      _transactions = [];
      _bundles = [];
      _promotions = [];
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;
    
    try {
      await loadBundles();

      final transactions = await _service.getTransactionHistory(_user!.id);
      _transactions = transactions;

      final promotions = await _service.getPromotions(_user!.id);
      _promotions = promotions;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
      // Don't clear data on error, keep existing data
    }
  }

  Future<void> loadBundles() async {
    try {
      final bundles = await _service.getBundles();
      _bundles = bundles;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading bundles: $e');
      // Keep existing bundles on error
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _saveData() async {
    try {
      if (_user != null) {
        final String userData = jsonEncode(_user!.toJson());
        await _box.put(_userKey, userData);
        await _service.updateUser(_user!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error saving data: $e');
      rethrow;
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final user = await _service.getUser(email, password);
      if (user != null) {
        _user = user;
        await _loadUserData();
        await _saveData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(String name, String email, String password, String? referralCode) async {
    _setLoading(true);
    try {
      final user = User(
        id: '', // Will be set by the database
        name: name,
        email: email,
        referralCode: '', // Will be set by the database
        balance: 1000,
        referredBy: referralCode,
        purchasedBundles: const [],
        referralEarnings: 0,
      );
      
      final createdUser = await _service.createUser(user, password);
      if (createdUser != null) {
        _user = createdUser;
        await _loadUserData();
        await _saveData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> submitPromotion(String videoUrl, String title) async {
    if (_user == null) return false;

    _setLoading(true);
    try {
      final success = await _service.submitPromotion(_user!.id, videoUrl, title);
      if (success) {
        final promotions = await _service.getPromotions(_user!.id);
        _promotions = promotions;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Submit promotion error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
    _user = null;
    _transactions = [];
    _bundles = [];
    _promotions = [];
    _box.delete(_userKey);
    notifyListeners();
  }

  Future<bool> purchaseBundle(VideoBundle bundle) async {
    if (_user == null) return false;

    try {
      final success = await _service.purchaseBundle(_user!.id, bundle);
      if (success) {
        await refreshUser();
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Purchase bundle error: $e');
      return false;
    }
  }

  Future<bool> requestWithdrawal(double amount, String upiId) async {
    if (_user == null) return false;

    try {
      final success = await _service.requestWithdrawal(_user!.id, amount, upiId);
      if (success) {
        // Update user data immediately after successful withdrawal
        await refreshUser();
        
        // Also update transactions
        final transactions = await _service.getTransactionHistory(_user!.id);
        _transactions = transactions;
        
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Withdrawal request error: $e');
      return false;
    }
  }

  Future<List<Transaction>> getTransactionHistory() async {
    if (_user == null) return [];

    try {
      final transactions = await _service.getTransactionHistory(_user!.id);
      _transactions = transactions;
      notifyListeners();
      return transactions;
    } catch (e) {
      debugPrint('Get transaction history error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getWithdrawalHistory() async {
    if (_user == null) return [];

    try {
      return await _service.getWithdrawalHistory(_user!.id);
    } catch (e) {
      debugPrint('Get withdrawal history error: $e');
      return [];
    }
  }

  Future<VideoBundle?> getBundleWithVideos(String bundleId) async {
    try {
      return await _service.getBundleWithVideos(bundleId);
    } catch (e) {
      debugPrint('Get bundle videos error: $e');
      return null;
    }
  }

  Future<void> refreshUser() async {
    if (_user == null) return;

    try {
      final updatedUser = await _service.getUserById(_user!.id);
      if (updatedUser != null) {
        _user = updatedUser;
        
        // Also refresh related data
        final transactions = await _service.getTransactionHistory(_user!.id);
        _transactions = transactions;
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh user error: $e');
      // Keep existing user data on error
    }
  }

  Future<bool> recordVideoWatch(
    String bundleId,
    String videoId,
    int watchTimeSeconds,
  ) async {
    try {
      _setLoading(true);
      
      if (_user == null) return false;
      
      final bundle = _bundles.firstWhere(
        (b) => b.id == bundleId,
        orElse: () => throw Exception('Bundle not found: $bundleId'),
      );
      
      if (!bundle.videoIds.contains(videoId)) {
        throw Exception('Video not found in bundle: $videoId');
      }
      
      if (!_user!.purchasedBundles.contains(bundleId)) {
        throw Exception('Bundle not purchased: $bundleId');
      }
      
      final success = await _service.recordVideoWatch(
        _user!.id,
        bundleId,
        videoId,
        watchTimeSeconds,
      );
      
      if (success) {
        await refreshUser();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error recording video watch: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> canWatchMoreVideos(String bundleId) async {
    try {
      if (_user == null) return false;
      
      if (!_user!.purchasedBundles.contains(bundleId)) {
        return false;
      }
      
      final watchedToday = await _service.getWatchedVideosCountToday(
        _user!.id,
        bundleId,
      );
      
      return watchedToday < 2;
    } catch (e) {
      debugPrint('Error checking video watch limit: $e');
      return false;
    }
  }
} 