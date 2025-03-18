import 'dart:math';
import 'dart:async';
import 'package:qxc_flutter/services/lottery_service.dart';

class PredictionService {
  static final PredictionService instance = PredictionService._init();
  final LotteryService _lotteryService = LotteryService.instance;
  final Random _random = Random();

  // 分层数据配置
  static const int RECENT_DATA_RANGE = 100; // 最近数据（高权重）
  static const int MEDIUM_DATA_RANGE = 500; // 中期数据（中等权重）
  static const int FULL_DATA_RANGE = 3000; // 全量数据（低权重）
  static const int SAME_PERIOD_YEARS = 5; // 同期分析年数

  // 权重配置
  static const double RECENT_WEIGHT = 0.5; // 最近数据权重
  static const double MEDIUM_WEIGHT = 0.3; // 中期数据权重
  static const double FULL_WEIGHT = 0.2; // 全量数据权重

  // 特征数据存储
  final Map<String, Map<String, Map<String, dynamic>>> _layerFeatures = {
    'recent': {},
    'medium': {},
    'full': {},
  };

  final Map<String, double> _layerWeights = {
    'recent': RECENT_WEIGHT,
    'medium': MEDIUM_WEIGHT,
    'full': FULL_WEIGHT,
  };

  // 基础特征数据
  Map<String, Map<String, dynamic>> _positionFeatures = {};
  Map<String, Map<String, dynamic>> _correlationData = {};
  Map<String, Map<String, dynamic>> _timeSeriesData = {};
  Map<String, Map<String, dynamic>> _periodicityData = {};
  Map<String, Map<String, dynamic>> _combinationPatterns = {};
  Map<String, Map<String, dynamic>> _historicalPatterns = {};

  PredictionService._init();

  Future<void> calculateFeatures() async {
    // 获取分层数据
    final recentDraws =
        await _lotteryService.getRecentDraws(limit: RECENT_DATA_RANGE);
    final mediumDraws =
        await _lotteryService.getRecentDraws(limit: MEDIUM_DATA_RANGE);
    final fullDraws =
        await _lotteryService.getRecentDraws(limit: FULL_DATA_RANGE);

    if (recentDraws.isEmpty) return;

    // 初始化特征存储
    _initializeFeatureStorage();

    // 分层计算特征
    await Future.wait([
      _calculateLayerFeatures(recentDraws, 'recent'),
      _calculateLayerFeatures(mediumDraws, 'medium'),
      _calculateLayerFeatures(fullDraws, 'full'),
    ]);

    // 合并特征
    _mergeLayerFeatures();
  }

  void _initializeFeatureStorage() {
    for (var layer in ['recent', 'medium', 'full']) {
      _layerFeatures[layer]?.clear();
      for (int i = 0; i < 7; i++) {
        final position = 'position${i + 1}';
        _layerFeatures[layer]![position] = {
          'frequency': <int, double>{},
          'missingValues': <int, int>{},
          'repeats': <int, int>{},
          'bigSmallRatio': {'big': 0.0, 'small': 0.0},
          'oddEvenRatio': {'odd': 0.0, 'even': 0.0},
          '012way': {'way0': 0.0, 'way1': 0.0, 'way2': 0.0},
          'spanValues': <int, double>{},
          'samePeriodPattern': <int, double>{},
          'seasonalPattern': <int, double>{},
          'monthlyPattern': <int, double>{},
          'weekdayPattern': <int, double>{},
        };
      }
    }

    _positionFeatures.clear();
    for (int i = 0; i < 7; i++) {
      final position = 'position${i + 1}';
      _positionFeatures[position] = {
        'frequency': <int, double>{},
        'missingValues': <int, int>{},
        'repeats': <int, int>{},
        'bigSmallRatio': {'big': 0.0, 'small': 0.0},
        'oddEvenRatio': {'odd': 0.0, 'even': 0.0},
        '012way': {'way0': 0.0, 'way1': 0.0, 'way2': 0.0},
        'spanValues': <int, double>{},
        'samePeriodPattern': <int, double>{},
        'seasonalPattern': <int, double>{},
        'monthlyPattern': <int, double>{},
        'weekdayPattern': <int, double>{},
      };
    }
  }

  Future<void> _calculateLayerFeatures(
    List<Map<String, dynamic>> draws,
    String layer,
  ) async {
    _calculateFrequency(draws, layer);
    _calculateMissingValues(draws, layer);
    _calculateRepeats(draws, layer);
    _calculateRatios(draws, layer);
    _calculate012Way(draws, layer);
    _calculateSpanValues(draws, layer);
    await _calculateHistoricalPatterns(draws, layer);
    _calculateCorrelations(draws, layer);
    _calculateTimeSeries(draws, layer);
    _calculatePeriodicity(draws, layer);
    _calculateCombinationPatterns(draws, layer);
  }

  void _calculateFrequency(List<Map<String, dynamic>> draws, String layer) {
    for (int pos = 0; pos < 7; pos++) {
      final position = 'position${pos + 1}';
      final maxNum = pos == 6 ? 15 : 10;
      Map<int, int> counts = {};

      // 初始化计数
      for (int i = 0; i < maxNum; i++) {
        counts[i] = 0;
      }

      // 统计频率
      for (var draw in draws) {
        try {
          final numbersStr = draw['numbers'].toString();
          List<String> numbers;

          // 处理带空格和不带空格的两种情况
          if (numbersStr.contains(' ')) {
            numbers = numbersStr.split(' ');
          } else {
            // 如果没有空格，每个字符都是一个数字
            numbers = numbersStr.split('');
          }

          if (numbers.length != 7) {
            print(
                '警告: 开奖号码数量不正确，期号: ${draw['draw_number']}, 号码: ${draw['numbers']}');
            continue;
          }

          final numStr = numbers[pos].trim();
          if (numStr.isEmpty) {
            print('警告: 开奖号码为空，期号: ${draw['draw_number']}, 位置: $pos');
            continue;
          }

          final num = int.parse(numStr);
          if (num >= 0 && num < maxNum) {
            counts[num] = (counts[num] ?? 0) + 1;
          } else {
            print(
                '警告: 开奖号码超出范围，期号: ${draw['draw_number']}, 号码: $num, 位置: $pos');
          }
        } catch (e) {
          print('处理开奖号码时出错: ${draw['draw_number']}, 错误: $e');
          continue;
        }
      }

      // 转换为频率并应用时间权重
      final total = draws.length;
      if (total > 0) {
        _layerFeatures[layer]![position]!['frequency'] = counts.map(
          (k, v) => MapEntry(k, v / total),
        );
      } else {
        // 如果没有数据，使用均匀分布
        final uniformProb = 1.0 / maxNum;
        _layerFeatures[layer]![position]!['frequency'] = Map.fromIterable(
            List.generate(maxNum, (i) => i),
            key: (i) => i,
            value: (_) => uniformProb);
      }
    }
  }

  void _calculateMissingValues(List<Map<String, dynamic>> draws, String layer) {
    for (int pos = 0; pos < 7; pos++) {
      final position = 'position${pos + 1}';
      final maxNum = pos == 6 ? 15 : 10;

      // 初始化遗漏值数组
      List<int> missing = List.filled(maxNum, 0);

      // 计算遗漏值
      for (var draw in draws) {
        final numbers = draw['numbers'].toString().split(' ');
        if (numbers.length <= pos) {
          print('警告: 号码数组长度不足，跳过该期: ${draw['draw_number']}');
          continue;
        }

        final numStr = numbers[pos];
        if (numStr.isEmpty) {
          print('警告: 号码为空，跳过该期: ${draw['draw_number']}');
          continue;
        }

        final num = int.tryParse(numStr);
        if (num == null || num < 0 || num >= maxNum) {
          print('警告: 无效号码 $numStr，跳过该期: ${draw['draw_number']}');
          continue;
        }

        for (int i = 0; i < maxNum; i++) {
          if (i != num) {
            missing[i]++;
          } else {
            missing[i] = 0;
          }
        }
      }

      _layerFeatures[layer]![position]!['missingValues'] = missing;
    }
  }

  void _calculateRepeats(List<Map<String, dynamic>> draws, String layer) {
    for (int pos = 0; pos < 7; pos++) {
      final position = 'position${pos + 1}';
      Map<int, int> repeats = {};

      for (int i = 0; i < draws.length - 1; i++) {
        final currentNumbers = draws[i]['numbers'].toString().split(' ');
        final nextNumbers = draws[i + 1]['numbers'].toString().split(' ');

        final currentNum = int.parse(currentNumbers[pos]);
        final nextNum = int.parse(nextNumbers[pos]);

        if (currentNum == nextNum) {
          repeats[currentNum] = (repeats[currentNum] ?? 0) + 1;
        }
      }

      _layerFeatures[layer]![position]!['repeats'] = repeats;
    }
  }

  void _calculateRatios(List<Map<String, dynamic>> draws, String layer) {
    for (int pos = 0; pos < 7; pos++) {
      final position = 'position${pos + 1}';
      final maxNum = pos == 6 ? 15 : 10;
      int bigCount = 0;
      int oddCount = 0;

      for (var draw in draws) {
        final numbers = draw['numbers'].toString().split(' ');
        final num = int.parse(numbers[pos]);

        // 大小比
        if (num > maxNum ~/ 2) {
          bigCount++;
        }

        // 奇偶比
        if (num % 2 == 1) {
          oddCount++;
        }
      }

      final total = draws.length.toDouble();
      _layerFeatures[layer]![position]!['bigSmallRatio'] = {
        'big': bigCount / total,
        'small': (total - bigCount) / total,
      };

      _layerFeatures[layer]![position]!['oddEvenRatio'] = {
        'odd': oddCount / total,
        'even': (total - oddCount) / total,
      };
    }
  }

  void _calculate012Way(List<Map<String, dynamic>> draws, String layer) {
    for (int pos = 0; pos < 7; pos++) {
      final position = 'position${pos + 1}';
      List<int> counts = [0, 0, 0];

      for (var draw in draws) {
        final numbers = draw['numbers'].toString().split(' ');
        final num = int.parse(numbers[pos]);
        counts[num % 3]++;
      }

      final total = draws.length.toDouble();
      _layerFeatures[layer]![position]!['012way'] = {
        'way0': counts[0] / total,
        'way1': counts[1] / total,
        'way2': counts[2] / total,
      };
    }
  }

  void _calculateSpanValues(List<Map<String, dynamic>> draws, String layer) {
    for (int pos = 0; pos < 7; pos++) {
      final position = 'position${pos + 1}';
      Map<int, int> spans = {};

      for (int i = 0; i < draws.length - 1; i++) {
        final currentNumbers = draws[i]['numbers'].toString().split(' ');
        final nextNumbers = draws[i + 1]['numbers'].toString().split(' ');

        final currentNum = int.parse(currentNumbers[pos]);
        final nextNum = int.parse(nextNumbers[pos]);

        final span = (currentNum - nextNum).abs();
        spans[span] = (spans[span] ?? 0) + 1;
      }

      final total = spans.values.fold(0, (sum, count) => sum + count);
      _layerFeatures[layer]![position]!['spanValues'] = spans.map(
        (k, v) => MapEntry(k, v / total),
      );
    }
  }

  Future<void> _calculateHistoricalPatterns(
      List<Map<String, dynamic>> currentDraws, String layer) async {
    if (currentDraws.isEmpty) return;

    try {
      final latestDraw = currentDraws.first;
      // 添加错误处理和日期格式标准化
      final String drawDate = latestDraw['draw_date'];
      final DateTime latestDate = _parseDrawDate(drawDate);

      // 获取历史同期数据（最近5年）
      final historicalDraws = await _lotteryService.getRecentDraws(
        limit: SAME_PERIOD_YEARS * 365, // 假设每天一期
      );

      for (int pos = 0; pos < 7; pos++) {
        final position = 'position${pos + 1}';

        // 按年份同期分析
        Map<int, Map<String, int>> yearlyPatterns = {};
        // 按月份分析
        Map<int, Map<String, int>> monthlyPatterns = {};
        // 按星期分析
        Map<int, Map<String, int>> weekdayPatterns = {};
        // 按季节分析
        Map<int, Map<String, int>> seasonalPatterns = {};

        for (var draw in historicalDraws) {
          try {
            final drawDate = _parseDrawDate(draw['draw_date']);
            final numbers = draw['numbers'].toString().split(' ');
            final num = int.parse(numbers[pos]);

            // 同期分析（相同月日）
            if (drawDate.month == latestDate.month &&
                drawDate.day == latestDate.day) {
              final year = drawDate.year;
              yearlyPatterns[year] ??= {};
              yearlyPatterns[year]![num.toString()] =
                  (yearlyPatterns[year]![num.toString()] ?? 0) + 1;
            }

            // 月份分析
            final month = drawDate.month;
            monthlyPatterns[month] ??= {};
            monthlyPatterns[month]![num.toString()] =
                (monthlyPatterns[month]![num.toString()] ?? 0) + 1;

            // 星期分析
            final weekday = drawDate.weekday;
            weekdayPatterns[weekday] ??= {};
            weekdayPatterns[weekday]![num.toString()] =
                (weekdayPatterns[weekday]![num.toString()] ?? 0) + 1;

            // 季节分析
            final season = (drawDate.month - 1) ~/ 3;
            seasonalPatterns[season] ??= {};
            seasonalPatterns[season]![num.toString()] =
                (seasonalPatterns[season]![num.toString()] ?? 0) + 1;
          } catch (e) {
            print(
                'Error processing draw date: ${draw['draw_date']}, Error: $e');
            continue;
          }
        }

        // 转换为概率
        Map<int, double> monthlyProbs = {};
        Map<int, double> weekdayProbs = {};
        Map<int, double> seasonalProbs = {};

        // 计算当前月份的概率
        final currentMonth = latestDate.month;
        if (monthlyPatterns.containsKey(currentMonth)) {
          final totalCount = monthlyPatterns[currentMonth]!
              .values
              .fold(0, (sum, count) => sum + count);
          monthlyPatterns[currentMonth]!.forEach((numStr, count) {
            final num = int.parse(numStr);
            monthlyProbs[num] = count / totalCount;
          });
        }

        // 计算当前星期的概率
        final currentWeekday = latestDate.weekday;
        if (weekdayPatterns.containsKey(currentWeekday)) {
          final totalCount = weekdayPatterns[currentWeekday]!
              .values
              .fold(0, (sum, count) => sum + count);
          weekdayPatterns[currentWeekday]!.forEach((numStr, count) {
            final num = int.parse(numStr);
            weekdayProbs[num] = count / totalCount;
          });
        }

        // 计算当前季节的概率
        final currentSeason = (latestDate.month - 1) ~/ 3;
        if (seasonalPatterns.containsKey(currentSeason)) {
          final totalCount = seasonalPatterns[currentSeason]!
              .values
              .fold(0, (sum, count) => sum + count);
          seasonalPatterns[currentSeason]!.forEach((numStr, count) {
            final num = int.parse(numStr);
            seasonalProbs[num] = count / totalCount;
          });
        }

        // 保存分析结果
        _layerFeatures[layer]![position]!['monthlyPattern'] = monthlyProbs;
        _layerFeatures[layer]![position]!['weekdayPattern'] = weekdayProbs;
        _positionFeatures[position]!['monthlyPattern'] = monthlyProbs;
        _positionFeatures[position]!['weekdayPattern'] = weekdayProbs;
        _positionFeatures[position]!['seasonalPattern'] = seasonalProbs;

        // 保存原始历史数据
        _historicalPatterns[position] = {
          'yearlyPatterns': yearlyPatterns,
          'monthlyPatterns': monthlyPatterns,
          'weekdayPatterns': weekdayPatterns,
          'seasonalPatterns': seasonalPatterns,
        };
      }
    } catch (e) {
      print('Error in historical pattern calculation: $e');
      rethrow;
    }
  }

  // 添加日期解析辅助方法
  DateTime _parseDrawDate(String dateStr) {
    try {
      // 处理可能的日期格式
      if (dateStr.contains('(')) {
        // 格式如: "2024-03-16(日)"
        dateStr = dateStr.split('(')[0];
      }

      // 尝试解析标准格式 "YYYY-MM-DD"
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      }

      // 尝试解析期号格式 "YYXXX"，其中 YY 是年份，XXX 是当年的期号
      if (dateStr.length >= 5) {
        final year = int.parse(dateStr.substring(0, 2)) + 2000;
        final dayOfYear = int.parse(dateStr.substring(2));
        final date = DateTime(year).add(Duration(days: dayOfYear - 1));
        return date;
      }

      throw FormatException('Unsupported date format: $dateStr');
    } catch (e) {
      print('Error parsing date: $dateStr, Error: $e');
      rethrow;
    }
  }

  void _calculateCorrelations(List<Map<String, dynamic>> draws, String layer) {
    // 计算相邻位置的号码关联
    for (int i = 0; i < 6; i++) {
      final pos1 = 'position${i + 1}';
      final pos2 = 'position${i + 2}';
      Map<int, Map<int, int>> jointCounts = {};
      Map<int, int> totalCounts = {};

      for (var draw in draws) {
        final numbers = draw['numbers'].toString().split(' ');
        final num1 = int.parse(numbers[i]);
        final num2 = int.parse(numbers[i + 1]);

        jointCounts[num1] ??= {};
        jointCounts[num1]![num2] = (jointCounts[num1]![num2] ?? 0) + 1;
        totalCounts[num1] = (totalCounts[num1] ?? 0) + 1;
      }

      // 转换为条件概率
      Map<int, Map<int, double>> condProbs = {};
      jointCounts.forEach((num1, counts) {
        condProbs[num1] = {};
        counts.forEach((num2, count) {
          condProbs[num1]![num2] = count / totalCounts[num1]!;
        });
      });

      _correlationData['$pos1-$pos2'] = {'condProbs': condProbs};
    }
  }

  void _calculateTimeSeries(List<Map<String, dynamic>> draws, String layer) {
    for (int pos = 0; pos < 7; pos++) {
      final position = 'position${pos + 1}';
      final maxNum = pos == 6 ? 15 : 10;

      // 计算移动平均
      List<double> movingAverages = [];
      List<int> numbers = draws.map((draw) {
        final nums = draw['numbers'].toString().split(' ');
        return int.parse(nums[pos]);
      }).toList();

      // 计算5期移动平均
      for (int i = 0; i < numbers.length - 4; i++) {
        double sum = 0;
        for (int j = 0; j < 5; j++) {
          sum += numbers[i + j];
        }
        movingAverages.add(sum / 5);
      }

      // 计算趋势
      Map<int, String> trends = {};
      for (int num = 0; num < maxNum; num++) {
        int count = 0;
        String trend = 'stable';

        for (int i = 0; i < numbers.length - 1; i++) {
          if (numbers[i] == num) {
            if (i > 0 && numbers[i - 1] < num) count++;
            if (i > 0 && numbers[i - 1] > num) count--;
          }
        }

        if (count > 2) trend = 'up';
        if (count < -2) trend = 'down';
        trends[num] = trend;
      }

      // 计算波动性
      Map<int, double> volatility = {};
      for (int num = 0; num < maxNum; num++) {
        List<int> intervals = [];
        int lastIndex = -1;

        for (int i = 0; i < numbers.length; i++) {
          if (numbers[i] == num) {
            if (lastIndex != -1) {
              intervals.add(i - lastIndex);
            }
            lastIndex = i;
          }
        }

        if (intervals.isNotEmpty) {
          double mean = intervals.reduce((a, b) => a + b) / intervals.length;
          double variance =
              intervals.map((i) => pow(i - mean, 2)).reduce((a, b) => a + b) /
                  intervals.length;
          volatility[num] = sqrt(variance);
        } else {
          volatility[num] = 0;
        }
      }

      _timeSeriesData[position] = {
        'movingAverages': movingAverages,
        'trends': trends,
        'volatility': volatility,
      };
    }
  }

  void _calculatePeriodicity(List<Map<String, dynamic>> draws, String layer) {
    for (int pos = 0; pos < 7; pos++) {
      final position = 'position${pos + 1}';
      final maxNum = pos == 6 ? 15 : 10;

      // 计算周期性特征
      Map<int, Map<String, dynamic>> periodicity = {};

      for (int num = 0; num < maxNum; num++) {
        // 计算间隔序列
        List<int> intervals = [];
        int lastIndex = -1;

        for (int i = 0; i < draws.length; i++) {
          final numbers = draws[i]['numbers'].toString().split(' ');
          final currentNum = int.parse(numbers[pos]);

          if (currentNum == num) {
            if (lastIndex != -1) {
              intervals.add(i - lastIndex);
            }
            lastIndex = i;
          }
        }

        // 分析周期性
        if (intervals.isNotEmpty) {
          // 计算主要周期
          Map<int, int> periodCounts = {};
          for (int interval in intervals) {
            periodCounts[interval] = (periodCounts[interval] ?? 0) + 1;
          }

          // 找出最常见的周期
          var mainPeriod = periodCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;

          // 计算周期强度（主要周期的出现比例）
          double periodStrength = periodCounts[mainPeriod]! / intervals.length;

          // 计算下一次出现的预期间隔
          int lastOccurrence = -1;
          for (int i = 0; i < draws.length; i++) {
            final numbers = draws[i]['numbers'].toString().split(' ');
            if (int.parse(numbers[pos]) == num) {
              lastOccurrence = i;
              break;
            }
          }

          int expectedNextGap = lastOccurrence == -1
              ? mainPeriod
              : (mainPeriod - (draws.length - 1 - lastOccurrence) % mainPeriod);

          periodicity[num] = {
            'mainPeriod': mainPeriod,
            'periodStrength': periodStrength,
            'expectedNextGap': expectedNextGap,
            'intervals': intervals,
          };
        }
      }

      _periodicityData[position] = {
        'periodicity': periodicity,
      };
    }
  }

  void _calculateCombinationPatterns(
      List<Map<String, dynamic>> draws, String layer) {
    // 分析数字组合模式
    Map<String, int> pairPatterns = {};
    Map<String, int> triplePatterns = {};
    Map<String, double> positionCorrelations = {};

    // 分析相邻数字对
    for (var draw in draws) {
      final numbers = draw['numbers'].toString().split(' ');

      // 分析数字对
      for (int i = 0; i < numbers.length - 1; i++) {
        final pair = '${numbers[i]}-${numbers[i + 1]}';
        pairPatterns[pair] = (pairPatterns[pair] ?? 0) + 1;
      }

      // 分析三个数字的组合
      for (int i = 0; i < numbers.length - 2; i++) {
        final triple = '${numbers[i]}-${numbers[i + 1]}-${numbers[i + 2]}';
        triplePatterns[triple] = (triplePatterns[triple] ?? 0) + 1;
      }
    }

    // 计算位置之间的相关性
    for (int i = 0; i < 6; i++) {
      for (int j = i + 1; j < 7; j++) {
        int matches = 0;
        for (var draw in draws) {
          final numbers = draw['numbers'].toString().split(' ');
          final num1 = int.parse(numbers[i]);
          final num2 = int.parse(numbers[j]);

          // 检查是否有特定的关系（如差值、和值等）
          if ((num1 + num2) % 2 == 0) matches++;
          if ((num1 - num2).abs() <= 2) matches++;
        }

        final correlation = matches / (draws.length * 2);
        positionCorrelations['$i-$j'] = correlation;
      }
    }

    // 保存组合模式分析结果
    _combinationPatterns = {
      'pairPatterns': {'patterns': pairPatterns},
      'triplePatterns': {'patterns': triplePatterns},
      'positionCorrelations': {'correlations': positionCorrelations},
    };
  }

  void _mergeLayerFeatures() {
    for (int pos = 0; pos < 7; pos++) {
      final position = 'position${pos + 1}';

      // 合并频率特征
      Map<int, double> mergedFrequency = {};
      _layerFeatures.forEach((layer, features) {
        final layerFreq = features[position]!['frequency'] as Map<int, double>;
        final weight = _layerWeights[layer]!;
        layerFreq.forEach((num, freq) {
          mergedFrequency[num] = (mergedFrequency[num] ?? 0) + freq * weight;
        });
      });
      _positionFeatures[position]!['frequency'] = mergedFrequency;

      // 合并其他特征
      _mergeBigSmallRatio(position);
      _mergeOddEvenRatio(position);
      _merge012Way(position);
      _mergeSpanValues(position);
      _mergeHistoricalPatterns(position);
    }
  }

  void _mergeBigSmallRatio(String position) {
    double mergedBig = 0;
    double mergedSmall = 0;

    _layerFeatures.forEach((layer, features) {
      final ratio = features[position]!['bigSmallRatio'] as Map<String, double>;
      final weight = _layerWeights[layer]!;
      mergedBig += ratio['big']! * weight;
      mergedSmall += ratio['small']! * weight;
    });

    _positionFeatures[position]!['bigSmallRatio'] = {
      'big': mergedBig,
      'small': mergedSmall,
    };
  }

  void _mergeOddEvenRatio(String position) {
    double mergedOdd = 0;
    double mergedEven = 0;

    _layerFeatures.forEach((layer, features) {
      final ratio = features[position]!['oddEvenRatio'] as Map<String, double>;
      final weight = _layerWeights[layer]!;
      mergedOdd += ratio['odd']! * weight;
      mergedEven += ratio['even']! * weight;
    });

    _positionFeatures[position]!['oddEvenRatio'] = {
      'odd': mergedOdd,
      'even': mergedEven,
    };
  }

  void _merge012Way(String position) {
    double mergedWay0 = 0;
    double mergedWay1 = 0;
    double mergedWay2 = 0;

    _layerFeatures.forEach((layer, features) {
      final way = features[position]!['012way'] as Map<String, double>;
      final weight = _layerWeights[layer]!;
      mergedWay0 += way['way0']! * weight;
      mergedWay1 += way['way1']! * weight;
      mergedWay2 += way['way2']! * weight;
    });

    _positionFeatures[position]!['012way'] = {
      'way0': mergedWay0,
      'way1': mergedWay1,
      'way2': mergedWay2,
    };
  }

  void _mergeSpanValues(String position) {
    Map<int, double> mergedSpans = {};

    _layerFeatures.forEach((layer, features) {
      final spans = features[position]!['spanValues'] as Map<int, double>;
      final weight = _layerWeights[layer]!;
      spans.forEach((span, value) {
        mergedSpans[span] = (mergedSpans[span] ?? 0) + value * weight;
      });
    });

    _positionFeatures[position]!['spanValues'] = mergedSpans;
  }

  void _mergeHistoricalPatterns(String position) {
    Map<int, double> mergedMonthly = {};
    Map<int, double> mergedWeekday = {};
    Map<int, double> mergedSeasonal = {};

    _layerFeatures.forEach((layer, features) {
      final weight = _layerWeights[layer]!;

      final monthly = features[position]!['monthlyPattern'] as Map<int, double>;
      monthly.forEach((num, value) {
        mergedMonthly[num] = (mergedMonthly[num] ?? 0) + value * weight;
      });

      final weekday = features[position]!['weekdayPattern'] as Map<int, double>;
      weekday.forEach((num, value) {
        mergedWeekday[num] = (mergedWeekday[num] ?? 0) + value * weight;
      });

      final seasonal =
          features[position]!['seasonalPattern'] as Map<int, double>;
      seasonal.forEach((num, value) {
        mergedSeasonal[num] = (mergedSeasonal[num] ?? 0) + value * weight;
      });
    });

    _positionFeatures[position]!['monthlyPattern'] = mergedMonthly;
    _positionFeatures[position]!['weekdayPattern'] = mergedWeekday;
    _positionFeatures[position]!['seasonalPattern'] = mergedSeasonal;
  }

  Future<Map<String, dynamic>> predictNextDraw() async {
    await calculateFeatures();
    final latestDraw = await _lotteryService.getLatestDraw();
    if (latestDraw == null) {
      throw Exception('无法获取最新开奖数据');
    }

    // 预测下一期号码
    final nextDrawNumber =
        (int.parse(latestDraw['draw_number']) + 1).toString();
    final predictions = <String, List<int>>{};
    final confidences = <String, double>{};

    // 为每个位置生成预测
    for (int i = 0; i < 7; i++) {
      final position = 'position${i + 1}';
      final result = _predictPosition(position, i);
      predictions[position] = result['numbers'];
      confidences[position] = result['confidence'];
    }

    // 生成推荐组合
    final combinations = _generateCombinations(predictions, confidences);

    return {
      'drawNumber': nextDrawNumber,
      'predictions': predictions,
      'confidences': confidences,
      'combinations': combinations,
    };
  }

  Map<String, dynamic> _predictPosition(String position, int posIndex) {
    try {
      final features = _positionFeatures[position];
      if (features == null) {
        throw Exception('位置特征数据未初始化');
      }

      final maxNumber = posIndex == 6 ? 15 : 10;
      Map<int, double> scores = {};

      // 初始化所有可能的数字的分数
      for (int num = 0; num < maxNumber; num++) {
        scores[num] = 0.0;
      }

      // 计算每个数字的分数
      for (int num = 0; num < maxNumber; num++) {
        double score = 100;

        // 基础特征评分
        score += (features['frequency'][num] ?? 0.0) * 100;
        score +=
            ((features['missingValues'][num] ?? 0) as int).clamp(0, 20) * 2;

        if (features['repeats']?.containsKey(num) ?? false) {
          score -= 20;
        }

        final sizeRatio = features['bigSmallRatio'] as Map<String, double>;
        if ((num > maxNumber ~/ 2 && sizeRatio['big']! < 0.4) ||
            (num <= maxNumber ~/ 2 && sizeRatio['small']! < 0.4)) {
          score += 10;
        }

        final oddEvenRatio = features['oddEvenRatio'] as Map<String, double>;
        if ((num % 2 == 1 && oddEvenRatio['odd']! < 0.4) ||
            (num % 2 == 0 && oddEvenRatio['even']! < 0.4)) {
          score += 10;
        }

        final way = features['012way']['way${num % 3}'] ?? 0.0;
        score += way * 50;

        final spanValues = features['spanValues'] as Map<int, double>;
        if (spanValues.containsKey(num)) {
          score += spanValues[num]! * 50;
        }

        final samePeriodPattern =
            features['samePeriodPattern'] as Map<int, double>?;
        if (samePeriodPattern?.containsKey(num) ?? false) {
          score += samePeriodPattern![num]! * 50;
        }

        // 时间序列分析评分
        final timeSeriesFeatures = _timeSeriesData[position];
        if (timeSeriesFeatures != null) {
          final trend = timeSeriesFeatures['trends'][num] as String;
          if (trend == 'up') score += 20;
          if (trend == 'down') score -= 10;

          final volatility =
              timeSeriesFeatures['volatility'][num] as double? ?? 0.0;
          score -= volatility * 5; // 波动性越大，分数越低
        }

        // 周期性分析评分
        final periodicityFeatures = _periodicityData[position]?['periodicity']
            [num] as Map<String, dynamic>?;
        if (periodicityFeatures != null) {
          final periodStrength =
              periodicityFeatures['periodStrength'] as double;
          final expectedNextGap = periodicityFeatures['expectedNextGap'] as int;

          if (expectedNextGap == 1) {
            score += 30 * periodStrength; // 如果预期下一期出现，根据周期强度增加分数
          } else if (expectedNextGap > 10) {
            score -= 20; // 如果预期还要很久才出现，降低分数
          }
        }

        // 添加历史模式评分
        final monthlyPattern = features['monthlyPattern'] as Map<int, double>;
        if (monthlyPattern.containsKey(num)) {
          score += monthlyPattern[num]! * 40; // 月度模式权重
        }

        final weekdayPattern = features['weekdayPattern'] as Map<int, double>;
        if (weekdayPattern.containsKey(num)) {
          score += weekdayPattern[num]! * 30; // 星期模式权重
        }

        final seasonalPattern = features['seasonalPattern'] as Map<int, double>;
        if (seasonalPattern.containsKey(num)) {
          score += seasonalPattern[num]! * 35; // 季节模式权重
        }

        // 组合模式分析评分
        if (posIndex > 0) {
          final previousPosition = 'position${posIndex}';
          final previousFeatures = _positionFeatures[previousPosition];
          if (previousFeatures != null) {
            final frequency = previousFeatures['frequency'] as Map<int, double>;
            final previousPrediction = frequency.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;

            final pair = '$previousPrediction-$num';
            final patterns = _combinationPatterns['pairPatterns']?['patterns']
                as Map<String, int>?;
            final pairCount = patterns?[pair] ?? 0;
            score += pairCount * 2; // 根据数字对的历史出现次数增加分数
          }
        }

        scores[num] = (score / 10).clamp(0.0, 100.0);
      }

      // 选择得分最高的三个号码
      final sortedScores = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 确保至少返回一个号码，最多返回三个号码
      final selectedNumbers = sortedScores.take(3).map((e) => e.key).toList();
      if (selectedNumbers.isEmpty) {
        selectedNumbers.add(0);
      }

      // 计算置信度
      final confidence = selectedNumbers.length > 0
          ? sortedScores
                  .take(selectedNumbers.length)
                  .map((e) => e.value)
                  .reduce((a, b) => a + b) /
              (selectedNumbers.length * 100)
          : 0.0;

      return {
        'numbers': selectedNumbers,
        'confidence': confidence,
      };
    } catch (e) {
      print('Error in _predictPosition: $e');
      return {
        'numbers': [0],
        'confidence': 0.0,
      };
    }
  }

  List<List<int>> _generateCombinations(
    Map<String, List<int>> predictions,
    Map<String, double> confidences,
  ) {
    try {
      List<List<int>> combinations = [];
      final weights = [0.6, 0.25, 0.15]; // 固定权重

      for (int i = 0; i < 3; i++) {
        List<int> combination = [];

        for (int pos = 0; pos < 7; pos++) {
          final position = 'position${pos + 1}';
          final numbers = predictions[position];

          if (numbers == null || numbers.isEmpty) {
            combination.add(0);
            continue;
          }

          // 根据权重选择数字
          final rand = _random.nextDouble();
          int selectedIndex = 0;
          double cumWeight = 0;

          for (int j = 0; j < numbers.length && j < weights.length; j++) {
            cumWeight += weights[j];
            if (rand <= cumWeight) {
              selectedIndex = j;
              break;
            }
          }

          // 确保索引不会越界
          selectedIndex = selectedIndex.clamp(0, numbers.length - 1);
          combination.add(numbers[selectedIndex]);
        }

        combinations.add(combination);
      }

      return combinations;
    } catch (e) {
      print('Error in _generateCombinations: $e');
      // 返回默认组合
      return List.generate(3, (_) => List.filled(7, 0));
    }
  }
}
