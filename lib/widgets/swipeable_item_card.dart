import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SwipeableItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final Widget Function(BuildContext, Map<String, dynamic>) builder;

  const SwipeableItemCard({
    Key? key,
    required this.item,
    this.onSwipeLeft,
    this.onSwipeRight,
    required this.builder,
  }) : super(key: key);

  @override
  State<SwipeableItemCard> createState() => _SwipeableItemCardState();
}

class _SwipeableItemCardState extends State<SwipeableItemCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      // Limit the drag to horizontal movement
      _dragOffset = Offset(_dragOffset.dx, 0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    // Calculate the velocity and position
    final velocity = details.velocity.pixelsPerSecond.dx;
    final position = _dragOffset.dx;

    // If dragged more than half the width or with high velocity
    if (position < -context.size!.width / 2 || velocity < -1000) {
      _controller.forward().then((_) {
        widget.onSwipeLeft?.call();
        _resetPosition();
      });
    } else if (position > context.size!.width / 2 || velocity > 1000) {
      _controller.reverse().then((_) {
        widget.onSwipeRight?.call();
        _resetPosition();
      });
    } else {
      _resetPosition();
    }
  }

  void _resetPosition() {
    setState(() {
      _dragOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Transform.translate(
        offset: _isDragging ? _dragOffset : _animation.value * context.size!.width,
        child: Stack(
          children: [
            // Background actions
            Positioned.fill(
              child: Row(
                children: [
                  // Left action (swipe right)
                  Expanded(
                    child: Container(
                      color: Colors.green,
                      child: const Center(
                        child: Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  // Right action (swipe left)
                  Expanded(
                    child: Container(
                      color: Colors.red,
                      child: const Center(
                        child: Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Item card
            widget.builder(context, widget.item),
          ],
        ),
      ),
    );
  }
} 