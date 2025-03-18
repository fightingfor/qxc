import 'package:flutter/material.dart';
import 'package:qxc_flutter/services/lottery_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const int _pageSize = 30;
  final List<Map<String, dynamic>> _recentDraws = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadRecentDraws();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMore) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final moreDraws = await LotteryService.instance.getRecentDraws(
        limit: _pageSize,
        offset: (_currentPage - 1) * _pageSize,
      );

      setState(() {
        if (moreDraws.isEmpty) {
          _hasMore = false;
        } else {
          _recentDraws.addAll(moreDraws);
          _currentPage++;
        }
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

  Future<void> _loadRecentDraws() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
      _recentDraws.clear();
    });

    try {
      final recentDraws = await LotteryService.instance.getRecentDraws(
        limit: _pageSize,
        offset: 0,
      );
      setState(() {
        _recentDraws.addAll(recentDraws);
        if (recentDraws.length < _pageSize) {
          _hasMore = false;
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('开奖历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecentDraws,
          ),
        ],
      ),
      body: _recentDraws.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecentDraws,
              child: _recentDraws.isEmpty
                  ? const Center(child: Text('暂无历史数据'))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _recentDraws.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _recentDraws.length) {
                          return _buildLoadingIndicator();
                        }

                        final draw = _recentDraws[index];
                        final numbers = draw['numbers'].toString().split(' ');

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text('第${draw['draw_number']}期'),
                            subtitle: Text(draw['draw_date']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: numbers.map((number) {
                                return Container(
                                  width: 30,
                                  height: 30,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      number,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 8),
          Text('正在加载更多...'),
        ],
      ),
    );
  }
}
