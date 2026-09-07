import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/full_backup_service.dart';
import '../theme/app_theme.dart';

class StartupRecoveryScreen extends StatefulWidget {
  const StartupRecoveryScreen({super.key, required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  State<StartupRecoveryScreen> createState() => _StartupRecoveryScreenState();
}

class _StartupRecoveryScreenState extends State<StartupRecoveryScreen> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _busy = false;
  String? _error;
  bool get _es =>
      WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'es';

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selected = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (selected == null) return;
      final bytes = selected.files.single.bytes;
      if (bytes == null) throw const FormatException('Unable to read backup.');
      final service = FullBackupService();
      final backup = service.parse(bytes);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: _navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: Text(_es ? 'Restaurar copia completa' : 'Restore full backup'),
          content: Text(
            _es
                ? 'Se restaurarán ${backup.sessionCount} sesiones y ${backup.pieceCount} piezas. Los datos originales se conservarán para recuperación.'
                : 'Restore ${backup.sessionCount} sessions and ${backup.pieceCount} pieces. Original database files will be retained for recovery.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_es ? 'Cancelar' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_es ? 'Restaurar' : 'Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final db = DatabaseService();
      await db.initializeRecoveryDatabase();
      await service.restore(db, backup);
      await db.activateRecoveryDatabase();
      await widget.onRetry();
    } catch (_) {
      DatabaseService().abandonRecoveryDatabase();
      if (mounted) {
        setState(
          () => _error = _es
              ? 'No se pudo restaurar. Revisa la copia y el espacio disponible y vuelve a intentar.'
              : 'Could not restore. Check the backup and available storage, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restore, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _es
                        ? 'No se pudo abrir tu diario'
                        : 'Your journal could not be opened',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _es
                        ? 'Tus datos no se han borrado. Libera espacio si es necesario y vuelve a intentar, o restaura una copia completa.'
                        : 'Your data has not been erased. Free storage if needed and retry, or restore a full backup.',
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : widget.onRetry,
                    child: Text(_es ? 'Reintentar' : 'Retry'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _restore,
                    child: Text(
                      _es ? 'Restaurar copia completa' : 'Restore full backup',
                    ),
                  ),
                  if (_busy) const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
