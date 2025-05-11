import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'providers/item_provider.dart';

// This function runs before the app and can be used to initialize providers
Future<void> initializeProviders(ProviderContainer container) async {
  // Trigger initial load of items
  container.read(itemsProvider.notifier).loadItems();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create provider container
  final container = ProviderContainer();
  
  // Initialize providers
  await initializeProviders(container);
  
  // Run app with provider scope
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TedlistApp(),
    ),
  );
}
