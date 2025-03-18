import 'package:flutter/material.dart';
import 'package:qxc_flutter/pages/home_page.dart';
import 'package:qxc_flutter/services/lottery_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _loadingText = '正在初始化...';
  bool _isError = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // 1. 导入CSV数据
      setState(() {
        _loadingText = '正在导入历史数据...';
        _progress = 0.0;
      });

      await LotteryService.instance.importCsvData(
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _loadingText = message;
            });
          }
        },
      );

      // 2. 同步最新数据
      setState(() {
        _loadingText = '正在同步最新数据...';
        _progress = 0.9;
      });
      await LotteryService.instance.syncData();

      // 3. 完成后跳转到主页
      setState(() {
        _progress = 1.0;
        _loadingText = '初始化完成';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      setState(() {
        _loadingText = '数据加载失败: $e';
        _isError = true;
        _progress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo或应用名称
              const Text(
                '七星彩预测',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // 进度条
              if (!_isError) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 加载文本
              Text(
                _loadingText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isError ? Colors.red : null,
                ),
              ),

              // 错误时显示重试按钮
              if (_isError) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializeData,
                  child: const Text('重试'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
