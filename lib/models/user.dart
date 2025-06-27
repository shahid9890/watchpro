class User {
  final String id;
  final String name;
  final String email;
  final String referralCode;
  final String? referredBy;
  double balance;
  List<String> purchasedBundles;
  final String? referrerId;
  double referralEarnings;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.referralCode,
    this.referredBy,
    required this.balance,
    this.purchasedBundles = const [],
    this.referrerId,
    this.referralEarnings = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'referral_code': referralCode,
      'referred_by': referredBy,
      'wallet_balance': balance,
      'referrer_id': referrerId,
      'referral_earnings': referralEarnings,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      referralCode: json['referral_code'] as String,
      referredBy: json['referred_by'] as String?,
      balance: (json['wallet_balance'] as num).toDouble(),
      referrerId: json['referrer_id'] as String?,
      referralEarnings: (json['referral_earnings'] as num?)?.toDouble() ?? 0,
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? referralCode,
    String? referredBy,
    double? balance,
    List<String>? purchasedBundles,
    String? referrerId,
    double? referralEarnings,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      balance: balance ?? this.balance,
      purchasedBundles: purchasedBundles ?? this.purchasedBundles,
      referrerId: referrerId ?? this.referrerId,
      referralEarnings: referralEarnings ?? this.referralEarnings,
    );
  }
} 