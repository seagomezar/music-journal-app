import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/auth_provider.dart';
import '../providers/localization_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../services/analytics_service.dart';

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

  void _handleCreateProfile(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      try {
        await authProv.createLocalProfile(_nameController.text);
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('profile_create_error'))),
        );
        return;
      }
      if (context.mounted) {
        AnalyticsService.track('onboarding_complete');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.translate('welcome_back')} ${authProv.user?.name}!',
            ),
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
      body: SafeArea(
        child: Stack(
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
                  color: AppTheme.primary.withValues(alpha: 0.15),
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
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                ),
              ),
            ),

            // Language Switcher Floating Button
            Positioned(
              top: 8,
              right: 16,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  backgroundColor: AppTheme.surface.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppTheme.border, width: 1),
                  ),
                ),
                icon: const Icon(
                  Icons.language_rounded,
                  color: AppTheme.primaryAccent,
                  size: 18,
                ),
                label: Text(
                  locProv.isSpanish ? 'Español (ES)' : 'English (EN)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
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
                      // Premium App Logo Header
                      const Center(child: AppLogo(size: 110, showShadow: true)),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        context.translate('app_title'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.translate('app_subtitle'),
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 15),
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
                                  context.translate('local_profile_title'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),

                                Text(
                                  context.translate(
                                    'local_profile_description',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 20),

                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: context.translate('your_name'),
                                    prefixIcon: const Icon(
                                      Icons.person_outline_rounded,
                                      color: AppTheme.textSecondary,
                                    ),
                                    hintText: locProv.isSpanish
                                        ? 'Ingresa tu nombre'
                                        : 'Enter your name',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return context.translate(
                                        'enter_valid_name',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Local profile button
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _handleCreateProfile(context),
                                    child: Text(
                                      context.translate('continue_local'),
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
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
