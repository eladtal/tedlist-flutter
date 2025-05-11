import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WebScaffold extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const WebScaffold({
    Key? key,
    required this.child,
    this.maxWidth = 600,
    this.padding = const EdgeInsets.all(24),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      );
    } else {
      return child;
    }
  }
} 