import '../models/score_view_preferences.dart';
import 'database_service.dart';

abstract class ScoreViewPreferencesRepository {
  Future<ScoreViewPreferences> load({
    required String pieceId,
    required String sourcePath,
  });

  Future<void> save(ScoreViewPreferences preferences);
  Future<void> delete(String pieceId);
}

class ScoreViewPreferencesService implements ScoreViewPreferencesRepository {
  final DatabaseService _database;

  ScoreViewPreferencesService({DatabaseService? database})
    : _database = database ?? DatabaseService();

  @override
  Future<ScoreViewPreferences> load({
    required String pieceId,
    required String sourcePath,
  }) async {
    final stored = _database.getScoreViewPreferences(pieceId);
    if (stored == null || stored.sourcePath != sourcePath) {
      if (stored != null) await delete(pieceId);
      return ScoreViewPreferences.defaults(
        pieceId: pieceId,
        sourcePath: sourcePath,
      );
    }
    return stored;
  }

  @override
  Future<void> save(ScoreViewPreferences preferences) =>
      _database.saveScoreViewPreferences(preferences);

  @override
  Future<void> delete(String pieceId) =>
      _database.deleteScoreViewPreferences(pieceId);
}
