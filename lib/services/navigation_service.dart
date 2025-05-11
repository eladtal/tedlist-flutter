import 'package:flutter/material.dart';

class NavigationService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  NavigatorState? get navigator => navigatorKey.currentState;

  Future<dynamic> navigateTo(String routeName, {dynamic arguments}) {
    return navigator!.pushNamed(routeName, arguments: arguments);
  }

  Future<dynamic> replaceTo(String routeName, {dynamic arguments}) {
    return navigator!.pushReplacementNamed(routeName, arguments: arguments);
  }

  Future<dynamic> pushReplacement(Widget page) {
    return navigator!.pushReplacement(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void pop([dynamic result]) {
    navigator!.pop(result);
  }

  void popUntilFirst() {
    navigator!.popUntil((route) => route.isFirst);
  }

  void forceNavigateAndClear(Widget page) {
    navigator!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => page),
      (route) => false, // Remove all routes
    );
  }
}

// Global instance
final navigationService = NavigationService(); 