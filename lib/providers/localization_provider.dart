import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';

class LocalizationProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  String _localeCode = 'en';

  String get localeCode => _localeCode;
  bool get isSpanish => _localeCode == 'es';

  LocalizationProvider({String? initialLocale}) {
    if (initialLocale != null) {
      _localeCode = initialLocale == 'es' ? 'es' : 'en';
    } else {
      _loadLocale();
    }
  }

  void _loadLocale() {
    _localeCode = _db.getPreferredLocale();
  }

  Future<void> setLocale(String langCode) async {
    if (langCode != 'en' && langCode != 'es') return;
    if (_localeCode == langCode) return;
    final previousLocaleCode = _localeCode;
    _localeCode = langCode;
    notifyListeners();
    try {
      await _db.setPreferredLocale(langCode);
    } catch (_) {
      _localeCode = previousLocaleCode;
      notifyListeners();
      rethrow;
    }
  }

  String translate(String key, [List<String>? args]) {
    final dictionary = _localeCode == 'es' ? _es : _en;
    var val = dictionary[key] ?? key;
    if (args != null && args.isNotEmpty) {
      for (final arg in args) {
        val = val.replaceFirst('{}', arg);
      }
    }
    return val;
  }

  // --- ENGLISH DICTIONARY ---
  static const Map<String, String> _en = {
    'app_title': 'Flute Practice Coach',
    'app_subtitle': 'Your private, focused practice journal',
    'local_profile_title': 'Set up your local profile',
    'local_profile_description':
        'Your practice journal is managed locally by the app. No account or internet connection is required.',
    'continue_local': 'Continue',
    'profile_create_error':
        'The local profile could not be created. Please try again.',
    'or_practice_offline': 'OR PRACTICE OFFLINE',
    'your_name': 'Your Name',
    'practice_as_guest': 'Practice as Guest',
    'sign_out': 'Sign Out',
    'welcome_back': 'Welcome back,',
    'weekly_progress': 'Weekly Practice Progress',
    'minutes': 'minutes',
    'streak_days': '{} Days Current Streak',
    'current_streak_title': 'Current Streak',
    'total_sessions_title': 'Total Sessions',
    'exercises_done_title': 'Exercises Done',
    'total_study_time_title': 'Total Study Time',
    'days': 'Days',
    'update_goal_title': 'Update Weekly Practice Goal',
    'update_goal_desc':
        'Define how many minutes you want to study per week. We will track your progress automatically.',
    'target_minutes': 'Target Minutes',
    'save': 'Save',
    'no_routines_configured':
        'No routines configured yet.\nGo to the Routines tab to create one!',
    'technical_exercises_count': '{} technical exercises',
    'total_sessions': '{} Total Sessions',
    'exercises_done': '{} Exercises Done',
    'total_study_time': '{}m Total Study Time',
    'quick_start': 'Quick Start Routines',
    'free_study': 'Free Study',
    'dashboard_nav': 'Dashboard',
    'active_practice_session': 'Active Practice Session',
    'routine_label': 'Routine: {}',
    'free_study_piece': 'Free Study Piece',
    'routines': 'Routines',
    'repertoire': 'Repertoire',
    'history': 'History',
    // Active Practice View
    'free_repertoire_study': 'Free Repertoire Study',
    'study_clock_running': 'STUDY CLOCK RUNNING',
    'study_clock_paused': 'STUDY CLOCK PAUSED',
    'pause': 'Pause',
    'resume': 'Resume',
    'finish': 'Finish',
    'repertoire_tracking': 'Repertoire Active Piece Tracking',
    'repertoire_tracking_subtitle':
        'Select the sheet music you are working on to accumulate time directly.',
    'none_technical_only': 'None (Technical Exercises Only)',
    'visual_metronome': 'Metronome',
    'tempo': 'Tempo: {} BPM',
    'decrease_tempo': 'Decrease tempo by 1 BPM',
    'increase_tempo': 'Increase tempo by 1 BPM',
    'metronome_sound': 'Metronome sound',
    'enable_metronome_sound': 'Turn metronome sound on',
    'mute_metronome': 'Mute metronome sound',
    'metronome_sound_suppressed':
        'Sound is muted while recording or playing back audio.',
    'tuner': 'Tuner',
    'tuner_subtitle':
        'Tune freely or measure your intonation during an exercise.',
    'show_tuner': 'Show tuner',
    'hide_tuner': 'Hide tuner and stop listening',
    'decrease_tuner_reference': 'Lower the A4 reference by 1 Hz',
    'increase_tuner_reference': 'Raise the A4 reference by 1 Hz',
    'pitch_tolerance': 'On-pitch tolerance',
    'play_a_note': 'Play a steady note',
    'waiting_for_stable_pitch': 'Waiting for a stable pitch…',
    'on_pitch_live': '{}% on pitch • {} analyzed',
    'track_my_pitch': 'Track my pitch',
    'tune_now': 'Tune',
    'stop_pitch_tracking': 'Stop tracking',
    'stop_listening': 'Stop listening',
    'tuner_mic_error':
        'The microphone is unavailable. Stop the recorder and check microphone permission.',
    'tuner_headphones_hint':
        'Headphones improve accuracy while the metronome is sounding.',
    'self_recorder': 'Self-Evaluation Recorder',
    'self_recorder_subtitle':
        'Record a passage, play it back, and listen to your tone and articulation.',
    'open_self_recorder': 'Open Self-Recorder',
    'close_recorder': 'Close Recorder',
    'recording_paused': 'Recording Paused',
    'recording_stopped': 'Recording Stopped',
    'recording_playing': 'Playing Recording',
    'recording_active': 'RECORDING AUDIO...',
    'mic_error':
        'Microphone permission not granted or recorder not initialized.',
    // Finish Dialog
    'finish_session_title': 'Finish Practice Session?',
    'finish_session_subtitle':
        'Review your practice notes before saving. The session details and recordings will be logged to your history.',
    'finish_session_subtitle_web':
        'Review your practice notes before saving. Session details and browser recordings are saved to this browser’s history.',
    'practice_notes': 'Practice Notes',
    'exercise_notes_draft_title': 'Exercises worked:',
    'exercise_notes_draft_item': '• {} — {} BPM',
    'exercise_notes_draft_item_pitch':
        '• {} — {} BPM — {}% on pitch (A4 {} Hz, ±{}¢)',
    'keep_practicing': 'Keep Practicing',
    'save_finish': 'Save & Finish',
    'exit_practice_title': 'Exit Practice?',
    'exit_practice_desc':
        'Do you want to discard your current progress or keep studying?',
    'discard_session_btn': 'Discard Session',
    'select_active_sheet': 'Select active sheet piece',
    'exercises_for_routine': 'Exercises for: {}',
    'start_exercise': 'Start',
    'resume_exercise': 'Again',
    'stop_exercise': 'Stop',
    'exercise_elapsed': 'Exercise: {}',
    'practiced_tempo': '{} BPM practiced',
    'exercise_result_format': '{} • {} • {} BPM',
    'exercise_result_with_pitch_format':
        '{} • {} • {} BPM • {}% on pitch • {} analyzed • A4 {} Hz • ±{}¢',
    'exercise_tempo_save_error':
        'The routine tempo could not be saved. The previous tempo was restored.',
    'recording_audio': 'Recording audio...',
    'recording_saved_temp': 'Practice recording saved on this device',
    'recording_count_format': '{} recordings saved in this session',
    'recording_take_number': 'Take {}',
    'recording_library': 'Recording Library',
    'recording_library_subtitle':
        'Listen to, rename, or delete recordings from saved sessions.',
    'recording_library_empty': 'No saved recordings yet.',
    'recording_actions': 'Recording actions',
    'rename_recording': 'Rename',
    'rename_recording_title': 'Rename recording',
    'recording_name_label': 'Recording name',
    'delete_recording_title': 'Delete recording?',
    'delete_recording_confirm': 'Delete "{}"? This cannot be undone.',
    'recording_rename_error': 'The recording name could not be saved.',
    'recording_delete_error': 'The recording could not be deleted.',
    'start_recording': 'Start recording',
    'stop_recording': 'Stop recording',
    'delete_recording': 'Delete recording',
    'mic_ready': 'Microphone Ready',
    // Routines View
    'routines_title': 'Technical Study Routines',
    'routines_subtitle':
        'Structure your daily scale drills, long tones, and articulation guides.',
    'add_routine': 'Create Custom Routine',
    'routines_tab_title': 'Study Routines',
    'new_routine_title': 'New Study Routine',
    'create_btn': 'Create',
    'add_exercise_to': 'Add Exercise to {}',
    'edit_exercise_title': 'Edit Exercise in {}',
    'edit_exercise': 'Edit exercise',
    'reorder_exercise': 'Reorder exercise',
    'reorder_exercises_hint': 'Drag the handle to reorder exercises.',
    'target_bpm_tempo': 'Target BPM (Tempo)',
    'add_btn': 'Add',
    'no_routines_configured_empty': 'No study routines configured.',
    'click_add_routine':
        'Click the "+" button in the top right to build your first technical routine.',
    'technical_exercises_default': 'Technical exercises',
    'technical_checklist': 'Technical Checklist',
    'no_exercises_added': 'No exercises added yet.',
    'exercise_detail_format': '{} • Target: {} BPM',
    'delete_routine_title': 'Delete Routine?',
    'delete_routine_confirm':
        'Are you sure you want to delete "{}"? This cannot be undone.',
    'delete_btn': 'Delete',
    'routine_title_label': 'Routine Title',
    'routine_desc_label': 'Description',
    'exercises_list': 'Exercises',
    'add_exercise': 'Add Exercise',
    'exercise_name_label': 'Exercise Name',
    'articulation_label': 'Articulation',
    'target_bpm_label': 'Target BPM',
    'save_routine': 'Save Routine',
    'cancel': 'Cancel',
    // Repertoire View
    'repertoire_title': 'My Repertoire Binder',
    'repertoire_subtitle':
        'Track your sheet music pieces, measure mastery, and metronome targets.',
    'add_piece': 'Add Repertoire Piece',
    'repertoire_manager_title': 'Repertoire Manager',
    'title_label': 'Title',
    'total_measures': 'Total Measures',
    'study_focus_notes': 'Study Focus Notes',
    'no_pdf_attached': 'No PDF sheet attached',
    'change_btn': 'Change',
    'browse_btn': 'Browse',
    'composer_format': 'Composer: {}',
    'target_tempo_format': 'Target Tempo: {} BPM',
    'score_sheet_format': 'Score sheet: {}',
    'measures_progress_format': 'Measures Progress: {} / {}',
    'focus_notes_label': 'Focus Notes:',
    'no_focus_notes': 'No focus notes written.',
    'save_progress_btn': 'Save Progress',
    'repertoire_empty_title': 'Your repertoire binder is empty.',
    'repertoire_empty_desc':
        'Click the "+" button in the top right to catalog a musical piece and track your progress.',
    'unknown': 'Unknown',
    'meas_count_format': '{} / {} meas.',
    'piece_title_label': 'Piece Title',
    'composer_label': 'Composer',
    'measures_total': 'Total Measures',
    'measures_completed': 'Measures Completed',
    'study_notes': 'Study Notes',
    'save_piece': 'Save Piece',
    'progress_percent': '{}% completed',
    // History View
    'history_title': 'Practice Logs & Calendar',
    'history_subtitle':
        'Track your dedication heat map and replay self-recorder sessions.',
    'session_details': 'Session Details',
    'no_sessions_day': 'No practice sessions recorded for this day.',
    'notes_label': 'Notes: {}',
    'duration_label': 'Duration: {} seconds',
    'play_recording_btn': 'Play Recording',
    'stop_playback_btn': 'Stop Playback',
    'practice_history_title': 'Practice History',
    'secs_format': '{} secs',
    'mins_format': '{} mins',
    'sessions_on_date': 'Sessions on {}',
    'recorded_count_format': '{} recorded',
    'no_sessions_on_day': 'No practice sessions recorded on this day.',
    'technical_exercises_completed_title': 'Technical Exercises Completed:',
    'repertoire_rehearsed_title': 'Repertoire Rehearsed:',
    'spent_duration': 'Spent: {}',
    'practice_session_notes_title': 'Practice Session Notes:',
    'recorded_self_evaluation_title': 'Recorded Self-Evaluation Snippet',
    'playing_back_audio': 'Playing back audio...',
    'audio_attached': 'Audio recording attached',
    'log_past_session': 'Log Past Session',
    'manual_session_description':
        'Add practice completed earlier. Manually logged sessions never include an audio recording.',
    'session_date': 'Session date',
    'session_start_time': 'Start time',
    'duration_minutes': 'Duration',
    'minutes_short': 'min',
    'invalid_manual_duration': 'Enter a duration from 1 to 1,440 minutes.',
    'manual_session_future': 'The session must start and finish in the past.',
    'completed_exercises_optional': 'Completed exercises (optional)',
    'save_manual_session': 'Save Session',
    'manual_session_saved': 'Past practice session saved.',
    'manual_session_save_error':
        'The past practice session could not be saved.',
    // Notifications
    'session_saved': 'Practice session saved successfully!',
    'session_save_error':
        'The session could not be saved. Your practice remains open so you can retry.',
    'pdf_pick_error': 'The PDF could not be selected.',
    'pdf_web_unavailable':
        'PDF score attachments are available in the iOS and Android apps.',
    'pdf_viewer_web_unavailable':
        'PDF score viewing is not available in the browser version.',
    'recording_web_session_only':
        'Browser recordings are saved in this browser and remain available in your history.',
    'invalid_piece_values':
        'Enter a title, a BPM from 40 to 240, and measures from 0 to 10,000.',
    'piece_save_error': 'The repertoire piece could not be saved.',
    'piece_delete_error': 'The repertoire piece could not be deleted.',
    'delete_piece_title': 'Delete repertoire piece?',
    'delete_piece_confirm':
        'This removes the piece and its app-managed PDF. This cannot be undone.',
    'settings': 'Settings',
    'local_profile': 'Local profile',
    'local_only_data': 'Practice data is managed locally by the app.',
    'data_portability': 'DATA PORTABILITY',
    'export_journal': 'Export journal backup',
    'export_journal_subtitle':
        'Save routines and practice history without recordings or PDFs.',
    'import_journal': 'Import journal backup',
    'import_journal_subtitle':
        'Safely add routines and sessions from a backup file.',
    'backup_active_session':
        'Finish or discard the active practice session first.',
    'backup_exported': 'Journal backup exported successfully.',
    'backup_export_error': 'The journal backup could not be exported.',
    'backup_invalid': 'This file is not a valid or supported journal backup.',
    'backup_import_error':
        'The journal backup could not be imported. Existing data was preserved.',
    'backup_imported':
        'Added {} routines and {} sessions. Skipped {} existing records.',
    'import_preview_title': 'Review Journal Import',
    'backup_contains': 'Backup contents: {} routines and {} sessions.',
    'backup_will_add':
        'This device will add {} routines and {} sessions and skip {} existing records.',
    'backup_conflicts':
        '{} ID conflicts will be added as separate records without overwriting existing data.',
    'backup_exclusions':
        'Recordings, PDFs, repertoire files, and profile settings are not imported.',
    'import_add': 'Add to This Device',
    'privacy_policy': 'Privacy Policy',
    'terms_and_conditions': 'Terms and Conditions',
    'support': 'Support',
    'about': 'About',
    'erase_all_data': 'Erase all data',
    'erase_all_data_subtitle':
        'Permanently remove your profile, journal, PDFs, and recordings.',
    'erase_data_title': 'Erase all app data?',
    'erase_data_description':
        'This permanently deletes your profile, routines, repertoire, practice history, imported PDFs, and recordings. This cannot be undone.',
    'erase_data_action': 'Erase everything',
    'erase_data_error':
        'The app data could not be completely erased. Please try again.',
    'delete_session_title': 'Delete practice session?',
    'delete_session_confirm':
        'This permanently removes the session and its recording.',
    'session_delete_error': 'The practice session could not be deleted.',
    'audio_playback_error': 'This recording is missing or could not be played.',
    'clear_annotations': 'Clear annotations on this page',
    'annotations_temporary':
        'Annotations are temporary and apply only to this page.',
    'pdf_missing':
        'The PDF is missing. Reattach the score from your repertoire.',
    'pdf_load_error': 'The PDF could not be opened.',
    'pdf_page_error': 'Page {} could not be displayed.',
    'page_of': 'Page {} of {}',
    'tempo_label': 'TEMPO',
    'toggle_metronome': 'Toggle metronome',
    'invalid_routine_values': 'Enter a title of 100 characters or fewer.',
    'invalid_exercise_values':
        'Enter an exercise name and a BPM from 40 to 240.',
    'routine_save_error': 'The routine could not be saved.',
    'routine_delete_error': 'The routine could not be deleted.',
    'practice_preferences': 'Practice Preferences',
    'keep_screen_awake': 'Keep screen awake during practice',
    'keep_screen_awake_subtitle':
        'Prevents automatic screen lock only while a practice session is open.',
    'appearance_feedback': 'Appearance & feedback',
    'appearance_feedback_subtitle':
        'Shape the practice space around your attention and comfort.',
    'practice_visual_mode': 'Practice layout',
    'exercise_label': 'Exercise',
    'practice_visual_mode_subtitle':
        'Focused keeps one exercise in view; Full shows the complete workspace.',
    'focused_mode': 'Focused',
    'full_mode': 'Full workspace',
    'theme_mode': 'Theme',
    'theme_system': 'Use device setting',
    'theme_light': 'Light',
    'theme_dark': 'Dark',
    'haptics': 'Gentle touch feedback',
    'haptics_subtitle': 'A small cue when an exercise starts or completes.',
    'sound_cues': 'Sound cues',
    'sound_cues_subtitle': 'A soft optional cue for practice transitions.',
    'reduced_motion': 'Reduce motion',
    'reduced_motion_subtitle': 'Use calmer transitions and fewer animations.',
    'show_celebrations': 'Show encouraging completion cues',
    'show_celebrations_subtitle':
        'Keep progress feedback supportive and easy to turn off.',
    'preference_save_error': 'The preference could not be saved.',
    'invalid_weekly_goal': 'Enter a weekly goal from 1 to 10,080 minutes.',
    'enter_valid_name': 'Please enter a valid name',
    'enter_title_desc': 'Please enter a title and description',
    'enter_piece_details': 'Please fill out all piece details',
    'weekly_goal_target': '{}% of your weekly target accomplished!',
    'page_label': 'Page',
    'score_view': 'Navigation',
    'annotate_score': 'Annotate',
    'stop_metronome': 'Stop Metronome',
    'start_metronome': 'Start Metronome',
    'view_score_btn': 'View Score',
  };

  // --- SPANISH DICTIONARY ---
  static const Map<String, String> _es = {
    'app_title': 'Flute Practice Coach',
    'app_subtitle': 'Tu diario de práctica privado y enfocado',
    'local_profile_title': 'Configura tu perfil local',
    'local_profile_description':
        'La app administra localmente tu diario de práctica. No necesitas una cuenta ni conexión a internet.',
    'continue_local': 'Continuar',
    'profile_create_error':
        'No se pudo crear el perfil local. Inténtalo de nuevo.',
    'or_practice_offline': 'O PRÁCTICA EN MODO OFFLINE',
    'your_name': 'Tu Nombre',
    'practice_as_guest': 'Practicar como Invitado',
    'sign_out': 'Cerrar Sesión',
    'welcome_back': 'Bienvenido de nuevo,',
    'weekly_progress': 'Progreso de Práctica Semanal',
    'minutes': 'minutos',
    'streak_days': '{} Días de Racha Actual',
    'current_streak_title': 'Racha Actual',
    'total_sessions_title': 'Sesiones Totales',
    'exercises_done_title': 'Ejercicios Realizados',
    'total_study_time_title': 'Tiempo de Estudio',
    'days': 'Días',
    'update_goal_title': 'Actualizar Meta Semanal',
    'update_goal_desc':
        'Define cuántos minutos quieres estudiar por semana. Haremos un seguimiento automático.',
    'target_minutes': 'Minutos Objetivo',
    'save': 'Guardar',
    'no_routines_configured':
        'Aún no hay rutinas configuradas.\n¡Ve a la pestaña de Rutinas para crear una!',
    'technical_exercises_count': '{} ejercicios técnicos',
    'total_sessions': '{} Sesiones Totales',
    'exercises_done': '{} Ejercicios Realizados',
    'total_study_time': '{}m de Tiempo de Estudio',
    'quick_start': 'Rutinas de Inicio Rápido',
    'free_study': 'Estudio Libre',
    'dashboard_nav': 'Inicio',
    'active_practice_session': 'Sesión de Práctica Activa',
    'routine_label': 'Rutina: {}',
    'free_study_piece': 'Pieza de Estudio Libre',
    'routines': 'Rutinas',
    'repertoire': 'Repertorio',
    'history': 'Historial',
    // Active Practice View
    'free_repertoire_study': 'Estudio Libre de Repertorio',
    'study_clock_running': 'RELOJ DE ESTUDIO CORRIENDO',
    'study_clock_paused': 'RELOJ DE ESTUDIO PAUSADO',
    'pause': 'Pausar',
    'resume': 'Reanudar',
    'finish': 'Terminar',
    'repertoire_tracking': 'Seguimiento de Pieza Activa de Repertorio',
    'repertoire_tracking_subtitle':
        'Selecciona la partitura en la que estás trabajando para acumular tiempo directamente.',
    'none_technical_only': 'Ninguna (Solo Ejercicios Técnicos)',
    'visual_metronome': 'Metrónomo',
    'tempo': 'Tempo: {} BPM',
    'decrease_tempo': 'Reducir el tempo en 1 BPM',
    'increase_tempo': 'Aumentar el tempo en 1 BPM',
    'metronome_sound': 'Sonido del metrónomo',
    'enable_metronome_sound': 'Activar sonido del metrónomo',
    'mute_metronome': 'Silenciar sonido del metrónomo',
    'metronome_sound_suppressed':
        'El sonido se silencia durante la grabación o reproducción.',
    'tuner': 'Afinador',
    'tuner_subtitle':
        'Afina libremente o mide tu afinación durante un ejercicio.',
    'show_tuner': 'Mostrar afinador',
    'hide_tuner': 'Ocultar afinador y dejar de escuchar',
    'decrease_tuner_reference': 'Bajar la referencia de La4 en 1 Hz',
    'increase_tuner_reference': 'Subir la referencia de La4 en 1 Hz',
    'pitch_tolerance': 'Tolerancia de afinación',
    'play_a_note': 'Toca una nota estable',
    'waiting_for_stable_pitch': 'Esperando una nota estable…',
    'on_pitch_live': '{}% afinado • {} analizado',
    'track_my_pitch': 'Medir mi afinación',
    'tune_now': 'Afinar',
    'stop_pitch_tracking': 'Detener medición',
    'stop_listening': 'Dejar de escuchar',
    'tuner_mic_error':
        'El micrófono no está disponible. Detén la grabadora y revisa el permiso del micrófono.',
    'tuner_headphones_hint':
        'Los audífonos mejoran la precisión mientras suena el metrónomo.',
    'self_recorder': 'Grabadora de Autoevaluación',
    'self_recorder_subtitle':
        'Graba un fragmento, ejecútalo y escucha tu tono y articulación.',
    'open_self_recorder': 'Abrir Grabadora',
    'close_recorder': 'Cerrar Grabadora',
    'recording_paused': 'Grabación Pausada',
    'recording_stopped': 'Grabación Detenida',
    'recording_playing': 'Reproduciendo Grabación',
    'recording_active': 'GRABANDO AUDIO...',
    'mic_error': 'Permiso de micrófono denegado o grabadora no inicializada.',
    // Finish Dialog
    'finish_session_title': '¿Terminar Sesión de Práctica?',
    'finish_session_subtitle':
        'Revisa tus notas de práctica antes de guardar. Los detalles de la sesión y las grabaciones se guardarán en tu historial.',
    'finish_session_subtitle_web':
        'Revisa tus notas antes de guardar. Los detalles y las grabaciones del navegador se guardan en el historial de este navegador.',
    'practice_notes': 'Notas de Práctica',
    'exercise_notes_draft_title': 'Ejercicios trabajados:',
    'exercise_notes_draft_item': '• {} — {} BPM',
    'exercise_notes_draft_item_pitch':
        '• {} — {} BPM — {}% afinado (La4 {} Hz, ±{}¢)',
    'keep_practicing': 'Seguir Practicando',
    'save_finish': 'Guardar y Finalizar',
    'exit_practice_title': '¿Salir de la Práctica?',
    'exit_practice_desc':
        '¿Deseas descartar tu progreso actual o seguir estudiando?',
    'discard_session_btn': 'Descartar Sesión',
    'select_active_sheet': 'Seleccionar partitura activa',
    'exercises_for_routine': 'Ejercicios para: {}',
    'start_exercise': 'Iniciar',
    'resume_exercise': 'Repetir',
    'stop_exercise': 'Detener',
    'exercise_elapsed': 'Ejercicio: {}',
    'practiced_tempo': '{} BPM practicados',
    'exercise_result_format': '{} • {} • {} BPM',
    'exercise_result_with_pitch_format':
        '{} • {} • {} BPM • {}% afinado • {} analizado • La4 {} Hz • ±{}¢',
    'exercise_tempo_save_error':
        'No se pudo guardar el tempo de la rutina. Se restauró el tempo anterior.',
    'recording_audio': 'Grabando audio...',
    'recording_saved_temp': 'Grabación guardada en este dispositivo',
    'recording_count_format': '{} grabaciones guardadas en esta sesión',
    'recording_take_number': 'Toma {}',
    'recording_library': 'Biblioteca de grabaciones',
    'recording_library_subtitle':
        'Escucha, cambia el nombre o elimina grabaciones de sesiones guardadas.',
    'recording_library_empty': 'Aún no hay grabaciones guardadas.',
    'recording_actions': 'Acciones de grabación',
    'rename_recording': 'Cambiar nombre',
    'rename_recording_title': 'Cambiar nombre de la grabación',
    'recording_name_label': 'Nombre de la grabación',
    'delete_recording_title': '¿Eliminar grabación?',
    'delete_recording_confirm': '¿Eliminar "{}"? Esto no se puede deshacer.',
    'recording_rename_error': 'No se pudo guardar el nombre de la grabación.',
    'recording_delete_error': 'No se pudo eliminar la grabación.',
    'start_recording': 'Iniciar grabación',
    'stop_recording': 'Detener grabación',
    'delete_recording': 'Eliminar grabación',
    'mic_ready': 'Micrófono Listo',
    // Routines View
    'routines_title': 'Rutinas de Estudio Técnico',
    'routines_subtitle':
        'Estructura tus ejercicios de respiración diarios, notas largas y guías de articulación.',
    'add_routine': 'Crear Rutina Personalizada',
    'routines_tab_title': 'Rutinas de Estudio',
    'new_routine_title': 'Nueva Rutina de Estudio',
    'create_btn': 'Crear',
    'add_exercise_to': 'Añadir Ejercicio a {}',
    'edit_exercise_title': 'Editar Ejercicio en {}',
    'edit_exercise': 'Editar ejercicio',
    'reorder_exercise': 'Reordenar ejercicio',
    'reorder_exercises_hint':
        'Arrastra el control para reordenar los ejercicios.',
    'target_bpm_tempo': 'BPM Objetivo (Tempo)',
    'add_btn': 'Añadir',
    'no_routines_configured_empty': 'No hay rutinas de estudio configuradas.',
    'click_add_routine':
        'Haz clic en el botón "+" en la parte superior derecha para crear tu primera rutina.',
    'technical_exercises_default': 'Ejercicios técnicos',
    'technical_checklist': 'Lista de Ejercicios',
    'no_exercises_added': 'Aún no se han añadido ejercicios.',
    'exercise_detail_format': '{} • Objetivo: {} BPM',
    'delete_routine_title': '¿Eliminar Rutina?',
    'delete_routine_confirm':
        '¿Estás seguro de que deseas eliminar "{}"? Esto no se puede deshacer.',
    'delete_btn': 'Eliminar',
    'routine_title_label': 'Título de la Rutina',
    'routine_desc_label': 'Descripción',
    'exercises_list': 'Ejercicios',
    'add_exercise': 'Añadir Ejercicio',
    'exercise_name_label': 'Nombre del Ejercicio',
    'articulation_label': 'Articulación',
    'target_bpm_label': 'BPM Objetivo',
    'save_routine': 'Guardar Rutina',
    'cancel': 'Cancelar',
    // Repertoire View
    'repertoire_title': 'Mi Carpeta de Repertorio',
    'repertoire_subtitle':
        'Lleva un registro de tus partituras, compases dominados y tempos de metrónomo.',
    'add_piece': 'Añadir Pieza de Repertorio',
    'repertoire_manager_title': 'Gestor de Repertorio',
    'title_label': 'Título',
    'total_measures': 'Compases Totales',
    'study_focus_notes': 'Notas de Enfoque',
    'no_pdf_attached': 'Sin partitura PDF adjunta',
    'change_btn': 'Cambiar',
    'browse_btn': 'Buscar',
    'composer_format': 'Compositor: {}',
    'target_tempo_format': 'Tempo Objetivo: {} BPM',
    'score_sheet_format': 'Partitura: {}',
    'measures_progress_format': 'Progreso de Compases: {} / {}',
    'focus_notes_label': 'Notas de Enfoque:',
    'no_focus_notes': 'Sin notas de enfoque.',
    'save_progress_btn': 'Guardar Progreso',
    'repertoire_empty_title': 'Tu carpeta de repertorio está vacía.',
    'repertoire_empty_desc':
        'Haz clic en el botón "+" en la parte superior derecha para catalogar una pieza musical y hacer un seguimiento de tu progreso.',
    'unknown': 'Desconocido',
    'meas_count_format': '{} / {} comp.',
    'piece_title_label': 'Título de la Pieza',
    'composer_label': 'Compositor',
    'measures_total': 'Compases Totales',
    'measures_completed': 'Compases Completados',
    'study_notes': 'Notas de Estudio',
    'save_piece': 'Guardar Pieza',
    'progress_percent': '{}% completado',
    // History View
    'history_title': 'Historial de Práctica y Calendario',
    'history_subtitle':
        'Lleva un registro de tu mapa de calor de dedicación y reproduce grabaciones.',
    'session_details': 'Detalles de la Sesión',
    'no_sessions_day': 'No se registraron sesiones de práctica para este día.',
    'notes_label': 'Notas: {}',
    'duration_label': 'Duración: {} segundos',
    'play_recording_btn': 'Reproducir Grabación',
    'stop_playback_btn': 'Detener Reproducción',
    'practice_history_title': 'Historial de Práctica',
    'secs_format': '{} segs',
    'mins_format': '{} mins',
    'sessions_on_date': 'Sesiones el {}',
    'recorded_count_format': '{} registradas',
    'no_sessions_on_day': 'No se registraron sesiones de práctica en este día.',
    'technical_exercises_completed_title': 'Ejercicios Técnicos Completados:',
    'repertoire_rehearsed_title': 'Repertorio Ensayado:',
    'spent_duration': 'Tiempo: {}',
    'practice_session_notes_title': 'Notas de la Sesión de Práctica:',
    'recorded_self_evaluation_title': 'Fragmento de Autoevaluación Grabado',
    'playing_back_audio': 'Reproduciendo audio...',
    'audio_attached': 'Grabación de audio adjunta',
    'log_past_session': 'Registrar Sesión Pasada',
    'manual_session_description':
        'Añade una práctica realizada anteriormente. Las sesiones manuales nunca incluyen grabaciones de audio.',
    'session_date': 'Fecha de la sesión',
    'session_start_time': 'Hora de inicio',
    'duration_minutes': 'Duración',
    'minutes_short': 'min',
    'invalid_manual_duration': 'Ingresa una duración entre 1 y 1.440 minutos.',
    'manual_session_future': 'La sesión debe comenzar y terminar en el pasado.',
    'completed_exercises_optional': 'Ejercicios completados (opcional)',
    'save_manual_session': 'Guardar Sesión',
    'manual_session_saved': 'Sesión de práctica pasada guardada.',
    'manual_session_save_error':
        'No se pudo guardar la sesión de práctica pasada.',
    // Notifications
    'session_saved': '¡Sesión de práctica guardada correctamente!',
    'session_save_error':
        'No se pudo guardar la sesión. Tu práctica permanece abierta para que puedas intentarlo de nuevo.',
    'pdf_pick_error': 'No se pudo seleccionar el PDF.',
    'pdf_web_unavailable':
        'Los archivos PDF están disponibles en las apps para iOS y Android.',
    'pdf_viewer_web_unavailable':
        'La visualización de PDF no está disponible en la versión web.',
    'recording_web_session_only':
        'Las grabaciones del navegador se guardan en este navegador y siguen disponibles en tu historial.',
    'invalid_piece_values':
        'Ingresa un título, un BPM entre 40 y 240 y compases entre 0 y 10.000.',
    'piece_save_error': 'No se pudo guardar la pieza del repertorio.',
    'piece_delete_error': 'No se pudo eliminar la pieza del repertorio.',
    'delete_piece_title': '¿Eliminar pieza del repertorio?',
    'delete_piece_confirm':
        'Esto elimina la pieza y su PDF administrado por la app. No se puede deshacer.',
    'settings': 'Ajustes',
    'local_profile': 'Perfil local',
    'local_only_data': 'La app administra localmente los datos de práctica.',
    'data_portability': 'PORTABILIDAD DE DATOS',
    'export_journal': 'Exportar copia del diario',
    'export_journal_subtitle':
        'Guarda rutinas e historial sin grabaciones ni archivos PDF.',
    'import_journal': 'Importar copia del diario',
    'import_journal_subtitle':
        'Añade rutinas y sesiones de forma segura desde una copia.',
    'backup_active_session':
        'Finaliza o descarta primero la sesión de práctica activa.',
    'backup_exported': 'La copia del diario se exportó correctamente.',
    'backup_export_error': 'No se pudo exportar la copia del diario.',
    'backup_invalid':
        'El archivo no es una copia válida o compatible del diario.',
    'backup_import_error':
        'No se pudo importar la copia. Los datos existentes se conservaron.',
    'backup_imported':
        'Se añadieron {} rutinas y {} sesiones. Se omitieron {} registros existentes.',
    'import_preview_title': 'Revisar Importación del Diario',
    'backup_contains': 'La copia contiene {} rutinas y {} sesiones.',
    'backup_will_add':
        'Se añadirán {} rutinas y {} sesiones y se omitirán {} registros existentes.',
    'backup_conflicts':
        '{} conflictos de ID se añadirán como registros separados sin sobrescribir datos.',
    'backup_exclusions':
        'No se importan grabaciones, archivos PDF, partituras ni ajustes del perfil.',
    'import_add': 'Añadir a Este Dispositivo',
    'privacy_policy': 'Política de Privacidad',
    'terms_and_conditions': 'Términos y Condiciones',
    'support': 'Soporte',
    'about': 'Acerca de',
    'erase_all_data': 'Borrar todos los datos',
    'erase_all_data_subtitle':
        'Elimina permanentemente tu perfil, diario, archivos PDF y grabaciones.',
    'erase_data_title': '¿Borrar todos los datos de la app?',
    'erase_data_description':
        'Esto elimina permanentemente tu perfil, rutinas, repertorio, historial, archivos PDF y grabaciones. No se puede deshacer.',
    'erase_data_action': 'Borrar todo',
    'erase_data_error':
        'No se pudieron borrar todos los datos. Inténtalo de nuevo.',
    'delete_session_title': '¿Eliminar sesión de práctica?',
    'delete_session_confirm':
        'Esto elimina permanentemente la sesión y su grabación.',
    'session_delete_error': 'No se pudo eliminar la sesión de práctica.',
    'audio_playback_error': 'La grabación no existe o no se pudo reproducir.',
    'clear_annotations': 'Borrar anotaciones de esta página',
    'annotations_temporary':
        'Las anotaciones son temporales y solo se aplican a esta página.',
    'pdf_missing':
        'El PDF no está disponible. Vuelve a adjuntar la partitura desde el repertorio.',
    'pdf_load_error': 'No se pudo abrir el PDF.',
    'pdf_page_error': 'No se pudo mostrar la página {}.',
    'page_of': 'Página {} de {}',
    'tempo_label': 'TEMPO',
    'toggle_metronome': 'Activar o desactivar metrónomo',
    'invalid_routine_values': 'Ingresa un título de máximo 100 caracteres.',
    'invalid_exercise_values': 'Ingresa un nombre y un BPM entre 40 y 240.',
    'routine_save_error': 'No se pudo guardar la rutina.',
    'routine_delete_error': 'No se pudo eliminar la rutina.',
    'practice_preferences': 'Preferencias de Práctica',
    'keep_screen_awake': 'Mantener la pantalla activa durante la práctica',
    'keep_screen_awake_subtitle':
        'Evita el bloqueo automático solo mientras haya una sesión de práctica abierta.',
    'appearance_feedback': 'Apariencia y feedback',
    'appearance_feedback_subtitle':
        'Adapta el espacio de práctica a tu atención y comodidad.',
    'practice_visual_mode': 'Diseño de práctica',
    'exercise_label': 'Ejercicio',
    'practice_visual_mode_subtitle':
        'Enfocado muestra un ejercicio; Completo muestra todo el espacio.',
    'focused_mode': 'Enfocado',
    'full_mode': 'Espacio completo',
    'theme_mode': 'Tema',
    'theme_system': 'Usar ajuste del dispositivo',
    'theme_light': 'Claro',
    'theme_dark': 'Oscuro',
    'haptics': 'Feedback táctil suave',
    'haptics_subtitle': 'Una señal breve al iniciar o completar un ejercicio.',
    'sound_cues': 'Señales de sonido',
    'sound_cues_subtitle':
        'Una señal suave opcional para los cambios de práctica.',
    'reduced_motion': 'Reducir movimiento',
    'reduced_motion_subtitle':
        'Usa transiciones más tranquilas y menos animaciones.',
    'show_celebrations': 'Mostrar señales de finalización',
    'show_celebrations_subtitle':
        'Mantén el feedback de progreso amable y fácil de desactivar.',
    'preference_save_error': 'No se pudo guardar la preferencia.',
    'invalid_weekly_goal': 'Ingresa una meta semanal entre 1 y 10.080 minutos.',
    'enter_valid_name': 'Por favor ingresa un nombre válido',
    'enter_title_desc': 'Por favor ingresa un título y una descripción',
    'enter_piece_details': 'Por favor completa todos los detalles de la pieza',
    'weekly_goal_target': '¡{}% de tu objetivo semanal cumplido!',
    'page_label': 'Página',
    'score_view': 'Navegación',
    'annotate_score': 'Anotar',
    'stop_metronome': 'Detener Metrónomo',
    'start_metronome': 'Iniciar Metrónomo',
    'view_score_btn': 'Ver Partitura',
  };
}

extension LocalizationExtension on BuildContext {
  String translate(String key, [List<String>? args]) {
    return Provider.of<LocalizationProvider>(
      this,
      listen: false,
    ).translate(key, args);
  }
}
