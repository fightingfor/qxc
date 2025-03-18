import 'dart:convert';

class DrawResult {
  final List<int> drawnNumbers;
  final int matchCount;
  final int prizeLevel;
  final double? prizeAmount;

  DrawResult({
    required this.drawnNumbers,
    required this.matchCount,
    required this.prizeLevel,
    this.prizeAmount,
  });

  factory DrawResult.fromJson(Map<String, dynamic> json) {
    return DrawResult(
      drawnNumbers: List<int>.from(json['drawnNumbers']),
      matchCount: json['matchCount'],
      prizeLevel: json['prizeLevel'],
      prizeAmount: json['prizeAmount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'drawnNumbers': drawnNumbers,
      'matchCount': matchCount,
      'prizeLevel': prizeLevel,
      'prizeAmount': prizeAmount,
    };
  }
}

class PredictionRecord {
  final int? id; // 数据库ID
  final String drawNumber; // 期号
  final DateTime predictionTime; // 预测时间
  final Map<String, List<int>> predictions; // 每个位置的预测数字
  final Map<String, double> confidences; // 每个位置的置信度
  final List<List<int>> combinations; // 推荐号码组合
  final List<bool> favoritedStatus; // 每个组合的收藏状态
  final DrawResult? drawResult; // 开奖结果

  PredictionRecord({
    this.id,
    required this.drawNumber,
    required this.predictionTime,
    required this.predictions,
    required this.confidences,
    required this.combinations,
    List<bool>? favoritedStatus,
    this.drawResult,
  }) : favoritedStatus =
            favoritedStatus ?? List.generate(combinations.length, (_) => false);

  // 从JSON映射创建对象
  factory PredictionRecord.fromJson(Map<String, dynamic> json) {
    return PredictionRecord(
      id: json['id'],
      drawNumber: json['drawNumber'],
      predictionTime:
          DateTime.fromMillisecondsSinceEpoch(json['predictionTime']),
      predictions: Map<String, List<int>>.from(
        json['predictions']
            .map((key, value) => MapEntry(key, List<int>.from(value))),
      ),
      confidences: Map<String, double>.from(json['confidences']),
      combinations: List<List<int>>.from(
        json['combinations'].map((combo) => List<int>.from(combo)),
      ),
      favoritedStatus: List<bool>.from(json['favoritedStatus'] ?? []),
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
      'predictionTime': predictionTime.millisecondsSinceEpoch,
      'predictions': predictions,
      'confidences': confidences,
      'combinations': combinations,
      'favoritedStatus': favoritedStatus,
      'drawResult': drawResult?.toJson(),
    };
  }

  // 转换为数据库存储格式
  Map<String, dynamic> toMap() {
    return {
      'draw_number': drawNumber,
      'prediction_time': predictionTime.millisecondsSinceEpoch,
      'predictions': jsonEncode(predictions),
      'confidences': jsonEncode(confidences),
      'combinations': jsonEncode(combinations),
      'favorited_status': jsonEncode(favoritedStatus),
      'draw_result':
          drawResult != null ? jsonEncode(drawResult!.toJson()) : null,
    };
  }

  // 从数据库记录创建对象
  factory PredictionRecord.fromMap(Map<String, dynamic> map) {
    return PredictionRecord(
      id: map['id'],
      drawNumber: map['draw_number'],
      predictionTime:
          DateTime.fromMillisecondsSinceEpoch(map['prediction_time']),
      predictions: Map<String, List<int>>.from(
        jsonDecode(map['predictions']).map(
          (key, value) => MapEntry(key, List<int>.from(value)),
        ),
      ),
      confidences: Map<String, double>.from(jsonDecode(map['confidences'])),
      combinations: List<List<int>>.from(
        jsonDecode(map['combinations']).map((combo) => List<int>.from(combo)),
      ),
      favoritedStatus: List<bool>.from(jsonDecode(map['favorited_status'])),
      drawResult: map['draw_result'] != null
          ? DrawResult.fromJson(jsonDecode(map['draw_result']))
          : null,
    );
  }

  // 复制对象并修改部分属性
  PredictionRecord copyWith({
    int? id,
    String? drawNumber,
    DateTime? predictionTime,
    Map<String, List<int>>? predictions,
    Map<String, double>? confidences,
    List<List<int>>? combinations,
    List<bool>? favoritedStatus,
    DrawResult? drawResult,
  }) {
    return PredictionRecord(
      id: id ?? this.id,
      drawNumber: drawNumber ?? this.drawNumber,
      predictionTime: predictionTime ?? this.predictionTime,
      predictions: predictions ?? this.predictions,
      confidences: confidences ?? this.confidences,
      combinations: combinations ?? this.combinations,
      favoritedStatus: favoritedStatus ?? this.favoritedStatus,
      drawResult: drawResult ?? this.drawResult,
    );
  }
}
