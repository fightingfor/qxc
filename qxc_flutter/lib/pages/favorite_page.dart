import 'package:flutter/material.dart';
import 'package:qxc_flutter/models/favorite_model.dart';
import 'package:qxc_flutter/services/favorite_service.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final _favoriteService = FavoriteService();
  List<FavoriteNumber> _undrawnFavorites = [];
  List<FavoriteNumber> _drawnFavorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final undrawn = await _favoriteService.getUndrawnFavorites();
      final drawn = await _favoriteService.getDrawnFavorites();
      setState(() {
        _undrawnFavorites = undrawn;
        _drawnFavorites = drawn;
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

  Future<void> _deleteFavorite(FavoriteNumber favorite) async {
    try {
      await _favoriteService.deleteFavorite(favorite.id!);

      // 只更新当前列表状态
      setState(() {
        if (favorite.drawResult == null) {
          _undrawnFavorites.removeWhere((f) => f.id == favorite.id);
        } else {
          _drawnFavorites.removeWhere((f) => f.id == favorite.id);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已删除收藏'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFavorites,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFavoriteSection(
                    '未开奖预测',
                    _undrawnFavorites,
                    showDrawResult: false,
                  ),
                  const SizedBox(height: 16),
                  _buildFavoriteSection(
                    '已开奖预测',
                    _drawnFavorites,
                    showDrawResult: true,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFavoriteSection(
    String title,
    List<FavoriteNumber> favorites, {
    required bool showDrawResult,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (favorites.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('暂无收藏')),
          )
        else
          ...favorites
              .map((favorite) => _buildFavoriteCard(favorite, showDrawResult)),
      ],
    );
  }

  Widget _buildFavoriteCard(FavoriteNumber favorite, bool showDrawResult) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text('第${favorite.drawNumber}期'),
        subtitle: Text(
          '预测号码: ${favorite.numbers.join(' ')}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '置信度: ${(favorite.confidence * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteFavorite(favorite),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('收藏时间: ${_formatDateTime(favorite.favoriteTime)}'),
                if (showDrawResult && favorite.drawResult != null) ...[
                  const SizedBox(height: 8),
                  Text('开奖号码: ${favorite.drawResult!.drawnNumbers.join(' ')}'),
                  Text('匹配数量: ${favorite.drawResult!.matchCount}'),
                  Text(
                      '中奖等级: ${_getPrizeLevelText(favorite.drawResult!.prizeLevel)}'),
                  if (favorite.drawResult!.prizeAmount != null)
                    Text(
                        '中奖金额: ¥${favorite.drawResult!.prizeAmount!.toStringAsFixed(2)}'),
                ],
              ],
            ),
          ),
        ],
      ),
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
