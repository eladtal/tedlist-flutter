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
import 'package:flutter/gestures.dart';

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

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  StreamSubscription? _eventSubscription;
  String? _currentUserId;

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
  }
  
  @override
  void dispose() {
    // Remove the observer
    WidgetsBinding.instance.removeObserver(this);
    // Cancel event subscription
    _eventSubscription?.cancel();
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
      debugPrint('Auth response: $response');
      if (mounted) {
        setState(() {
          _currentUserId = response['email'] ?? response['user']?['email'];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch current user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tedlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications screen
            },
          ),
        ],
      ),
      body: WebScaffold(
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(child: Text('No items found.'));
            }
            
            debugPrint('=== DEBUG INFO ===');
            debugPrint('Current user email: $_currentUserId');
            debugPrint('Total items: ${items.length}');
            
            // Print all items and their owners for debugging
            for (var item in items) {
              debugPrint('Item: ${item['title']} - Owner: ${item['owner']?['email']}');
            }
            
            // Filter items: my items are from current user, featured items are from others
            final List<Map<String, dynamic>> myItems;
            final List<Map<String, dynamic>> featuredItems;

            if (_currentUserId == null) {
              // If user ID is not yet loaded, both lists should be empty to avoid miscategorization
              myItems = [];
              featuredItems = [];
              debugPrint('Current user ID is null. MyItems and FeaturedItems are empty.');
            } else {
              debugPrint('Current user ID is $_currentUserId. Filtering items...');
              myItems = items.where((item) {
                final ownerEmail = item['owner']?['email']?.toString();
                final isMyItem = ownerEmail != null && ownerEmail == _currentUserId.toString();
                // Keep minimal debug for clarity
                // debugPrint('MY ITEMS CHECK - Item: ${item['title']}, OwnerEmail: $ownerEmail, IsMyItem: $isMyItem');
                return isMyItem;
              }).cast<Map<String, dynamic>>().toList();
                  
              featuredItems = items.where((item) {
                final ownerEmail = item['owner']?['email']?.toString();
                final isFeaturedItem = ownerEmail != null && ownerEmail != _currentUserId.toString();
                // Keep minimal debug for clarity
                // debugPrint('FEATURED ITEMS CHECK - Item: ${item['title']}, OwnerEmail: $ownerEmail, IsFeaturedItem: $isFeaturedItem');
                return isFeaturedItem;
              }).cast<Map<String, dynamic>>().toList();
            }
            
            debugPrint('=== FILTERING RESULTS ===');
            debugPrint('My items count: ${myItems.length}');
            debugPrint('Featured items count: ${featuredItems.length}');
            if (myItems.isNotEmpty) {
              debugPrint('First my item: ${myItems[0]['title']} - Owner: ${myItems[0]['owner']?['email']}');
            }
            if (featuredItems.isNotEmpty) {
              debugPrint('First featured item: ${featuredItems[0]['title']} - Owner: ${featuredItems[0]['owner']?['email']}');
            }
            debugPrint('=== END DEBUG INFO ===');

            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(itemsProvider.notifier).loadItems();
                await _fetchCurrentUserId();
              },
              child: CustomScrollView(
                slivers: [
                  // Featured Items Section (from other users)
                  if (featuredItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Featured Items',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 220,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: featuredItems.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  final item = featuredItems[index];
                                  return SizedBox(
                                    width: 180,
                                    child: _buildItemCard(item),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Categories
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Categories',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 100,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _buildCategoryItem(Icons.devices, 'Electronics'),
                                _buildCategoryItem(Icons.sports, 'Sports'),
                                _buildCategoryItem(Icons.book, 'Books'),
                                _buildCategoryItem(Icons.checkroom, 'Clothing'),
                                _buildCategoryItem(Icons.videogame_asset, 'Games'),
                                _buildCategoryItem(Icons.palette, 'Art'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // My Items Section
                  if (myItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Items',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 220,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: myItems.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  final item = myItems[index];
                                  return SizedBox(
                                    width: 180,
                                    child: _buildItemCard(item),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String name) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(name),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final imageUrl = getProxyImageUrl(
      (item['images'] is List && item['images'].isNotEmpty) ? item['images'][0] : null
    );
    // Debug: Print the image URLs for inspection
    debugPrint('Item: ${item['title'] ?? item['id']}');
    debugPrint('  images: ${item['images']}');
    debugPrint('  imageUrl used: ${imageUrl}');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          debugPrint('Item card tapped: ${item['title']}');
          // Navigate to detail and WAIT for result
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(item: item),
            ),
          );
          
          debugPrint('Navigation result from detail screen: $result');
          
          // Refresh regardless of result - this ensures we have current data
          debugPrint('Refreshing items list after returning from detail screen');
          await _refreshItems();
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
      ),
    );
  }

  Future<void> _refreshItems() async {
    debugPrint('Refreshing items list using provider...');
    await ref.read(itemsProvider.notifier).loadItems();
  }
} 