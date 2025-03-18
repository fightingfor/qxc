import 'dart:convert';

/// 开奖结果模型
class DrawResult {
  final List<int> drawnNumbers; // 开奖号码
  final int matchCount; // 匹配数量
  final int prizeLevel; // 中奖等级
  final double? prizeAmount; // 奖金金额

  DrawResult({
    required this.drawnNumbers,
    required this.matchCount,
    required this.prizeLevel,
    this.prizeAmount,
  });

  // 从JSON映射创建对象
  factory DrawResult.fromJson(Map<String, dynamic> json) {
    return DrawResult(
      drawnNumbers: List<int>.from(json['drawnNumbers']),
      matchCount: json['matchCount'],
      prizeLevel: json['prizeLevel'],
      prizeAmount: json['prizeAmount'],
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'drawnNumbers': drawnNumbers,
      'matchCount': matchCount,
      'prizeLevel': prizeLevel,
      'prizeAmount': prizeAmount,
    };
  }
}

/// 收藏数据模型
class FavoriteNumber {
  final int? id; // 数据库ID
  final String drawNumber; // 期号
  final List<int> numbers; // 预测号码
  final double confidence; // 置信度
  final DateTime favoriteTime; // 收藏时间
  bool isDrawn; // 是否已开奖
  DrawResult? drawResult; // 开奖结果

  FavoriteNumber({
    this.id,
    required this.drawNumber,
    required this.numbers,
    required this.confidence,
    required this.favoriteTime,
    this.isDrawn = false,
    this.drawResult,
  });

  // 从JSON映射创建对象
  factory FavoriteNumber.fromJson(Map<String, dynamic> json) {
    return FavoriteNumber(
      id: json['id'],
      drawNumber: json['drawNumber'],
      numbers: List<int>.from(json['numbers']),
      confidence: json['confidence'],
      favoriteTime: DateTime.fromMillisecondsSinceEpoch(json['favoriteTime']),
      isDrawn: json['isDrawn'] == 1,
      drawResult: json['drawResult'] != null
          ? DrawResult.fromJson(json['drawResult'])
          : null,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'drawNumber': drawNumber,
      'numbers': numbers,
      'confidence': confidence,
      'favoriteTime': favoriteTime.millisecondsSinceEpoch,
      'isDrawn': isDrawn ? 1 : 0,
      'drawResult': drawResult?.toJson(),
    };
  }

  // 转换为数据库存储格式
  Map<String, dynamic> toMap() {
    return {
      'draw_number': drawNumber,
      'numbers': jsonEncode(numbers),
      'confidence': confidence,
      'favorite_time': favoriteTime.millisecondsSinceEpoch,
      'is_drawn': isDrawn ? 1 : 0,
      'drawn_numbers': drawResult?.drawnNumbers != null
          ? jsonEncode(drawResult!.drawnNumbers)
          : null,
      'match_count': drawResult?.matchCount,
      'prize_level': drawResult?.prizeLevel,
      'prize_amount': drawResult?.prizeAmount,
    };
  }

  // 从数据库记录创建对象
  factory FavoriteNumber.fromMap(Map<String, dynamic> map) {
    DrawResult? drawResult;
    if (map['drawn_numbers'] != null) {
      drawResult = DrawResult(
        drawnNumbers: List<int>.from(jsonDecode(map['drawn_numbers'])),
        matchCount: map['match_count'],
        prizeLevel: map['prize_level'],
        prizeAmount: map['prize_amount'],
      );
    }

    return FavoriteNumber(
      id: map['id'],
      drawNumber: map['draw_number'],
      numbers: List<int>.from(jsonDecode(map['numbers'])),
      confidence: map['confidence'],
      favoriteTime: DateTime.fromMillisecondsSinceEpoch(map['favorite_time']),
      isDrawn: map['is_drawn'] == 1,
      drawResult: drawResult,
    );
  }

  // 复制对象并修改部分属性
  FavoriteNumber copyWith({
    int? id,
    String? drawNumber,
    List<int>? numbers,
    double? confidence,
    DateTime? favoriteTime,
    bool? isDrawn,
    DrawResult? drawResult,
  }) {
    return FavoriteNumber(
      id: id ?? this.id,
      drawNumber: drawNumber ?? this.drawNumber,
      numbers: numbers ?? this.numbers,
      confidence: confidence ?? this.confidence,
      favoriteTime: favoriteTime ?? this.favoriteTime,
      isDrawn: isDrawn ?? this.isDrawn,
      drawResult: drawResult ?? this.drawResult,
    );
  }

  // 计算中奖情况
  void calculateDrawResult(List<int> drawnNumbers) {
    int matchCount = 0;
    for (int i = 0; i < numbers.length; i++) {
      if (numbers[i] == drawnNumbers[i]) {
        matchCount++;
      }
    }

    // 计算中奖等级
    int prizeLevel = _calculatePrizeLevel(matchCount);

    drawResult = DrawResult(
      drawnNumbers: drawnNumbers,
      matchCount: matchCount,
      prizeLevel: prizeLevel,
      prizeAmount: null, // 奖金金额需要从其他地方获取
    );
    isDrawn = true;
  }

  // 计算中奖等级
  int _calculatePrizeLevel(int matchCount) {
    switch (matchCount) {
      case 7:
        return 1; // 一等奖
      case 6:
        return 2; // 二等奖
      case 5:
        return 3; // 三等奖
      case 4:
        return 4; // 四等奖
      case 3:
        return 5; // 五等奖
      default:
        return 0; // 未中奖
    }
  }
}
