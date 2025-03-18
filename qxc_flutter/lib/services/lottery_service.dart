import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:qxc_flutter/services/database_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

class LotteryService {
  static final LotteryService instance = LotteryService._init();
  final DatabaseService _db = DatabaseService();
  final Dio _dio = Dio();
  final String _baseUrl = 'https://webapi.sporttery.cn/gateway/lottery';

  LotteryService._init() {
    // 配置 dio
    _dio.options.headers = {
      'accept': 'application/json, text/javascript, */*; q=0.01',
      'accept-language': 'zh-CN,zh;q=0.9,vi;q=0.8,en;q=0.7',
      'origin': 'https://static.sporttery.cn',
      'referer': 'https://static.sporttery.cn/',
      'user-agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36'
    };
  }

  Future<List<Map<String, dynamic>>> syncData() async {
    try {
      print('Starting lottery data synchronization...');

      // 获取最新一期的开奖号码
      final response = await _dio.get(
        '$_baseUrl/getHistoryPageListV1.qry',
        queryParameters: {
          'gameNo': '04', // 七星彩
          'provinceId': '0',
          'pageSize': '30',
          'isVerify': '1',
          'pageNo': '1',
        },
      );

      print('API Response: ${response.data}'); // 添加响应数据日志

      if (response.statusCode != 200) {
        throw Exception(
            'Network request failed with status: ${response.statusCode}');
      }

      final data = response.data;
      if (data == null ||
          data['value'] == null ||
          data['value']['list'] == null) {
        throw Exception('Invalid response format');
      }

      final List<dynamic> draws = data['value']['list'];
      print('Received ${draws.length} records from network');

      if (draws.isEmpty) {
        print('No new data received from network');
        return [];
      }

      // 验证是否为七星彩数据
      final firstDraw = draws.first;
      print('First draw data: $firstDraw');
      final gameName = firstDraw['lotteryGameName']?.toString() ?? '';
      final gameNum = firstDraw['lotteryGameNum']?.toString() ?? '';
      if (gameNum != '04' || !gameName.contains('星彩')) {
        throw Exception(
            'Invalid lottery type: Expected Qixingcai (gameNo: 04), got: $gameName (gameNo: $gameNum)');
      }

      // 开始批量插入
      print('Starting batch commit...');
      int newRecords = 0;
      int updatedRecords = 0;
      final db = await _db.database;
      final batch = db.batch();

      for (var draw in draws) {
        final drawNum = draw['lotteryDrawNum'].toString();
        final drawDate = draw['lotteryDrawTime'];
        final rawNumbers = draw['lotteryDrawResult'].toString();

        // 将号码字符串转换为单个数字的数组
        final numbersList = rawNumbers.split(' ');
        if (numbersList.length != 7) {
          print('警告: 开奖号码数量不正确，期号: $drawNum, 原始号码: $rawNumbers');
          continue;
        }

        // 将数字数组重新组合为带空格的字符串
        final numbers = numbersList.join(' ');

        // 检查记录是否已存在
        final existing = await db.query(
          'lottery_results',
          where: 'draw_number = ?',
          whereArgs: [drawNum],
        );

        if (existing.isEmpty) {
          batch.insert('lottery_results', {
            'draw_number': drawNum,
            'draw_date': drawDate,
            'numbers': numbers,
          });
          newRecords++;
        } else {
          batch.update(
            'lottery_results',
            {
              'draw_date': drawDate,
              'numbers': numbers,
            },
            where: 'draw_number = ?',
            whereArgs: [drawNum],
          );
          updatedRecords++;
        }
      }

      await batch.commit();
      print(
          'Sync completed: $newRecords new records, $updatedRecords updated records');

      // 获取所有记录
      final allRecords =
          await db.query('lottery_results', orderBy: 'draw_number DESC');
      print('Total records in database: ${allRecords.length}');

      return allRecords;
    } catch (e) {
      print('Error during data synchronization: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getLatestDraw() async {
    try {
      final db = await _db.database;
      final result = await db.query(
        'lottery_results',
        orderBy: 'draw_number DESC',
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error getting latest draw: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getRecentDraws({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final db = await _db.database;
      return await db.query(
        'lottery_results',
        orderBy: 'draw_number DESC',
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      print('Error getting recent draws: $e');
      return [];
    }
  }

  Future<void> savePrediction({
    required String drawNumber,
    required String predictedNumbers,
    required double confidenceScore,
  }) async {
    try {
      final db = await _db.database;
      await db.insert(
        'predictions',
        {
          'draw_number': drawNumber,
          'predicted_numbers': predictedNumbers,
          'confidence_score': confidenceScore,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error saving prediction: $e');
      rethrow;
    }
  }

  Future<void> importCsvData({
    void Function(double progress, String message)? onProgress,
  }) async {
    try {
      // 检查是否已经导入过数据
      final db = await _db.database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM lottery_results'),
      );

      if (count != null && count > 0) {
        print('CSV data already imported, existing records: $count');
        onProgress?.call(1.0, '数据已存在，跳过导入');
        return;
      }

      // 读取CSV文件
      print('Starting to read CSV file...');
      onProgress?.call(0.1, '正在读取CSV文件...');
      final String csvData =
          await rootBundle.loadString('assets/lottery_history.csv');
      final List<String> rows = csvData.split('\n');
      final int totalRows = rows.length - 1; // 减去标题行
      print('CSV file read successfully, total rows: $totalRows');
      onProgress?.call(0.2, '文件读取完成，开始导入数据...');

      // 开始批量插入
      final batch = db.batch();
      int processedRows = 0;
      int validRows = 0;

      // 跳过标题行
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i].trim();
        if (row.isEmpty) {
          print('Skipping empty row at line $i');
          continue;
        }

        final columns = row.split(',');
        if (columns.length < 3) {
          print('Invalid row at line $i: insufficient columns');
          continue;
        }

        batch.insert(
          'lottery_results',
          {
            'draw_number': columns[0].trim(),
            'draw_date': columns[1].trim(),
            'numbers': columns[2].trim(),
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        validRows++;

        // 每处理100行更新一次进度
        processedRows++;
        if (processedRows % 100 == 0) {
          final progress = 0.2 + (0.8 * processedRows / totalRows);
          print('Processed $processedRows/$totalRows rows');
          onProgress?.call(progress, '正在导入数据: $processedRows/$totalRows');
        }
      }

      print('Starting batch commit...');
      onProgress?.call(0.9, '正在保存数据...');
      await batch.commit();

      final finalCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM lottery_results'),
      );
      print(
          'CSV data import completed. Valid rows: $validRows, Final DB count: $finalCount');
      onProgress?.call(1.0, '数据导入完成，共导入 $validRows 条记录');
    } catch (e) {
      print('Error importing CSV data: $e');
      onProgress?.call(0.0, '数据导入失败: $e');
      rethrow;
    }
  }
}
