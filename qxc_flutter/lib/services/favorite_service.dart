import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/favorite_model.dart';

class FavoriteService {
  static const String _tableName = 'favorites';
  static Database? _database;

  // 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 初始化数据库
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'favorites.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            draw_number TEXT NOT NULL,
            numbers TEXT NOT NULL,
            confidence REAL NOT NULL,
            favorite_time INTEGER NOT NULL,
            is_drawn INTEGER NOT NULL DEFAULT 0,
            drawn_numbers TEXT,
            match_count INTEGER,
            prize_level INTEGER,
            prize_amount REAL
          )
        ''');
      },
    );
  }

  // 添加收藏
  Future<int> addFavorite(FavoriteNumber favorite) async {
    final db = await database;
    return await db.insert(
      _tableName,
      favorite.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // 删除收藏
  Future<int> deleteFavorite(int id) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 获取所有收藏
  Future<List<FavoriteNumber>> getAllFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'favorite_time DESC',
    );
    return List.generate(maps.length, (i) => FavoriteNumber.fromMap(maps[i]));
  }

  // 更新开奖结果
  Future<int> updateDrawResult(
      int id, List<int> drawnNumbers, int matchCount, int prizeLevel,
      [double? prizeAmount]) async {
    final db = await database;
    return await db.update(
      _tableName,
      {
        'is_drawn': 1,
        'drawn_numbers': drawnNumbers.toString(),
        'match_count': matchCount,
        'prize_level': prizeLevel,
        'prize_amount': prizeAmount,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 根据期号查找收藏
  Future<FavoriteNumber?> findByDrawNumber(String drawNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'draw_number = ?',
      whereArgs: [drawNumber],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return FavoriteNumber.fromMap(maps.first);
  }

  // 检查是否已收藏
  Future<bool> isFavorited(String drawNumber) async {
    final favorite = await findByDrawNumber(drawNumber);
    return favorite != null;
  }

  // 获取未开奖的收藏
  Future<List<FavoriteNumber>> getUndrawnFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'is_drawn = ?',
      whereArgs: [0],
      orderBy: 'favorite_time DESC',
    );
    return List.generate(maps.length, (i) => FavoriteNumber.fromMap(maps[i]));
  }

  // 获取已开奖的收藏
  Future<List<FavoriteNumber>> getDrawnFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'is_drawn = ?',
      whereArgs: [1],
      orderBy: 'favorite_time DESC',
    );
    return List.generate(maps.length, (i) => FavoriteNumber.fromMap(maps[i]));
  }
}
