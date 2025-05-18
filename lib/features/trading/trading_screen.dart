import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../config/env.dart';
import '../../widgets/web_scaffold.dart';

String getProxyImageUrl(dynamic imageUrl) {
  if (imageUrl == null || imageUrl == '') return '';
  final apiBase = Env.apiUrl.replaceAll('/api', '');
  if (imageUrl is String && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
    return imageUrl;
  }
  String filename = imageUrl.toString().split('/').last;
  return '$apiBase/api/images/$filename';
}

class TradingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> myItem;

  const TradingScreen({
    Key? key,
    required this.myItem,
  }) : super(key: key);

  @override
  ConsumerState<TradingScreen> createState() => _TradingScreenState();
}

class _TradingScreenState extends ConsumerState<TradingScreen> {
  List<Map<String, dynamic>> _potentialItems = [];
  int _currentIndex = 0;
  double _dragDx = 0;
  bool _isDragging = false;
  double _cardWidth = 0;

  @override
  void initState() {
    super.initState();
    _startTradingSession();
  }

  Future<void> _startTradingSession() async {
    try {
      // Start a trading session with our current item
      await ApiService().post('trading/start', {
        'itemId': widget.myItem['_id'],
      });
      
      // After successfully starting the session, load potential trades
      _loadPotentialItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing trading: $e')),
        );
      }
    }
  }

  Future<void> _loadPotentialItems() async {
    try {
      // First, get the current user's ID from the API
      final userResponse = await ApiService().get('auth/validate');
      // The user ID is nested inside the 'user' object
      final String currentUserId = userResponse['user']?['_id']?.toString() ?? '';
      
      if (currentUserId.isEmpty) {
        throw Exception('Could not determine current user ID');
      }
      
      print('Current user ID: $currentUserId');
      
      // Get items FROM OTHER USERS that we can trade with
      // We use the trading/items endpoint to find potential trade matches
      print('Calling trading/items endpoint to find potential trades...');
      final response = await ApiService().get('trading/items');
      print('Got response from trading/items: $response');
      
      if (mounted) {
        List<Map<String, dynamic>> potentialTrades = [];
        
        // Handle the response format
        if (response is Map && response['items'] != null) {
          print('Response contains items array: ${response['items']}');
          potentialTrades = List<Map<String, dynamic>>.from(response['items']);
        } else if (response is List) {
          print('Response is a direct list: $response');
          potentialTrades = List<Map<String, dynamic>>.from(response);
        } else {
          print('WARNING: Unexpected response format: ${response.runtimeType}');
        }
        
        // Filter out items without images to prevent UI issues
        potentialTrades = potentialTrades.where((item) => 
          item['images'] != null && 
          item['images'] is List && 
          item['images'].isNotEmpty
        ).toList();
        
        print('Found ${potentialTrades.length} potential trades from other users');
        
        setState(() {
          _potentialItems = potentialTrades;
          _currentIndex = 0; // Reset the index when loading new items
        });
        
        if (_potentialItems.isEmpty) {
          print('No items available for trading from other users');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No matching items found from other users. Try again later!')),
            );
          }
        } else {
          print('Showing ${_potentialItems.length} items from other users in trading screen');
        }
      }
    } catch (e) {
      print('Error loading potential trades: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading potential trades: $e')),
        );
      }
    }
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragDx += details.delta.dx;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_dragDx.abs() > _cardWidth * 0.3 || velocity.abs() > 800) {
      if (_dragDx > 0) {
        _acceptItem();
      } else {
        _rejectItem();
      }
    } else {
      setState(() {
        _dragDx = 0;
      });
    }
  }

  Future<void> _acceptItem() async {
    if (_currentIndex >= _potentialItems.length) return;
    final item = _potentialItems[_currentIndex];
    try {
      // Just send the itemId and direction - the session is already initialized
      await ApiService().post('trading/swipe', {
        'itemId': item['_id'],
        'direction': 'right',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trade offer sent for ${item['title']}!'),
            backgroundColor: const Color(0xFFB2F2BB),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending trade offer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() {
      _dragDx = 0;
      _currentIndex++;
    });
  }

  void _rejectItem() {
    if (_currentIndex >= _potentialItems.length) return;
    final item = _potentialItems[_currentIndex];
    ApiService().post('trading/swipe', {
      'itemId': item['_id'],
      'direction': 'left',
    });
    setState(() {
      _dragDx = 0;
      _currentIndex++;
    });
  }

  void _showDetailsModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final imageUrl = (item['images'] is List && item['images'].isNotEmpty)
            ? getProxyImageUrl(item['images'][0])
            : '';
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              Text(item['title'] ?? '', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (item['description'] != null && item['description'].toString().trim().isNotEmpty)
                Text(item['description'], style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 12),
              if (item['condition'] != null)
                Row(
                  children: [
                    const Text('Condition: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Chip(
                      label: Text(item['condition']),
                      backgroundColor: const Color(0xFFF6F8FA),
                    ),
                  ],
                ),
              if (item['owner'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Color(0xFF4A6FA5)),
                      const SizedBox(width: 4),
                      Text(item['owner']['name'] ?? '', style: const TextStyle(color: Color(0xFF4A6FA5))),
                    ],
                  ),
                ),
              if (item['teddyBonus'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3B0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.stars, color: Color(0xFFFFC107), size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '+${item['teddyBonus']}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pastelTeal = const Color(0xFF7DE2D1);
    final pastelYellow = const Color(0xFFFFF3B0);
    final pastelBlue = const Color(0xFF7DE2D1);
    final pastelGray = const Color(0xFFF6F8FA);
    final teddyRed = const Color(0xFFFF6B6B);
    final teddyBrown = const Color(0xFF3E3C3A);

    return Scaffold(
      backgroundColor: const Color(0xFF7DE2D1),
      body: WebScaffold(
        header: AppBar(
          title: const Text(
            'Swipe to Trade', 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: Colors.white,
              fontSize: 28,
            )
          ),
          backgroundColor: const Color(0xFF7DE2D1),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                try {
                  await ApiService().logout();
                  if (!mounted) return;
                  context.go('/login');
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                }
              },
              tooltip: 'Logout',
            ),
          ],
        ),
        content: LayoutBuilder(
          builder: (context, constraints) {
            // Set card width to 75% of screen width
            _cardWidth = constraints.maxWidth * 0.75;
            // Calculate maximum allowed card height (60% of available height)
            final maxCardHeight = constraints.maxHeight * 0.6;
            if (_potentialItems.isEmpty || _currentIndex >= _potentialItems.length) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, color: Colors.white, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'No matching items found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No one has items matching your preferences right now',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: teddyBrown,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }
            final item = _potentialItems[_currentIndex];
            final imageUrl = (item['images'] is List && item['images'].isNotEmpty)
                ? getProxyImageUrl(item['images'][0])
                : '';
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text('Trading:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.myItem['title'],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Card stack hint (next card)
                        if (_currentIndex + 1 < _potentialItems.length)
                          Transform.scale(
                            scale: 0.96,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: _TradingCard(
                                item: _potentialItems[_currentIndex + 1],
                                imageUrl: (_potentialItems[_currentIndex + 1]['images'] is List && _potentialItems[_currentIndex + 1]['images'].isNotEmpty)
                                    ? getProxyImageUrl(_potentialItems[_currentIndex + 1]['images'][0])
                                    : '',
                                pastelTeal: pastelTeal,
                                pastelGray: pastelGray,
                                pastelYellow: pastelYellow,
                                teddyBrown: teddyBrown,
                                teddyRed: teddyRed,
                                isBehind: true,
                                onLike: null,
                                onDislike: null,
                                onInfo: null,
                              ),
                            ),
                          ),
                        // Main card
                        GestureDetector(
                          onHorizontalDragStart: _onDragStart,
                          onHorizontalDragUpdate: _onDragUpdate,
                          onHorizontalDragEnd: _onDragEnd,
                          child: Transform.translate(
                            offset: Offset(_dragDx, 0),
                            child: Stack(
                              children: [
                                SizedBox(
                                  width: _cardWidth,
                                  height: maxCardHeight,
                                  child: _TradingCard(
                                    item: item,
                                    imageUrl: imageUrl,
                                    pastelTeal: pastelTeal,
                                    pastelGray: pastelGray,
                                    pastelYellow: pastelYellow,
                                    teddyBrown: teddyBrown,
                                    teddyRed: teddyRed,
                                    isBehind: false,
                                    onLike: _acceptItem,
                                    onDislike: _rejectItem,
                                    onInfo: () => _showDetailsModal(item),
                                  ),
                                ),
                                // Swipe overlay
                                if (_isDragging && _dragDx.abs() > 10)
                                  Positioned.fill(
                                    child: AnimatedOpacity(
                                      opacity: 1.0,
                                      duration: const Duration(milliseconds: 100),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _dragDx > 0
                                              ? pastelTeal.withOpacity(0.18)
                                              : teddyRed.withOpacity(0.13),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Align(
                                          alignment: _dragDx > 0
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                            child: Icon(
                                              _dragDx > 0 ? Icons.favorite : Icons.close,
                                              color: _dragDx > 0 ? pastelTeal : teddyRed,
                                              size: 48,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Bottom action buttons like the image
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, top: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // X button (Dislike)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B6B),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          onPressed: _rejectItem,
                        ),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Info button (in the middle)
                      Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF3B0),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.info_outline, 
                            color: Color(0xFF3E3C3A), 
                            size: 32
                          ),
                          onPressed: () => _showDetailsModal(item),
                        ),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Heart button (Like)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7DE2D1).withOpacity(0.8),
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.white, size: 30),
                          onPressed: _acceptItem,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TradingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String imageUrl;
  final Color pastelTeal;
  final Color pastelGray;
  final Color pastelYellow;
  final Color teddyBrown;
  final Color teddyRed;
  final bool isBehind;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onInfo;

  const _TradingCard({
    required this.item,
    required this.imageUrl,
    required this.pastelTeal,
    required this.pastelGray,
    required this.pastelYellow,
    required this.teddyBrown,
    required this.teddyRed,
    required this.isBehind,
    this.onLike,
    this.onDislike,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    // Polaroid-style card design
    return Transform.rotate(
      angle: isBehind ? 0.0 : 0.05,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // More square aspect ratio like a polaroid
        child: AspectRatio(
          aspectRatio: 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Padding at the top for polaroid-style
              const SizedBox(height: 12),
              
              // Image in a square with rounded corners and padding on sides
              Expanded(
                flex: 65,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFB2F2BB).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                          ),
                    ),
                  ),
                ),
              ),
              
              // Item details
              Expanded(
                flex: 35,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Item title - larger and left-aligned
                      Text(
                        item['title'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: teddyBrown,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Tags row (category and condition)
                      Row(
                        children: [
                          // Category tag
                          if (item['category'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB2F2BB).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                item['category'] ?? 'Other',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            
                          const SizedBox(width: 8),
                          
                          // Condition tag
                          if (item['condition'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3B0).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                item['condition'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Color background;
  final Color border;
  final bool shadow;
  final String? label;
  final double size;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.background,
    required this.border,
    this.shadow = false,
    this.label,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: shadow ? 6 : 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
          child: label == null
              ? Icon(icon, color: color, size: size * 0.5)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: size * 0.4),
                      const SizedBox(height: 2),
                      Text(label!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
} 