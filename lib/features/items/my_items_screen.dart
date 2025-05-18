import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/item_provider.dart';
import '../../widgets/web_scaffold.dart';
import 'item_detail_screen.dart';
import '../../config/env.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';

final currentUserIdProvider = FutureProvider<String?>((ref) async {
  final response = await ApiService().get('auth/validate');
  return response['_id'] ?? response['id'] ?? response['user']?['_id'];
});

String getProxyImageUrl(dynamic imageUrl) {
  if (imageUrl == null || imageUrl == '') return '';
  final apiBase = Env.apiUrl.replaceAll('/api', '');
  if (imageUrl is String && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
    return imageUrl;
  }
  String filename = imageUrl.toString().split('/').last;
  return '$apiBase/api/images/$filename';
}

class MyItemsScreen extends ConsumerWidget {
  const MyItemsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsProvider);
    final userIdAsync = ref.watch(currentUserIdProvider);
    final pastelTeal = const Color(0xFFB2F2BB);
    final pastelYellow = const Color(0xFFFFF3B0);
    final pastelGray = const Color(0xFFF6F8FA);
    final teddyBrown = const Color(0xFF3E3C3A);

    return Scaffold(
      body: WebScaffold(
        header: AppBar(
          title: const Text('My Items'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        content: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (items) {
            return userIdAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              data: (userId) {
                final myItems = items.where((item) => item['isMine'] == true || item['owner']?['_id'] == userId).toList();
                if (myItems.isEmpty) {
                  return const Center(child: Text('No items found.'));
                }
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.builder(
                    itemCount: myItems.length,
                    itemBuilder: (context, index) {
                      final item = myItems[index];
                      final imageUrl = (item['images'] is List && item['images'].isNotEmpty)
                          ? getProxyImageUrl(item['images'][0])
                          : '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                  child: AspectRatio(
                                    aspectRatio: 1.8,
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: teddyBrown,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: [
                                        if (item['condition'] != null)
                                          Chip(
                                            label: Text(item['condition']),
                                            backgroundColor: pastelGray,
                                            labelStyle: const TextStyle(fontSize: 13),
                                          ),
                                        if (item['category'] != null)
                                          Chip(
                                            label: Text(item['category']),
                                            backgroundColor: pastelTeal.withOpacity(0.2),
                                            labelStyle: const TextStyle(fontSize: 13),
                                          ),
                                        if (item['teddyBonus'] != null)
                                          Chip(
                                            avatar: const Icon(Icons.stars, color: Color(0xFFFFC107), size: 18),
                                            label: Text('+${item['teddyBonus']}'),
                                            backgroundColor: pastelYellow,
                                            labelStyle: const TextStyle(fontSize: 13),
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
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
} 