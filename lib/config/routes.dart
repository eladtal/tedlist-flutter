import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Import screens from features
import '../features/items/home_screen.dart';
import '../features/items/publish_item_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../widgets/web_scaffold.dart';

// Static navigation class that can be called from anywhere
class AppRouter {
  static late GoRouter router;
  
  // Direct navigation to home without depending on context
  static void navigateToHome() {
    debugPrint('🔥 Forcing direct navigation to home');
    router.go('/');
  }
}

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return ScaffoldWithBottomNav(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) {
              // Check if we just deleted an item and should show a success message
              final extra = state.extra as Map<String, dynamic>?;
              if (extra != null && extra.containsKey('forceRebuild')) {
                debugPrint('🔄 Home route forced rebuild with: $extra');
                
                // Show success message after navigation
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${extra['itemTitle']}" successfully deleted'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                });
              }
              
              return const HomeScreen();
            },
          ),
          GoRoute(
            path: '/publish',
            name: 'publish',
            builder: (context, state) => const PublishItemScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/home-after-delete',
            name: 'homeAfterDelete',
            builder: (context, state) {
              // Show success message from parameters if available
              final params = state.extra as Map<String, dynamic>?;
              if (params != null && params['showSuccess'] == true && params['itemTitle'] != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${params['itemTitle']}" successfully deleted'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                });
              }
              return const HomeScreen();
            },
          ),
        ],
      ),
    ],
    // Redirect to login if not authenticated
    redirect: (context, state) {
      // TODO: Add authentication check logic when auth service is implemented
      return null;
    },
    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
  
  // Store the router in our static class for global access
  AppRouter.router = router;
  
  return router;
});

class ScaffoldWithBottomNav extends StatelessWidget {
  final Widget child;

  const ScaffoldWithBottomNav({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: kWebMaxWidth),
              child: NavigationBar(
                onDestinationSelected: (index) {
                  switch (index) {
                    case 0:
                      context.go('/');
                      break;
                    case 1:
                      context.go('/publish');
                      break;
                    case 2:
                      context.go('/profile');
                      break;
                  }
                },
                selectedIndex: _calculateSelectedIndex(context),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.add_circle_outline, size: 32),
                    selectedIcon: Icon(Icons.add_circle, size: 32),
                    label: 'Publish',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: kWebMaxWidth),
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                '© 2024 Tedlist. All rights reserved.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/publish')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }
} 