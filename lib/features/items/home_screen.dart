import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../config/env.dart';
import 'item_detail_screen.dart';
import '../../services/event_service.dart';
import 'dart:async';
import '../../providers/item_provider.dart';
import '../../widgets/web_scaffold.dart';
import '../../widgets/swipeable_item_card.dart';
import 'package:flutter/gestures.dart';
import '../trading/trading_screen.dart';
import '../items/my_items_screen.dart';
import 'dart:math' as math;
import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

String getProxyImageUrl(dynamic imageUrl) {
  if (imageUrl == null || imageUrl == '') return '';
  final apiBase = Env.apiUrl.replaceAll('/api', '');
  if (imageUrl is String && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
    return imageUrl; // Use as-is if already a full URL
  }
  // If it's a filename or relative path
  String filename = imageUrl.toString().split('/').last;
  return '$apiBase/api/images/$filename';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  StreamSubscription? _eventSubscription;
  String? _currentUserId;
  late AnimationController _tradeBtnController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(itemsProvider.notifier).loadItems();
      _fetchCurrentUserId();
    });
    _eventSubscription = eventService.onEvent.listen((event) {
      debugPrint('🎯 Received event in HomeScreen: ${event.event} with data: ${event.data}');
      
      // Refresh on important events - but scheduled after frame
      if (event.event == AppEvent.itemDeleted || 
          event.event == AppEvent.itemAdded || 
          event.event == AppEvent.refreshNeeded) {
        debugPrint('⚡ Refreshing items due to event: ${event.event}');
        // Use provider to refresh after current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(itemsProvider.notifier).loadItems();
        });
        
        // Show success message if requested
        if (event.data is Map && 
            event.data['showMessage'] == true && 
            event.data['title'] != null) {
          // Show success message for deletion
          if (event.event == AppEvent.itemDeleted && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${event.data['title']}" successfully deleted'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            });
          }
        }
      }
    });
    _tradeBtnController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _tradeBtnController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    // Remove the observer
    WidgetsBinding.instance.removeObserver(this);
    // Cancel event subscription
    _eventSubscription?.cancel();
    _tradeBtnController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Do NOT refresh items here - it will cause errors
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh items when app comes to the foreground - but schedule it safely
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshItems();
        }
      });
    }
  }

  Future<void> _fetchCurrentUserId() async {
    try {
      final response = await ApiService().get('api/auth/validate');
      if (mounted) {
        setState(() {
          _currentUserId = response['_id'] ?? response['id'] ?? response['user']?['_id'];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch current user id: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      body: Stack(
        children: [
          WebScaffold(
            header: AppBar(
              title: const Text('Tedlist'),
              backgroundColor: Theme.of(context).colorScheme.background,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    // TODO: Navigate to notifications screen
                  },
                ),
              ],
            ),
            content: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No items found.'));
                }
                final featuredItems = _currentUserId == null
                    ? items
                    : items.where((item) => item['owner']?['_id'] != _currentUserId).toList();
                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(itemsProvider.notifier).loadItems();
                    await _fetchCurrentUserId();
                  },
                  child: CustomScrollView(
                    slivers: [
                      // Featured Items
                      if (false) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Text(
                              'Featured Items',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                        // Items Grid (featured)
                        SliverPadding(
                          padding: const EdgeInsets.all(16.0),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = featuredItems[index];
                                return _buildItemCard(item);
                              },
                              childCount: featuredItems.length,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          // Floating animated Trade button
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: Center(
                child: AnimatedBuilder(
                  animation: _tradeBtnController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnim.value,
                      child: GestureDetector(
                        onTap: () {
                          // Navigate to Choose Item to Trade page
                          final items = ref.read(itemsProvider).maybeWhen(
                            data: (items) => items,
                            orElse: () => [],
                          );
                          final myItems = items.map((item) => Map<String, dynamic>.from(item)).toList();
                          _showItemSelectionDialog(context, myItems);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFF3B0).withOpacity(0.7),
                                blurRadius: 48,
                                spreadRadius: 16,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/trade_button.png',
                              width: 240,
                              height: 240,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final imageUrl = (item['images'] is List && item['images'].isNotEmpty) 
      ? getProxyImageUrl(item['images'][0]) 
      : '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailScreen(item: item),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Image
            Expanded(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                ),
              ),
            ),
            
            // Item Details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item['condition'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item['condition'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      if (item['category'] != null)
                        Expanded(
                          child: Text(
                            item['category'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemSelectionDialog(BuildContext context, List<Map<String, dynamic>> myItems) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose an Item to Trade'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: myItems.length,
            itemBuilder: (context, index) {
              final item = myItems[index];
              final imageUrl = (item['images'] is List && item['images'].isNotEmpty)
                  ? getProxyImageUrl(item['images'][0])
                  : '';
              
              return ListTile(
                leading: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            width: 48,
                            height: 48,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            width: 48,
                            height: 48,
                            child: const Icon(Icons.error),
                          ),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image),
                      ),
                title: Text(item['title'] ?? ''),
                subtitle: item['condition'] != null
                    ? Text(item['condition'])
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TradingScreen(
                        myItem: item,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshItems() async {
    debugPrint('Refreshing items list using provider...');
    await ref.read(itemsProvider.notifier).loadItems();
  }
} 