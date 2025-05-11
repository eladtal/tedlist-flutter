import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

// Provider for items list
final itemsProvider = StateNotifierProvider<ItemsNotifier, AsyncValue<List<dynamic>>>((ref) {
  return ItemsNotifier();
});

class ItemsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  ItemsNotifier() : super(const AsyncValue.loading()) {
    // Initialize with loading state, but don't call loadItems here
    // as it could cause issues during provider initialization
  }

  Future<void> loadItems() async {
    if (mounted) {
      try {
        debugPrint('ItemsNotifier: Loading items...');
        // Set loading state
        state = const AsyncValue.loading();
        
        // Fetch items
        final items = await ApiService().getItems();
        
        // Only update state if the notifier is still mounted
        if (mounted) {
          debugPrint('ItemsNotifier: Items loaded successfully');
          state = AsyncValue.data(items);
        }
      } catch (e, stack) {
        debugPrint('ItemsNotifier: Error loading items: $e');
        if (mounted) {
          state = AsyncValue.error(e, stack);
        }
      }
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      debugPrint('ItemsNotifier: Deleting item $itemId');
      await ApiService().deleteItem(itemId);
      
      // We need to reload the items after deletion to update the UI
      debugPrint('ItemsNotifier: Item deleted, reloading items...');
      await loadItems();
    } catch (e) {
      debugPrint('ItemsNotifier: Error deleting item: $e');
      // Error is already handled by the API service
      rethrow;
    }
  }
} 