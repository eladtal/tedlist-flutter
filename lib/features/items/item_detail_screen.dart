import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/env.dart';
import '../../services/api_service.dart';
import '../../services/event_service.dart';
import '../../providers/item_provider.dart';
import '../../config/routes.dart';
import 'home_screen.dart';
import '../../widgets/web_scaffold.dart';

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

class ItemDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({
    super.key,
    required this.item,
  });

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool _showHomeOverlay = false;
  String _deletedItemTitle = '';

  @override
  Widget build(BuildContext context) {
    // If showing home overlay, display HomeScreen directly
    if (_showHomeOverlay) {
      return _buildHomeScreenOverlay();
    }

    // Show normal detail screen
    final imageUrl = (widget.item['images'] is List && widget.item['images'].isNotEmpty) 
      ? getProxyImageUrl(widget.item['images'][0]) 
      : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item['title'] ?? 'Item Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      body: WebScaffold(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image gallery
              if (imageUrl.isNotEmpty)
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
                
              // Item details
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and condition
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.item['title'] ?? 'No Title',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        if (widget.item['condition'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.item['condition'],
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Category
                    if (widget.item['category'] != null) ...[
                      Text(
                        'Category',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item['category'],
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Description
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item['description'] ?? 'No description provided',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Owner info if available
                    if (widget.item['owner'] != null && widget.item['owner'] is Map) ...[
                      Text(
                        'Owner',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              (widget.item['owner']['name'] as String?)?.isNotEmpty == true
                                  ? (widget.item['owner']['name'] as String).substring(0, 1).toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (widget.item['owner']['name'] as String?) ?? 'Unknown User',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Status
                    if (widget.item['status'] != null) ...[
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(widget.item['status']).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.item['status'],
                          style: TextStyle(
                            color: _getStatusColor(widget.item['status']),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New method to completely bypass navigation and directly show HomeScreen
  Widget _buildHomeScreenOverlay() {
    debugPrint('🏠🏠🏠 SHOWING HOME SCREEN OVERLAY - BYPASS NAVIGATION');
    
    // Show success snackbar after short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$_deletedItemTitle" successfully deleted'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    
    // Return HomeScreen directly - this completely bypasses navigation
    return const HomeScreen();
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text(
          'Are you sure you want to delete this item? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              // Close the dialog
              Navigator.of(context).pop();
              
              try {
                // Debug: Print the item data
                debugPrint('Item data: ${widget.item}');
                final itemId = widget.item['_id'] ?? widget.item['id'];
                final itemTitle = widget.item['title'] ?? 'Item';
                if (itemId == null) {
                  throw Exception('Item ID is missing');
                }
                debugPrint('Deleting item with ID: $itemId');

                // Show loading indicator
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deleting item...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }

                // Call the delete API through the provider
                await ref.read(itemsProvider.notifier).deleteItem(itemId.toString());
                
                // Fire global event for refreshing other screens
                eventService.fireEvent(
                  AppEvent.itemDeleted, 
                  {
                    'id': itemId, 
                    'title': itemTitle,
                    'showMessage': true,
                  }
                );
                
                // SKIP NAVIGATION ENTIRELY - Just change local state to show home screen overlay
                if (mounted) {
                  setState(() {
                    _showHomeOverlay = true;
                    _deletedItemTitle = itemTitle;
                  });
                }
                
              } catch (e) {
                debugPrint('Error deleting item: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting item: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('DELETE'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'traded':
        return Colors.blue;
      case 'removed':
      case 'deleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
} 