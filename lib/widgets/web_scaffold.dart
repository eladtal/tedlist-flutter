import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const double kWebMaxWidth = 600;

class WebScaffold extends StatelessWidget {
  final Widget content;
  final Widget? header;
  final Widget? footer;
  final double maxWidth;
  final EdgeInsetsGeometry contentPadding;

  const WebScaffold({
    Key? key,
    required this.content,
    this.header,
    this.footer,
    this.maxWidth = 600,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                // Header
                if (header != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.background,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: header,
                  ),
                // Main content
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: contentPadding,
                    child: content,
                  ),
                ),
                // Footer
                Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: kWebMaxWidth),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.background,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (footer != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: footer,
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
    } else {
      return content;
    }
  }
} 