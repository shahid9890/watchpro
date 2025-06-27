import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({Key? key}) : super(key: key);

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _upiIdController = TextEditingController();
  List<Map<String, dynamic>> _withdrawalHistory = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWithdrawalHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _loadWithdrawalHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await context.read<AppProvider>().getWithdrawalHistory();
      setState(() => _withdrawalHistory = history);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);
    final upiId = _upiIdController.text;

    setState(() => _isLoading = true);
    try {
      final success = await context.read<AppProvider>().requestWithdrawal(amount, upiId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit withdrawal request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal request submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _amountController.clear();
          _upiIdController.clear();
          await _loadWithdrawalHistory();
          Navigator.pop(context); // Navigate back to previous screen
        
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return '🟢';
      case 'pending':
        return '🟡';
      case 'rejected':
        return '🔴';
      default:
        return '⚪';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Withdrawal',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Consumer<AppProvider>(
                        builder: (context, provider, child) {
                          final balance = provider.user?.balance ?? 0.0;
                          return Text(
                            'Available Balance: ₹${balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null) {
                            return 'Please enter a valid amount';
                          }
                          if (amount < 100) {
                            return 'Minimum withdrawal amount is ₹100';
                          }
                          final balance = context.read<AppProvider>().user?.balance ?? 0.0;
                          if (amount > balance) {
                            return 'Amount exceeds available balance';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _upiIdController,
                        decoration: const InputDecoration(
                          labelText: 'UPI ID',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your UPI ID';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid UPI ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleWithdrawal,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit Request'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Withdrawal History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_isLoading && _withdrawalHistory.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_withdrawalHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No withdrawal history'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _withdrawalHistory.length,
                itemBuilder: (context, index) {
                  final withdrawal = _withdrawalHistory[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('₹${withdrawal['amount'].toStringAsFixed(2)}'),
                      subtitle: Text(
                        'UPI: ${withdrawal['upi_id']}\n'
                        'Requested: ${DateTime.parse(withdrawal['requested_at']).toLocal().toString().split('.')[0]}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_getStatusColor(withdrawal['status'])),
                          const SizedBox(width: 8),
                          Text(
                            withdrawal['status'].toUpperCase(),
                            style: TextStyle(
                              color: withdrawal['status'].toLowerCase() == 'completed'
                                  ? Colors.green
                                  : withdrawal['status'].toLowerCase() == 'rejected'
                                      ? Colors.red
                                      : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
} 