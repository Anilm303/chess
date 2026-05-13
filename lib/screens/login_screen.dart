import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/colors.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login(BuildContext context) async {
    final authService = context.read<AuthService>();

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final success = await authService.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed('/chess');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authService.error ?? 'Login failed')),
      );
    }
  }

  Future<void> _editBackendUrl(BuildContext context) async {
    final controller = TextEditingController(text: ApiService.baseUrl);
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Backend URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current URL: ${ApiService.baseUrl}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: MessengerColors.messengerBlue,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.1.70:7860/api',
                  helperText: 'Enter your computer\'s IP address',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () async {
                final candidate = controller.text.trim();
                final ok = await ApiService.testBaseUrl(candidate);
                if (!dialogContext.mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Backend reachable at $candidate'
                          : 'Backend not reachable at $candidate',
                    ),
                  ),
                );
              },
              child: const Text('Test'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final candidate = controller.text.trim();
                final ok = await ApiService.testBaseUrl(candidate);
                if (!dialogContext.mounted) return;

                if (!ok) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Backend URL is not reachable. Check the IP and port.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(candidate);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || !mounted) {
      return;
    }

    await ApiService.setBaseUrlOverride(result);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backend URL set to ${ApiService.baseUrl}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: constraints.maxHeight > 700 ? 40 : 16),

                    // Header
                    Container(
                      decoration: const BoxDecoration(
                        gradient: MessengerColors.messengerGradient,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Login to your chess account',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: constraints.maxHeight > 700 ? 48 : 24),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _editBackendUrl(context),
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('Backend URL'),
                      ),
                    ),

                    // Username field
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(
                          color: Color(0xFF8A8D91),
                          fontWeight: FontWeight.w600,
                        ),
                        hintText: 'Enter your username',
                        prefixIcon: const Icon(Icons.person_outline),
                        prefixIconColor: MessengerColors.messengerBlue,
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).inputDecorationTheme.fillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E5EA),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: MessengerColors.messengerBlue,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(
                          color: Color(0xFF8A8D91),
                          fontWeight: FontWeight.w600,
                        ),
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        prefixIconColor: MessengerColors.messengerBlue,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: MessengerColors.messengerBlue,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).inputDecorationTheme.fillColor,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E5EA),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: MessengerColors.messengerBlue,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Consumer<AuthService>(
                        builder: (context, authService, _) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: MessengerColors.messengerGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: MessengerColors.messengerBlue
                                      .withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: authService.isLoading
                                    ? null
                                    : () => _login(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Center(
                                  child: authService.isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.of(context).pushNamed('/register'),
                          child: Text(
                            'Register',
                            style: TextStyle(
                              color: Colors.brown[400],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom > 0
                          ? 24
                          : 0,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
