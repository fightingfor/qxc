import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qxc_flutter/services/lottery_service.dart';
import 'package:qxc_flutter/services/prediction_service.dart';
import 'package:qxc_flutter/services/favorite_service.dart';
import 'package:qxc_flutter/services/prediction_record_service.dart';
import 'package:qxc_flutter/models/favorite_model.dart';
import 'package:qxc_flutter/models/prediction_record.dart';

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  Map<String, dynamic>? _latestDraw;
  bool _isLoading = true;
  bool _isPredicting = false;
  final _favoriteService = FavoriteService();
  final _predictionRecordService = PredictionRecordService();
  List<PredictionRecord> _predictionRecords = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final latestDraw = await LotteryService.instance.getLatestDraw();
      final predictions = await _predictionRecordService.getAllPredictions();
      setState(() {
        _latestDraw = latestDraw;
        _predictionRecords = predictions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(PredictionRecord record, int index) async {
    try {
      if (record.favoritedStatus[index]) {
        // 取消收藏
        final favorite =
            await _favoriteService.findByDrawNumber(record.drawNumber);
        if (favorite != null &&
            listEquals(favorite.numbers, record.combinations[index])) {
          await _favoriteService.deleteFavorite(favorite.id!);
        }
      } else {
        // 添加收藏
        final favorite = FavoriteNumber(
          drawNumber: record.drawNumber,
          numbers: record.combinations[index],
          confidence: record.confidences['position1']!, // 使用第一位的置信度
          favoriteTime: DateTime.now(),
        );
        await _favoriteService.addFavorite(favorite);
      }

      // 更新预测记录的收藏状态
      final newStatus = List<bool>.from(record.favoritedStatus);
      newStatus[index] = !newStatus[index];
      await _predictionRecordService.updateFavoriteStatus(
          record.id!, newStatus);

      // 只更新当前记录的状态
      setState(() {
        final recordIndex =
            _predictionRecords.indexWhere((r) => r.id == record.id);
        if (recordIndex != -1) {
          _predictionRecords[recordIndex] = record.copyWith(
            favoritedStatus: newStatus,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!record.favoritedStatus[index] ? '已添加到收藏' : '已取消收藏'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _generatePrediction() async {
    setState(() => _isPredicting = true);
    try {
      print('开始生成预测...');
      final prediction = await PredictionService.instance.predictNextDraw();
      print('预测结果: $prediction');

      print('创建预测记录...');
      // 检查预测结果的数据结构
      if (prediction['predictions'] == null) {
        throw Exception('预测结果中缺少 predictions 数据');
      }
      if (prediction['confidences'] == null) {
        throw Exception('预测结果中缺少 confidences 数据');
      }
      if (prediction['combinations'] == null) {
        throw Exception('预测结果中缺少 combinations 数据');
      }

      // 创建预测记录
      final record = PredictionRecord(
        drawNumber: prediction['drawNumber'],
        predictionTime: DateTime.now(),
        predictions: Map<String, List<int>>.from(prediction['predictions']),
        confidences: Map<String, double>.from(prediction['confidences']),
        combinations: List<List<int>>.from(prediction['combinations']),
      );
      print('预测记录创建成功: ${record.toString()}');

      print('保存预测记录...');
      final id = await _predictionRecordService.addPrediction(record);
      print('预测记录保存成功');

      // 只将新记录添加到列表开头
      setState(() {
        _predictionRecords.insert(0, record.copyWith(id: id));
        _isPredicting = false;
      });
    } catch (e, stackTrace) {
      print('预测失败，错误: $e');
      print('错误堆栈: $stackTrace');
      setState(() => _isPredicting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('预测失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('七星彩预测'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildLatestDrawCard(),
                  const SizedBox(height: 16),
                  _buildPredictionCard(),
                  if (_predictionRecords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '历史预测',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ..._predictionRecords.map(_buildPredictionRecordCard),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildLatestDrawCard() {
    if (_latestDraw == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无开奖数据'),
        ),
      );
    }

    final numbers = _latestDraw!['numbers'].toString().split(' ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最新开奖 - 第${_latestDraw!['draw_number']}期',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '开奖时间: ${_latestDraw!['draw_date']}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: numbers
                  .map((number) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            number.trim(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '下期预测',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ElevatedButton(
                  onPressed: _isPredicting ? null : _generatePrediction,
                  child: _isPredicting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('生成预测'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionRecordCard(PredictionRecord record) {
    // 确保favoritedStatus列表长度与combinations匹配
    if (record.favoritedStatus.length != record.combinations.length) {
      record = record.copyWith(
        favoritedStatus:
            List.generate(record.combinations.length, (_) => false),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text('第${record.drawNumber}期'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '预测时间: ${_formatDateTime(record.predictionTime)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (record.drawResult != null) ...[
              const SizedBox(height: 4),
              Text(
                '开奖号码: ${record.drawResult!.drawnNumbers.join(' ')}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              Text(
                '匹配数量: ${record.drawResult!.matchCount}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '中奖等级: ${_getPrizeLevelText(record.drawResult!.prizeLevel)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: record.drawResult!.prizeLevel > 0
                          ? Colors.red
                          : Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              if (record.drawResult!.prizeAmount != null)
                Text(
                  '中奖金额: ¥${record.drawResult!.prizeAmount!.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                ),
            ],
            const SizedBox(height: 4),
            Text(
              '推荐组合:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            ...record.combinations.asMap().entries.map((entry) {
              final index = entry.key;
              final combo = entry.value;
              final isFavorited = index < record.favoritedStatus.length
                  ? record.favoritedStatus[index]
                  : false;

              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text(
                      '组合 ${index + 1}: ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Expanded(
                      child: Text(
                        combo.join(' '),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '置信度: ${(record.confidences['position1']! * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      icon: Icon(
                        isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: isFavorited ? Colors.red : null,
                      ),
                      onPressed: () => _toggleFavorite(record, index),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('各位置预测:'),
                const SizedBox(height: 8),
                for (int i = 0; i < 7; i++) ...[
                  _buildPositionPrediction(i, record),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionPrediction(int index, PredictionRecord record) {
    final position = 'position${index + 1}';
    final numbers = record.predictions[position]!;
    final confidence = record.confidences[position]!;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text('第${index + 1}位:'),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: numbers.map((number) {
              return Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                child: Center(
                  child: Text(
                    number.toString(),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(${(confidence * 100).toStringAsFixed(0)}%)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getPrizeLevelText(int prizeLevel) {
    switch (prizeLevel) {
      case 1:
        return '一等奖';
      case 2:
        return '二等奖';
      case 3:
        return '三等奖';
      case 4:
        return '四等奖';
      case 5:
        return '五等奖';
      default:
        return '未中奖';
    }
  }
}
