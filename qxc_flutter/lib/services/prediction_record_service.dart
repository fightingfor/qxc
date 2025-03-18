import 'package:sqflite/sqflite.dart';
import '../models/prediction_record.dart';
import '../services/database_service.dart';

class PredictionRecordService {
  static const String _tableName = 'prediction_records';
  final DatabaseService _db = DatabaseService();

  // 添加预测记录
  Future<int> addPrediction(PredictionRecord record) async {
    final db = await _db.database;
    return await db.insert(
      _tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 获取所有预测记录
  Future<List<PredictionRecord>> getAllPredictions() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'prediction_time DESC',
    );
    return List.generate(maps.length, (i) => PredictionRecord.fromMap(maps[i]));
  }

  // 更新收藏状态
  Future<int> updateFavoriteStatus(int id, List<bool> favoritedStatus) async {
    final db = await _db.database;
    return await db.update(
      _tableName,
      {'favorited_status': favoritedStatus.toString()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 删除预测记录
  Future<int> deletePrediction(int id) async {
    final db = await _db.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 根据期号查找预测记录
  Future<PredictionRecord?> findByDrawNumber(String drawNumber) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'draw_number = ?',
      whereArgs: [drawNumber],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PredictionRecord.fromMap(maps.first);
  }

  // 获取最新的预测记录
  Future<PredictionRecord?> getLatestPrediction() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'prediction_time DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PredictionRecord.fromMap(maps.first);
  }
}
