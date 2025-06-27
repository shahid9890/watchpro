import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'watch_earn_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'promotions_screen.dart';
import 'bundles_screen.dart';
import 'withdrawal_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    BundlesScreen(),
    WatchEarnScreen(),
    WalletScreen(),
    PromotionsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().user;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch & Earn Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WithdrawalScreen(),
                ),
              );
            },
            tooltip: 'Withdraw Money',
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                '₹${user?.balance.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Bundles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle),
            label: 'Watch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign),
            label: 'Promote',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _BundlesTab extends StatelessWidget {
  const _BundlesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.user;
    final bundles = provider.bundles;

    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (bundles.isEmpty) {
      return const Center(
        child: Text('No bundles available at the moment'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bundles.length,
      itemBuilder: (context, index) {
        final bundle = bundles[index];
        final isPurchased = user?.purchasedBundles.contains(bundle.id) ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bundle.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('${bundle.videoCount} videos'),
                Text('Price: ₹${bundle.price}'),
                Text('Total Earnings: ₹${bundle.totalEarnings}'),
                Text('Reward per video: ₹${bundle.rewardPerVideo}'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isPurchased
                        ? null
                        : () async {
                            final success = await provider.purchaseBundle(bundle);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Bundle purchased successfully!'
                                        : 'Failed to purchase bundle. Please check your balance.',
                                  ),
                                  backgroundColor:
                                      success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                    child: Text(
                      isPurchased ? 'Purchased' : 'Buy Now',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 