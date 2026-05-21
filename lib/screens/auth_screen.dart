import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/auth_provider.dart';
import '../providers/localization_provider.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleGoogleSignIn(BuildContext context) async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProv.signInWithGoogle();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.translate('welcome_back')} ${authProv.user?.name}!'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  void _handleGuestSignIn(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      await authProv.signInGuest(_nameController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.translate('welcome_back')} ${authProv.user?.name}!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final locProv = Provider.of<LocalizationProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background subtle decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondary.withOpacity(0.1),
              ),
            ),
          ),
          
          // Language Switcher Floating Button
          Positioned(
            top: 40,
            right: 16,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                backgroundColor: AppTheme.surface.withOpacity(0.7),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              icon: const Icon(Icons.language_rounded, color: AppTheme.primaryAccent, size: 18),
              label: Text(
                locProv.isSpanish ? 'Español (ES)' : 'English (EN)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                locProv.setLocale(locProv.isSpanish ? 'en' : 'es');
              },
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon Logo Header
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.brandGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Title
                    Text(
                      context.translate('app_title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.translate('app_subtitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 40),

                    if (authProv.isLoading)
                      const Center(
                        child: SpinKitDoubleBounce(
                          color: AppTheme.primaryAccent,
                          size: 50.0,
                        ),
                      )
                    else ...[
                      // Main Authentication Card
                      AppTheme.glassCard(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.translate('sign_in'),
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              
                              // Google Sign In button
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.g_mobiledata_rounded, size: 30, color: Colors.red),
                                label: Text(
                                  context.translate('sign_in_google'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                onPressed: () => _handleGoogleSignIn(context),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Divider
                              Row(
                                children: [
                                  Expanded(child: Divider(color: AppTheme.border.withOpacity(0.5))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      context.translate('or_practice_offline'),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: AppTheme.border.withOpacity(0.5))),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Guest Name input
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: context.translate('your_name'),
                                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.textSecondary),
                                  hintText: locProv.isSpanish ? 'Ingresa tu nombre' : 'Enter name for offline profile',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return context.translate('enter_valid_name');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Guest Enter button
                              Container(
                                decoration: BoxDecoration(
                                  gradient: AppTheme.brandGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => _handleGuestSignIn(context),
                                  child: Text(
                                    context.translate('practice_as_guest'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
