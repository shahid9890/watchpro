import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/app_provider.dart';
import '../models/video_bundle.dart';
import 'dart:async';

class WatchEarnScreen extends StatelessWidget {
  const WatchEarnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.user;

    if (user == null) {
      return const Center(
        child: Text('Please register to continue'),
      );
    }

    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (user.purchasedBundles.isEmpty) {
      return const Center(
        child: Text('Purchase a bundle to start watching videos'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: user.purchasedBundles.length,
      itemBuilder: (context, index) {
        final bundleId = user.purchasedBundles[index];
        return FutureBuilder<VideoBundle?>(
          future: provider.getBundleWithVideos(bundleId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError || snapshot.data == null) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: ${snapshot.error ?? 'Bundle not found'}'),
                ),
              );
            }

            final bundle = snapshot.data!;

            return FutureBuilder<bool>(
              future: provider.canWatchMoreVideos(bundleId),
              builder: (context, canWatchSnapshot) {
                final canWatch = canWatchSnapshot.data ?? false;

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
                        Text(
                          'Videos in bundle: ${bundle.videoCount}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Reward per video: ₹${bundle.rewardPerVideo}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!canWatch)
                          const Text(
                            'You have reached the daily limit (2 videos) for this bundle',
                            style: TextStyle(color: Colors.red),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: bundle.videoIds.map((videoId) {
                              return ElevatedButton.icon(
                                onPressed: () => _showVideoDialog(
                                  context,
                                  videoId,
                                  bundle,
                                ),
                                icon: const Icon(Icons.play_circle_outline),
                                label: const Text('Watch Video'),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showVideoDialog(
    BuildContext context,
    String videoId,
    VideoBundle bundle,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _VideoDialog(
        videoId: videoId,
        bundle: bundle,
      ),
    );
  }
}

class _VideoDialog extends StatefulWidget {
  final String videoId;
  final VideoBundle bundle;

  const _VideoDialog({
    required this.videoId,
    required this.bundle,
  });

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late WebViewController _controller;
  bool _isWatching = false;
  bool _hasEarned = false;
  DateTime? _startTime;
  int _watchTimeSeconds = 0;
  Timer? _watchTimer;

  @override
  void initState() {
    super.initState();
    _setupWebView();
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    super.dispose();
  }

  void _setupWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString('''
        <!DOCTYPE html>
        <html>
          <body style="margin:0">
            <div id="player"></div>
            <script src="https://www.youtube.com/iframe_api"></script>
            <script>
              var player;
              function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                  height: '100%',
                  width: '100%',
                  videoId: '${widget.videoId}',
                  events: {
                    'onStateChange': onPlayerStateChange
                  }
                });
              }
              function onPlayerStateChange(event) {
                if (event.data == YT.PlayerState.PLAYING) {
                  window.flutter_inappwebview.callHandler('onVideoStart');
                } else if (event.data == YT.PlayerState.PAUSED || event.data == YT.PlayerState.ENDED) {
                  window.flutter_inappwebview.callHandler('onVideoStop');
                }
              }
            </script>
          </body>
        </html>
      ''')
      ..addJavaScriptChannel(
        'flutter_inappwebview',
        onMessageReceived: (message) {
          if (message.message == 'onVideoStart') {
            setState(() {
              _isWatching = true;
              _startTime = DateTime.now();
            });
            _startWatchTimer();
          } else if (message.message == 'onVideoStop') {
            setState(() {
              _isWatching = false;
            });
            _watchTimer?.cancel();
            _checkProgress();
          }
        },
      );
  }

  void _startWatchTimer() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isWatching && _startTime != null) {
        setState(() {
          _watchTimeSeconds = DateTime.now().difference(_startTime!).inSeconds;
        });
        _checkProgress();
      }
    });
  }

  void _checkProgress() {
    if (_hasEarned || _startTime == null) return;

    if (_watchTimeSeconds >= 90) { // 90 seconds minimum watch time
      setState(() => _hasEarned = true);
      context.read<AppProvider>().recordVideoWatch(
            widget.bundle.id,
            widget.videoId,
            _watchTimeSeconds,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: WebViewWidget(controller: _controller),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_hasEarned)
                  const Text(
                    'Congratulations! You earned your reward.',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (_isWatching)
                  Text(
                    'Keep watching to earn your reward... ($_watchTimeSeconds seconds)',
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 