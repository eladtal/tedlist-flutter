import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Mock item data - will be replaced with API calls
final List<Map<String, dynamic>> _mockItems = [
  {
    'id': '1',
    'title': 'Vintage Camera',
    'image': 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32',
    'condition': 'Good',
    'category': 'Electronics',
  },
  {
    'id': '2',
    'title': 'Mountain Bike',
    'image': 'https://images.unsplash.com/photo-1485965120184-e220f721d03e',
    'condition': 'Excellent',
    'category': 'Sports',
  },
  {
    'id': '3',
    'title': 'Board Games Collection',
    'image': 'https://images.unsplash.com/photo-1610890716171-6b1bb98ffd09',
    'condition': 'Like New',
    'category': 'Games',
  },
  {
    'id': '4',
    'title': 'Designer Jacket',
    'image': 'https://images.unsplash.com/photo-1551028719-00167b16eac5',
    'condition': 'Good',
    'category': 'Clothing',
  },
  {
    'id': '5',
    'title': 'Coffee Table Books',
    'image': 'https://images.unsplash.com/photo-1544947950-fa07a98d237f',
    'condition': 'Fair',
    'category': 'Books',
  },
  {
    'id': '6',
    'title': 'Wireless Headphones',
    'image': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e',
    'condition': 'Excellent',
    'category': 'Electronics',
  },
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      body: _buildHomePage(),
    );
  }

  Widget _buildHomePage() {
    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Implement refresh logic
        await Future.delayed(const Duration(seconds: 1));
      },
      child: CustomScrollView(
        slivers: [
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
          
          // Featured Items
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Featured Items',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          
          // Items Grid
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
                  final item = _mockItems[index];
                  return _buildItemCard(item);
                },
                childCount: _mockItems.length,
              ),
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to item detail screen
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Image
            Expanded(
              child: CachedNetworkImage(
                imageUrl: item['image'],
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
                    item['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
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
} 