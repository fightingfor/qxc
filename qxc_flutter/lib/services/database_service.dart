import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  factory DatabaseService() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lottery.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE lottery_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        draw_number TEXT NOT NULL UNIQUE,
        draw_date TEXT NOT NULL,
        numbers TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE prediction_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        draw_number TEXT NOT NULL,
        prediction_time INTEGER NOT NULL,
        predictions TEXT NOT NULL,
        confidences TEXT NOT NULL,
        combinations TEXT NOT NULL,
        favorited_status TEXT NOT NULL DEFAULT '[]',
        draw_result TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 添加 favorited_status 列
      await db.execute('''
        ALTER TABLE prediction_records ADD COLUMN favorited_status TEXT NOT NULL DEFAULT '[]'
      ''');
    }

    if (oldVersion < 3) {
      // 备份旧表
      await db.execute(
          'ALTER TABLE prediction_records RENAME TO prediction_records_old');

      // 创建新表
      await db.execute('''
        CREATE TABLE prediction_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          draw_number TEXT NOT NULL,
          prediction_time INTEGER NOT NULL,
          predictions TEXT NOT NULL,
          confidences TEXT NOT NULL,
          combinations TEXT NOT NULL,
          favorited_status TEXT NOT NULL DEFAULT '[]',
          draw_result TEXT,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // 迁移数据
      await db.execute('''
        INSERT INTO prediction_records (
          id, draw_number, prediction_time, predictions, confidences, 
          combinations, favorited_status, created_at
        )
        SELECT 
          id, draw_number, 
          CAST(strftime('%s', created_at) AS INTEGER) * 1000, -- 转换为毫秒时间戳
          CASE 
            WHEN predictions IS NULL OR predictions = '{}'
            THEN json_object(
              'position1', json_array(0, 0, 0),
              'position2', json_array(0, 0, 0),
              'position3', json_array(0, 0, 0),
              'position4', json_array(0, 0, 0),
              'position5', json_array(0, 0, 0),
              'position6', json_array(0, 0, 0),
              'position7', json_array(0, 0, 0)
            )
            ELSE predictions
          END AS predictions,
          CASE 
            WHEN confidences IS NULL OR confidences = '{}'
            THEN json_object(
              'position1', 0.0,
              'position2', 0.0,
              'position3', 0.0,
              'position4', 0.0,
              'position5', 0.0,
              'position6', 0.0,
              'position7', 0.0
            )
            ELSE confidences
          END AS confidences,
          combinations,
          favorited_status,
          created_at
        FROM prediction_records_old
      ''');

      // 删除旧表
      await db.execute('DROP TABLE prediction_records_old');
    }
  }

  // 添加缺失的方法
  Future<Batch> batch() async {
    final db = await database;
    return db.batch();
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<void> initialize() async {
    await database;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
