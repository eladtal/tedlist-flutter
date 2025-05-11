import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  bool _biometricForgotten = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
      final response = await _apiService.get('auth/validate');
      setState(() {
        _userData = response;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      setState(() => _isLoading = true);
      await _apiService.logout();
      if (!mounted) return;
      
      // Navigate to login screen
      context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgetBiometricLogin() async {
    setState(() => _isLoading = true);
    await BiometricService.setBiometricEnabled(false);
    await _apiService.clearToken();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric login forgotten. You will need to log in with email and password next time.')),
      );
      setState(() {
        _isLoading = false;
        _biometricForgotten = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isLoading ? null : _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            _userData?['name']?[0]?.toUpperCase() ?? 'U',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userData?['name'] ?? 'User',
                          style: theme.textTheme.headlineSmall,
                        ),
                        Text(
                          _userData?['email'] ?? '',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Stats Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stats',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(
                                icon: Icons.swap_horiz,
                                label: 'Trades',
                                value: _userData?['stats']?['trades']?.toString() ?? '0',
                              ),
                              _StatItem(
                                icon: Icons.inventory_2,
                                label: 'Listings',
                                value: _userData?['stats']?['listings']?.toString() ?? '0',
                              ),
                              _StatItem(
                                icon: Icons.star,
                                label: 'XP',
                                value: _userData?['stats']?['xp']?.toString() ?? '0',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Settings Section
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Edit Profile'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to edit profile screen
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.notifications),
                          title: const Text('Notifications'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to notifications settings
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.security),
                          title: const Text('Privacy & Security'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to privacy settings
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.fingerprint),
                          title: Text(_biometricForgotten ? 'Biometric login forgotten' : 'Forget Biometric Login'),
                          trailing: const Icon(Icons.chevron_right),
                          enabled: !_biometricForgotten && !_isLoading,
                          onTap: (!_biometricForgotten && !_isLoading) ? _forgetBiometricLogin : null,
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

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
} 