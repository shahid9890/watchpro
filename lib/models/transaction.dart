import 'package:intl/intl.dart';

enum TransactionType {
  purchase,
  reward,
  withdrawal,
  referral,
}

class Transaction {
  final String id;
  final String userId;
  final double amount;
  final String description;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedDate => DateFormat('MMM dd, yyyy HH:mm').format(createdAt);

  get type => null;
} 