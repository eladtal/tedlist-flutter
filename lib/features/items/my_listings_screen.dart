import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../config/env.dart';
import 'item_detail_screen.dart';
import '../../providers/item_provider.dart';
import '../../widgets/web_scaffold.dart'; // Assuming WebScaffold is a general purpose scaffold
import '../../services/event_service.dart';
import 'dart:async';

// TODO: Move getProxyImageUrl to a shared utility file
String getProxyImageUrl(dynamic imageUrl) {
  if (imageUrl == null || imageUrl == '') return '';
  final apiBase = Env.apiUrl.replaceAll('/api', '');
  if (imageUrl is String && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
    return imageUrl; // Use as-is if already a full URL
  }
  String filename = imageUrl.toString().split('/').last;
  return '$apiBase/api/images/$filename';
}

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  String? _currentUserId; // Stores the email of the current user
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCurrentUserId();
      // Initial load is handled by provider if needed or can be triggered here
      // ref.read(itemsProvider.notifier).loadItems(); 
    });
     _eventSubscription = eventService.onEvent.listen((event) {
      if (event.event == AppEvent.itemDeleted || 
          event.event == AppEvent.itemAdded ||
          event.event == AppEvent.refreshNeeded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(itemsProvider.notifier).loadItems();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchCurrentUserId() async {
    try {
      final response = await ApiService().get('api/auth/validate');
      if (mounted) {
        setState(() {
          _currentUserId = response['email'] ?? response['user']?['email'];
          debugPrint('MyListingsScreen: Fetched Current User Email: $_currentUserId');
        });
      }
    } catch (e) {
      debugPrint('MyListingsScreen: Failed to fetch current user: $e');
      if (mounted) {
        // Optionally show an error to the user
      }
    }
  }

  Future<void> _refreshItems() async {
    await ref.read(itemsProvider.notifier).loadItems();
    await _fetchCurrentUserId(); // Re-fetch user ID in case of session changes
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
      ),
      body: WebScaffold( // Using WebScaffold for consistent layout
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error loading items: $error')),
          data: (items) {
            if (_currentUserId == null) {
              debugPrint('MyListingsScreen: _currentUserId is still null. Waiting for user data.');
              return const Center(child: Text('Verifying user...')); // Or a loading indicator
            }
            debugPrint('MyListingsScreen: Building list. Current User Email: $_currentUserId. Total items from provider: ${items.length}');

            final myItems = items.where((item) {
              final itemTitle = item['title'] ?? 'No Title';
              final ownerData = item['owner'];
              final ownerEmail = item['owner']?['email']?.toString();
              final bool isMyItem = ownerEmail != null && _currentUserId != null && ownerEmail.trim().toLowerCase() == _currentUserId!.trim().toLowerCase();
              
              debugPrint('MyListingsScreen ITEM CHECK:');
              debugPrint('  Item Title: $itemTitle');
              debugPrint('  Raw item[\'owner\']: $ownerData');
              debugPrint('  Extracted ownerEmail: $ownerEmail (Type: ${ownerEmail?.runtimeType})');
              debugPrint('  _currentUserId: $_currentUserId (Type: ${_currentUserId?.runtimeType})');
              debugPrint('  Comparison: "${ownerEmail?.trim().toLowerCase()}" == "${_currentUserId?.trim().toLowerCase()}" -> $isMyItem');
              
              return isMyItem;
            }).toList().cast<Map<String, dynamic>>();

            debugPrint('MyListingsScreen: Filtered \'myItems\' count: ${myItems.length}');

            if (myItems.isEmpty) {
              return const Center(
                child: Text('You have not uploaded any items yet.'),
              );
            }

            return RefreshIndicator(
              onRefresh: _refreshItems,
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: myItems.length,
                itemBuilder: (context, index) {
                  final item = myItems[index];
                  // TODO: Refactor _buildItemCard into a reusable widget
                  return _buildItemCard(context, item);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // TODO: Refactor _buildItemCard into a shared reusable widget
  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item) {
    final imageUrl = getProxyImageUrl(
      (item['images'] is List && item['images'].isNotEmpty) ? item['images'][0] : null
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell( // Use InkWell for tap effect
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(item: item),
            ),
          );
          // No need to manually refresh here if event system handles it
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              SizedBox(
                height: 150, // Fixed height for image consistency
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                  ),
                ),
              )
            else
              Container( // Placeholder for items with no image
                height: 150,
                width: double.infinity,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? 'No Title',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item['category'] != null)
                    Text(
                      item['category'],
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (item['condition'] != null)
                        Chip(
                          label: Text(item['condition'], style: Theme.of(context).textTheme.labelSmall),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                        ),
                      // Add price or other key info here if available
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
} 