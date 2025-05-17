import 'package:flutter/material.dart';
import '../items/home_screen.dart';
import '../items/my_listings_screen.dart';
// Import other screens you might want in the main navigation
// import '../user/profile_screen.dart'; // Example

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // List of widgets to call in the body of the Scaffold
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),
    MyListingsScreen(),
    // Placeholder for a potential third screen, e.g., Profile
    // ProfileScreen(), 
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'My Listings',
          ),
          // Example for a third item
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.person_outline),
          //   activeIcon: Icon(Icons.person),
          //   label: 'Profile',
          // ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        // To make it feel more like a footer on web, consider these properties:
        // type: BottomNavigationBarType.fixed, // Ensures items don't shift
        // showUnselectedLabels: true, // Optional: always show labels
      ),
    );
  }
} 