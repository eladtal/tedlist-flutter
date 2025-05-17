import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    _loadPotentialItems();
  }

  Future<void> _loadPotentialItems() async {
    try {
      final response = await ApiService().get('items/potential-trades/${widget.myItem['_id']}');
      if (mounted) {
        setState(() {
          _potentialItems = List<Map<String, dynamic>>.from(response['items'] ?? []);
        });
      }
    } catch (e) {
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
      await ApiService().post('api/trading/swipe', {
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
    ApiService().post('api/trading/swipe', {
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
              const SizedBox(height: 8),
              if (item['description'] != null)
                Text(item['description'], style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 8),
              if (item['condition'] != null)
                Chip(
                  label: Text(item['condition']),
                  backgroundColor: const Color(0xFFF6F8FA),
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
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pastelTeal = const Color(0xFFB2F2BB);
    final pastelYellow = const Color(0xFFFFF3B0);
    final pastelBlue = const Color(0xFF7DE2D1);
    final pastelGray = const Color(0xFFF6F8FA);
    final teddyRed = const Color(0xFFEF5350);
    final teddyBrown = const Color(0xFF3E3C3A);

    return Scaffold(
      body: WebScaffold(
        header: AppBar(
          title: const Text('Find Trades'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        content: LayoutBuilder(
          builder: (context, constraints) {
            _cardWidth = constraints.maxWidth * 0.92;
            if (_potentialItems.isEmpty || _currentIndex >= _potentialItems.length) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.celebration, color: Color(0xFFB2F2BB), size: 64),
                    const SizedBox(height: 16),
                    const Text('No more items to trade with!', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pastelTeal,
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
                            child: _TradingCard(
                              item: _potentialItems[_currentIndex + 1],
                              imageUrl: ( _potentialItems[_currentIndex + 1]['images'] is List && _potentialItems[_currentIndex + 1]['images'].isNotEmpty)
                                  ? getProxyImageUrl(_potentialItems[_currentIndex + 1]['images'][0])
                                  : '',
                              pastelTeal: pastelTeal,
                              pastelGray: pastelGray,
                              pastelYellow: pastelYellow,
                              teddyBrown: teddyBrown,
                              isBehind: true,
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
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  curve: Curves.easeOut,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: pastelTeal.withOpacity(0.18),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  width: _cardWidth,
                                  child: _TradingCard(
                                    item: item,
                                    imageUrl: imageUrl,
                                    pastelTeal: pastelTeal,
                                    pastelGray: pastelGray,
                                    pastelYellow: pastelYellow,
                                    teddyBrown: teddyBrown,
                                    isBehind: false,
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
                                          borderRadius: BorderRadius.circular(28),
                                        ),
                                        child: Align(
                                          alignment: _dragDx > 0
                                              ? Alignment.centerLeft
                                              : Alignment.centerRight,
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionButton(
                        icon: Icons.close,
                        color: teddyRed,
                        onTap: _rejectItem,
                        background: Colors.white,
                        border: pastelGray,
                      ),
                      _ActionButton(
                        icon: Icons.info_outline,
                        color: pastelBlue,
                        onTap: () => _showDetailsModal(item),
                        background: Colors.white,
                        border: pastelGray,
                      ),
                      _ActionButton(
                        icon: Icons.favorite,
                        color: pastelTeal,
                        onTap: _acceptItem,
                        background: Colors.white,
                        border: pastelGray,
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
  final bool isBehind;

  const _TradingCard({
    required this.item,
    required this.imageUrl,
    required this.pastelTeal,
    required this.pastelGray,
    required this.pastelYellow,
    required this.teddyBrown,
    required this.isBehind,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: isBehind ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: teddyBrown,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (item['condition'] != null)
                  Chip(
                    label: Text(item['condition']),
                    backgroundColor: pastelGray,
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
                            color: pastelYellow,
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
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Color background;
  final Color border;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
      ),
    );
  }
} 