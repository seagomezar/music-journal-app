import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/localization_provider.dart';
import '../providers/practice_provider.dart';
import '../providers/routine_provider.dart';
import '../models/practice_appearance_preferences.dart';
import '../services/database_service.dart';
import '../services/journal_backup_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final JournalBackupService _backupService = JournalBackupService();
  bool _isTransferring = false;

  Future<void> _eraseAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.translate('erase_data_title')),
        content: Text(dialogContext.translate('erase_data_description')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.translate('erase_data_action')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final authProvider = context.read<AuthProvider>();
    final practiceProvider = context.read<PracticeProvider>();
    try {
      if (practiceProvider.isActive) {
        await practiceProvider.cancelSession();
      }
      await authProvider.eraseAllData();
      await practiceProvider.resetPreferences();
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('erase_data_error'))),
      );
    }
  }

  bool _canTransfer() {
    if (!context.read<PracticeProvider>().isActive) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.translate('backup_active_session'))),
    );
    return false;
  }

  Future<void> _savePracticePreference(Future<void> Function() change) async {
    try {
      await change();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('preference_save_error'))),
      );
    }
  }

  Future<void> _exportJournal() async {
    if (_isTransferring || !_canTransfer()) return;
    setState(() => _isTransferring = true);
    try {
      final routines = context.read<RoutineProvider>();
      final history = context.read<HistoryProvider>();
      await routines.loadRoutines();
      await history.loadSessions();
      if (!mounted) return;

      final now = DateTime.now();
      final source = _backupService.createBackup(
        routines: routines.routines,
        sessions: history.sessions,
        appVersion: '1.0.0',
        exportedAt: now,
      );
      final date =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final output = await FilePicker.saveFile(
        dialogTitle: context.translate('export_journal'),
        fileName: 'flute-practice-journal-$date.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(source)),
      );
      if (!kIsWeb && output == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('backup_exported'))),
      );
    } catch (error) {
      debugPrint('Journal export failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('backup_export_error'))),
      );
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _importJournal() async {
    if (_isTransferring || !_canTransfer()) return;
    setState(() => _isTransferring = true);
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
        withData: true,
      );
      if (selection == null) return;
      if (!mounted) return;
      final bytes = selection.files.single.bytes;
      if (bytes == null) {
        throw const JournalBackupException(
          'The selected file could not be read.',
        );
      }

      final backup = _backupService.parseBytes(bytes);
      final routines = context.read<RoutineProvider>();
      final history = context.read<HistoryProvider>();
      await routines.loadRoutines();
      await history.loadSessions();
      if (!mounted) return;
      final plan = _backupService.createImportPlan(
        backup: backup,
        existingRoutines: routines.routines,
        existingSessions: history.sessions,
      );
      final confirmed = await _confirmImport(plan);
      if (confirmed != true || !mounted) return;

      await DatabaseService().mergeJournalData(
        routines: plan.routinesToAdd,
        sessions: plan.sessionsToAdd,
      );
      await routines.loadRoutines();
      await history.loadSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.translate('backup_imported', [
              plan.routinesToAdd.length.toString(),
              plan.sessionsToAdd.length.toString(),
              plan.skippedCount.toString(),
            ]),
          ),
        ),
      );
    } on JournalBackupException catch (error) {
      debugPrint('Invalid journal backup: ${error.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('backup_invalid'))),
      );
    } catch (error) {
      debugPrint('Journal import failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('backup_import_error'))),
      );
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<bool?> _confirmImport(JournalImportPlan plan) {
    final conflicts = plan.routineConflicts + plan.sessionConflicts;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.translate('import_preview_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogContext.translate('backup_contains', [
                  plan.backup.routines.length.toString(),
                  plan.backup.sessions.length.toString(),
                ]),
              ),
              const SizedBox(height: 12),
              Text(
                dialogContext.translate('backup_will_add', [
                  plan.routinesToAdd.length.toString(),
                  plan.sessionsToAdd.length.toString(),
                  plan.skippedCount.toString(),
                ]),
              ),
              if (conflicts > 0) ...[
                const SizedBox(height: 8),
                Text(
                  dialogContext.translate('backup_conflicts', [
                    conflicts.toString(),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                dialogContext.translate('backup_exclusions'),
                style: TextStyle(color: AppTheme.textSecondaryColor(context)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.translate('cancel')),
          ),
          FilledButton(
            onPressed: plan.importedCount == 0
                ? null
                : () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.translate('import_add')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final practiceProvider = context.watch<PracticeProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(context.translate('settings'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTheme.glassCard(
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor(context),
                    child: Icon(
                      Icons.person_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  title: Text(user?.name ?? context.translate('local_profile')),
                  subtitle: Text(context.translate('local_only_data')),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                context.translate('practice_preferences'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.accentColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.light_mode_outlined),
              title: Text(context.translate('keep_screen_awake')),
              subtitle: Text(context.translate('keep_screen_awake_subtitle')),
              value: practiceProvider.keepScreenAwake,
              onChanged: (enabled) async {
                try {
                  await practiceProvider.setKeepScreenAwake(enabled);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.translate('preference_save_error'),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            AppTheme.glassCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.translate('appearance_feedback'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.translate('appearance_feedback_subtitle'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PracticeVisualMode>(
                    initialValue: practiceProvider.visualMode,
                    decoration: InputDecoration(
                      labelText: context.translate('practice_visual_mode'),
                      helperText: context.translate(
                        'practice_visual_mode_subtitle',
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: PracticeVisualMode.focused,
                        child: Text(context.translate('focused_mode')),
                      ),
                      DropdownMenuItem(
                        value: PracticeVisualMode.full,
                        child: Text(context.translate('full_mode')),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        _savePracticePreference(
                          () => practiceProvider.setVisualMode(mode),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ThemeMode>(
                    initialValue: practiceProvider.themeMode,
                    decoration: InputDecoration(
                      labelText: context.translate('theme_mode'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(context.translate('theme_system')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(context.translate('theme_light')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(context.translate('theme_dark')),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        _savePracticePreference(
                          () => practiceProvider.setThemeMode(mode),
                        );
                      }
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.vibration_outlined),
                    title: Text(context.translate('haptics')),
                    subtitle: Text(context.translate('haptics_subtitle')),
                    value: practiceProvider.hapticsEnabled,
                    onChanged: (value) => _savePracticePreference(
                      () => practiceProvider.setHapticsEnabled(value),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.notifications_none_rounded),
                    title: Text(context.translate('sound_cues')),
                    subtitle: Text(context.translate('sound_cues_subtitle')),
                    value: practiceProvider.soundCuesEnabled,
                    onChanged: (value) => _savePracticePreference(
                      () => practiceProvider.setSoundCuesEnabled(value),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.motion_photos_off_outlined),
                    title: Text(context.translate('reduced_motion')),
                    subtitle: Text(
                      context.translate('reduced_motion_subtitle'),
                    ),
                    value: practiceProvider.reducedMotion,
                    onChanged: (value) => _savePracticePreference(
                      () => practiceProvider.setReducedMotion(value),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.celebration_outlined),
                    title: Text(context.translate('show_celebrations')),
                    subtitle: Text(
                      context.translate('show_celebrations_subtitle'),
                    ),
                    value: practiceProvider.showCelebrations,
                    onChanged: (value) => _savePracticePreference(
                      () => practiceProvider.setShowCelebrations(value),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                context.translate('data_portability'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.accentColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: Text(context.translate('export_journal')),
              subtitle: Text(context.translate('export_journal_subtitle')),
              trailing: _isTransferring
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _isTransferring ? null : _exportJournal,
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: Text(context.translate('import_journal')),
              subtitle: Text(context.translate('import_journal_subtitle')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _isTransferring ? null : _importJournal,
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(context.translate('privacy_policy')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(context.translate('terms_and_conditions')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TermsAndConditionsScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_rounded),
              title: Text(context.translate('support')),
              subtitle: const Text(
                'github.com/seagomezar/music-journal-app/issues',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SupportScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(context.translate('about')),
              subtitle: const Text('Flute Practice Coach 1.0.0'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Flute Practice Coach',
                applicationVersion: '1.0.0',
              ),
            ),
            const Divider(height: 32),
            ListTile(
              leading: Icon(
                Icons.delete_forever_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                context.translate('erase_all_data'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: Text(context.translate('erase_all_data_subtitle')),
              onTap: () => _eraseAllData(context),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSpanish = context.watch<LocalizationProvider>().isSpanish;
    final sections = isSpanish ? _privacyEs : _privacyEn;
    return _DocumentScreen(
      title: context.translate('privacy_policy'),
      sections: sections,
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSpanish = context.watch<LocalizationProvider>().isSpanish;
    return _DocumentScreen(
      title: context.translate('support'),
      sections: isSpanish ? _supportEs : _supportEn,
    );
  }
}

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSpanish = context.watch<LocalizationProvider>().isSpanish;
    return _DocumentScreen(
      title: context.translate('terms_and_conditions'),
      sections: isSpanish ? _termsEs : _termsEn,
    );
  }
}

class _DocumentScreen extends StatelessWidget {
  const _DocumentScreen({required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: sections.length,
          separatorBuilder: (_, _) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final section = sections[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.$1,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                SelectableText(section.$2),
              ],
            );
          },
        ),
      ),
    );
  }
}

const _privacyEn = <(String, String)>[
  ('Effective date', 'July 24, 2026'),
  (
    'Summary',
    'Flute Practice Coach is a local-first practice journal. It does not use advertising or an online account, and it does not sell personal data. The deployed web version may send optional aggregate app-launch, onboarding, and session-start events through Plausible when configured; it never sends journal, profile, audio, or pitch data.',
  ),
  (
    'Data stored on your device',
    'Your display name, routines, repertoire details, practice history, notes, imported PDF scores, and recordings are managed locally in the app’s private storage. An operating-system backup or device-transfer feature you enable may include some app data.',
  ),
  (
    'Microphone',
    'Microphone access is requested only when you choose to use the tuner, track exercise intonation, or make a self-evaluation recording. Tuner and pitch analysis run locally on your device; analyzed audio is not saved or transmitted. Capture continues during supported screen-lock and background states and stops when you stop or close the recorder, finish or discard a session, or erase app data. Browsers may suspend microphone capture while a hidden tab is inactive.',
  ),
  (
    'Sharing and retention',
    'The app does not transmit your journal, PDFs, or recordings to us. The deployed web version sends only the aggregate events described above when analytics are enabled. If you export a journal backup, the operating system saves the file where you choose. Exported backups contain routines, session history, and notes, are not encrypted, and exclude recordings and PDFs. App-managed data remains until you delete individual content, erase all data in Settings, or uninstall the app.',
  ),
  (
    'Your choices',
    'You may deny microphone access and use all features that do not require it. Settings provides an Erase all data action that permanently removes the local profile and all app-managed files.',
  ),
  (
    'Support',
    'Questions and privacy requests can be submitted at github.com/seagomezar/music-journal-app/issues.',
  ),
];

const _privacyEs = <(String, String)>[
  ('Fecha de vigencia', '24 de julio de 2026'),
  (
    'Resumen',
    'Flute Practice Coach es un diario de práctica local. No utiliza publicidad ni cuentas en línea, y no vende datos personales. La versión web publicada puede enviar eventos agregados opcionales de inicio, incorporación y comienzo de sesión a través de Plausible cuando se configura; nunca envía tu diario, perfil, audio ni datos de afinación.',
  ),
  (
    'Datos guardados en tu dispositivo',
    'Tu nombre visible, rutinas, repertorio, historial, notas, partituras PDF y grabaciones se administran localmente en el almacenamiento privado de la app. Una copia de seguridad o transferencia del sistema que habilites puede incluir algunos datos de la app.',
  ),
  (
    'Micrófono',
    'El acceso al micrófono se solicita solo cuando decides usar el afinador, medir la afinación durante un ejercicio o crear una grabación de autoevaluación. El afinador y el análisis de afinación se ejecutan localmente; el audio analizado no se guarda ni se transmite. La captura continúa durante los estados compatibles de bloqueo de pantalla y segundo plano, y se detiene al cerrar la grabadora, finalizar o descartar la sesión, o borrar los datos. Los navegadores pueden suspender el micrófono cuando una pestaña oculta queda inactiva.',
  ),
  (
    'Uso compartido y conservación',
    'La app no nos transmite tu diario, archivos PDF ni grabaciones. La versión web publicada solo envía los eventos agregados descritos arriba cuando se activa la analítica. Si exportas una copia del diario, el sistema operativo guarda el archivo donde elijas. Las copias contienen rutinas, historial y notas, no están cifradas y excluyen grabaciones y archivos PDF. Los datos permanecen hasta que elimines el contenido, borres todos los datos o desinstales la app.',
  ),
  (
    'Tus opciones',
    'Puedes denegar el acceso al micrófono y usar todas las funciones que no lo requieren. Ajustes incluye la opción Borrar todos los datos.',
  ),
  (
    'Soporte',
    'Puedes enviar preguntas o solicitudes de privacidad en github.com/seagomezar/music-journal-app/issues.',
  ),
];

const _termsEn = <(String, String)>[
  ('Effective date', 'July 24, 2026'),
  (
    'Acceptance',
    'By downloading, installing, or using Flute Practice Coach, you agree to these Terms and the Privacy Policy. If you cannot legally enter this agreement, use the app only with permission and supervision from a parent or legal guardian.',
  ),
  (
    'License and ownership',
    'You may use the app for personal, non-commercial practice and study, subject to applicable app-store rules. Open-source software remains governed by its MIT or third-party licenses. The Flute Practice Coach name and branding are not transferred to you.',
  ),
  (
    'Your content',
    'You retain your rights in routines, notes, recordings, scores, and other material you add. You are responsible for having permission to import, copy, record, or use that material, including copyright permission for sheet music and consent before recording another person.',
  ),
  (
    'Responsible use',
    'Do not use the app unlawfully, infringe another person’s rights, bypass device protections, make recordings without required consent, or store unlawful, abusive, or harmful content.',
  ),
  (
    'Local data and backups',
    'The app has no account or developer-operated cloud sync. Settings can export routines and practice history to a user-controlled, unencrypted file and merge a compatible file into the journal. Exports exclude recordings and PDFs. You are responsible for protecting and deleting exported files. Deleting content, erasing app data, uninstalling the app, losing your device, or device failure may permanently remove content that was not exported. We cannot restore data we never received.',
  ),
  (
    'Educational purpose and availability',
    'The app is an organization and self-reflection tool, not a replacement for a qualified music teacher, hearing protection guidance, or medical advice. Features may change or become unavailable as devices, operating systems, and store requirements evolve.',
  ),
  (
    'Disclaimers and liability',
    'To the fullest extent permitted by law, the app is provided as is and as available, without warranties of uninterrupted operation, fitness, accuracy, or data preservation. We are not liable for indirect or consequential loss or loss of data. Non-waivable consumer rights remain unaffected.',
  ),
  (
    'Changes and contact',
    'Updated terms will be posted at seagomezar.github.io/music-journal-app/terms-and-conditions.html with a new effective date. Questions can be submitted at github.com/seagomezar/music-journal-app/issues. GitHub issues are public; do not include private files or sensitive information.',
  ),
];

const _termsEs = <(String, String)>[
  ('Fecha de vigencia', '24 de julio de 2026'),
  (
    'Aceptación',
    'Al descargar, instalar o usar Flute Practice Coach, aceptas estos Términos y la Política de Privacidad. Si no puedes aceptar legalmente este acuerdo, usa la app solo con permiso y supervisión de tu padre, madre o representante legal.',
  ),
  (
    'Licencia y propiedad',
    'Puedes usar la app para tu práctica y estudio personal no comercial, sujeto a las reglas de la tienda. El software de código abierto sigue regido por la licencia MIT o las licencias de terceros. El nombre y la identidad de Flute Practice Coach no se transfieren.',
  ),
  (
    'Tu contenido',
    'Conservas tus derechos sobre rutinas, notas, grabaciones, partituras y demás material que agregues. Eres responsable de contar con permiso para importarlo, copiarlo, grabarlo o usarlo, incluidos los derechos de autor de partituras y el consentimiento antes de grabar a otra persona.',
  ),
  (
    'Uso responsable',
    'No uses la app de forma ilegal, para infringir derechos, eludir protecciones del dispositivo, grabar sin el consentimiento requerido o guardar contenido ilegal, abusivo o dañino.',
  ),
  (
    'Datos locales y copias de seguridad',
    'La app no tiene cuenta ni sincronización en la nube operada por nosotros. Ajustes permite exportar rutinas e historial a un archivo sin cifrar bajo tu control e integrar un archivo compatible. Las copias excluyen grabaciones y PDF. Eres responsable de proteger y eliminar los archivos exportados. El contenido no exportado puede perderse al borrar datos, desinstalar la app, perder el dispositivo o por una falla. No podemos recuperar datos que nunca recibimos.',
  ),
  (
    'Finalidad educativa y disponibilidad',
    'La app es una herramienta de organización y autoevaluación. No sustituye a un docente de música, recomendaciones de protección auditiva ni asesoría médica. Las funciones pueden cambiar según los dispositivos, sistemas y requisitos de las tiendas.',
  ),
  (
    'Exclusiones y responsabilidad',
    'En la máxima medida permitida por la ley, la app se ofrece tal cual y según disponibilidad, sin garantías de funcionamiento ininterrumpido, idoneidad, exactitud o conservación de datos. No respondemos por pérdidas indirectas, consecuentes o de datos. Los derechos irrenunciables del consumidor no se ven afectados.',
  ),
  (
    'Cambios y contacto',
    'Los términos actualizados se publicarán en seagomezar.github.io/music-journal-app/terms-and-conditions.html con una nueva fecha. Puedes enviar preguntas en github.com/seagomezar/music-journal-app/issues. Los reportes son públicos; no incluyas archivos privados ni información sensible.',
  ),
];

const _supportEn = <(String, String)>[
  (
    'Get help',
    'Report a problem at github.com/seagomezar/music-journal-app/issues. Include the app version, device model, operating-system version, and steps to reproduce the problem. Do not attach private recordings or scores.',
  ),
  (
    'Recording problems',
    'Confirm microphone access in system Settings. The app remains usable without microphone permission.',
  ),
  (
    'Missing files',
    'Newly imported PDFs and recordings are copied into private app storage. Erasing app data or uninstalling the app permanently removes those files.',
  ),
];

const _supportEs = <(String, String)>[
  (
    'Obtener ayuda',
    'Reporta un problema en github.com/seagomezar/music-journal-app/issues. Incluye la versión de la app, modelo del dispositivo, versión del sistema y pasos para reproducirlo. No adjuntes grabaciones ni partituras privadas.',
  ),
  (
    'Problemas de grabación',
    'Confirma el permiso del micrófono en los ajustes del sistema. Puedes usar la app sin conceder ese permiso.',
  ),
  (
    'Archivos faltantes',
    'Los nuevos archivos PDF y grabaciones se copian al almacenamiento privado de la app. Borrar los datos o desinstalar la app elimina esos archivos de forma permanente.',
  ),
];
