import 'package:flutter/material.dart';
import 'package:qxc_flutter/services/lottery_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('同步数据'),
            subtitle: const Text('从服务器获取最新开奖数据'),
            onTap: () async {
              try {
                await LotteryService.instance.syncData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('数据同步成功')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('数据同步失败: $e')),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '七星彩预测',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 七星彩预测',
                children: const [
                  Text(
                    '\n本应用仅供娱乐参考，不构成投注建议。'
                    '购彩有风险，投注需谨慎。',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
