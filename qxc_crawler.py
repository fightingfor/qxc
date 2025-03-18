import requests
import pandas as pd
from datetime import datetime
import time
import os

def load_existing_data():
    """加载已存在的数据文件"""
    try:
        if os.path.exists('qxc_results_all.csv'):
            df = pd.read_csv('qxc_results_all.csv')
            df['开奖时间'] = pd.to_datetime(df['开奖时间'])
            # 确保期号是字符串类型
            df['期号'] = df['期号'].astype(str)
            return df
        return None
    except Exception as e:
        print(f"读取现有数据文件时出错: {e}")
        return None

def fetch_qxc_data():
    """获取七星彩开奖数据"""
    url = 'https://webapi.sporttery.cn/gateway/lottery/getHistoryPageListV1.qry'
    
    headers = {
        'accept': 'application/json, text/javascript, */*; q=0.01',
        'accept-language': 'zh-CN,zh;q=0.9,vi;q=0.8,en;q=0.7',
        'origin': 'https://static.sporttery.cn',
        'priority': 'u=1, i',
        'referer': 'https://static.sporttery.cn/',
        'sec-ch-ua': '"Not(A:Brand";v="99", "Google Chrome";v="133", "Chromium";v="133"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
        'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36'
    }
    
    # 加载现有数据
    existing_df = load_existing_data()
    latest_draw = None
    if existing_df is not None and not existing_df.empty:
        latest_draw = existing_df.iloc[0]['期号']
        print(f"找到现有数据文件，最新期号: {latest_draw}")
    
    all_lottery_results = []
    page_no = 1
    found_existing = False
    
    try:
        while True:
            params = {
                'gameNo': '04',
                'provinceId': '0',
                'pageSize': '30',
                'isVerify': '1',
                'pageNo': str(page_no)
            }
            
            print(f"正在获取第 {page_no} 页数据...")
            response = requests.get(url, params=params, headers=headers)
            response.raise_for_status()
            data = response.json()
            
            # 获取当前页的数据
            current_page_results = data['value']['list']
            
            # 如果没有更多数据，退出循环
            if not current_page_results:
                break
                
            # 提取开奖结果
            for item in current_page_results:
                current_draw = str(item['lotteryDrawNum'])  # 转换为字符串
                
                # 如果找到已存在的期号，停止获取
                if latest_draw and int(current_draw) <= int(latest_draw):  # 转换为整数进行比较
                    found_existing = True
                    break
                    
                all_lottery_results.append({
                    '开奖时间': item['lotteryDrawTime'],
                    '期号': current_draw,
                    '中奖号码': item['lotteryDrawResult']
                })
            
            # 如果找到已存在的期号，退出循环
            if found_existing:
                break
                
            # 增加页码
            page_no += 1
            
            # 添加短暂延迟，避免请求过于频繁
            time.sleep(1)
        
        # 处理获取的数据
        if all_lottery_results:
            new_df = pd.DataFrame(all_lottery_results)
            
            if existing_df is not None and not existing_df.empty:
                # 合并新旧数据
                combined_df = pd.concat([new_df, existing_df])
                # 删除可能的重复数据
                combined_df = combined_df.drop_duplicates(subset=['期号'])
                # 按期号排序（先转换为整数再排序）
                combined_df['期号_排序'] = combined_df['期号'].astype(int)
                combined_df = combined_df.sort_values(by='期号_排序', ascending=False)
                combined_df = combined_df.drop('期号_排序', axis=1)
                combined_df.to_csv('qxc_results_all.csv', index=False, encoding='utf-8-sig')
                print(f"\n成功更新数据！新增 {len(new_df)} 期")
            else:
                # 如果没有现有数据，直接保存新数据
                new_df['期号_排序'] = new_df['期号'].astype(int)
                new_df = new_df.sort_values(by='期号_排序', ascending=False)
                new_df = new_df.drop('期号_排序', axis=1)
                new_df.to_csv('qxc_results_all.csv', index=False, encoding='utf-8-sig')
                print(f"\n成功获取所有数据！共计 {len(new_df)} 期")
            
            print(f"数据已保存到 qxc_results_all.csv")
        else:
            if existing_df is not None:
                print("数据已是最新，无需更新")
            else:
                print("未获取到任何数据")
        
    except requests.exceptions.RequestException as e:
        print(f"请求失败: {e}")
    except Exception as e:
        print(f"处理数据时出错: {e}")
        
    return all_lottery_results

if __name__ == "__main__":
    fetch_qxc_data() 