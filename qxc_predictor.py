import pandas as pd
import numpy as np
from datetime import datetime
from sklearn.preprocessing import LabelEncoder
from collections import defaultdict
import warnings
warnings.filterwarnings('ignore')

class QXCPredictor:
    def __init__(self):
        self.data = None
        self.processed_data = None
        self.position_data = None
        self.correlation_data = None
        self.historical_patterns = None
        
    def load_data(self, file_path):
        """加载历史数据"""
        self.data = pd.read_csv(file_path)
        # 将开奖时间转换为datetime类型
        self.data['开奖时间'] = pd.to_datetime(self.data['开奖时间'])
        # 按期号降序排序
        self.data = self.data.sort_values('期号', ascending=False)
        print(f"成功加载数据，共 {len(self.data)} 条记录")
        
    def preprocess_data(self):
        """数据预处理：将中奖号码拆分为独立的数字"""
        if self.data is None:
            raise ValueError("请先加载数据！")
            
        # 确保期号是字符串类型
        self.data['期号'] = self.data['期号'].astype(str)
            
        # 拆分中奖号码为列表
        numbers = self.data['中奖号码'].str.split(' ', expand=True)
        # 重命名列
        position_names = [f'位置{i+1}' for i in range(7)]
        numbers.columns = position_names
        
        # 转换为数值类型
        for col in position_names:
            numbers[col] = pd.to_numeric(numbers[col])
            
        # 合并数据
        self.processed_data = pd.concat([self.data, numbers], axis=1)
        
        # 添加时间特征
        self.processed_data['星期'] = self.processed_data['开奖时间'].dt.dayofweek
        self.processed_data['月份'] = self.processed_data['开奖时间'].dt.month
        self.processed_data['年份'] = self.processed_data['开奖时间'].dt.year
        
        print("数据预处理完成")
        
    def calculate_basic_features(self):
        """计算基础特征"""
        if self.processed_data is None:
            raise ValueError("请先进行数据预处理！")
            
        position_features = {}
        
        for i in range(7):
            position = f'位置{i+1}'
            features = {
                '出现频率': self._calculate_frequency(position),
                '遗漏值': self._calculate_missing_values(position),
                '上期重复': self._calculate_repeats(position),
                '大小比': self._calculate_big_small_ratio(position),
                '奇偶比': self._calculate_odd_even_ratio(position),
                '012路': self._calculate_012_way(position),
                '跨度值': self._calculate_span_value(position),
                '同期规律': self._calculate_same_period_pattern(position)
            }
            position_features[position] = features
            
        self.position_data = position_features
        self._calculate_number_correlations()
        print("基础特征计算完成")
        
    def _calculate_frequency(self, position):
        """计算每个数字在指定位置的出现频率"""
        freq = self.processed_data[position].value_counts().sort_index()
        total = len(self.processed_data)
        return (freq / total).to_dict()
        
    def _calculate_missing_values(self, position):
        """计算每个数字的遗漏值"""
        current_draw = self.processed_data[position].iloc[0]
        missing_values = defaultdict(int)
        
        # 初始化所有可能的数字
        max_number = 9 if position != '位置7' else 14
        for num in range(max_number + 1):
            missing_values[num] = 0
            
        # 计算遗漏值
        for num in self.processed_data[position]:
            for key in missing_values:
                if key != num:
                    missing_values[key] += 1
                else:
                    missing_values[key] = 0
                    
        return dict(missing_values)
        
    def _calculate_repeats(self, position):
        """计算与上期相同的情况"""
        repeats = defaultdict(int)
        numbers = self.processed_data[position].values
        
        for i in range(len(numbers)-1):
            if numbers[i] == numbers[i+1]:
                repeats[numbers[i]] += 1
                
        return dict(repeats)
        
    def _calculate_big_small_ratio(self, position):
        """计算大小比例"""
        numbers = self.processed_data[position]
        max_num = 9 if position != '位置7' else 14
        mid_point = max_num // 2
        
        big_count = sum(numbers > mid_point)
        small_count = sum(numbers <= mid_point)
        total = len(numbers)
        
        return {
            'big_ratio': big_count / total,
            'small_ratio': small_count / total
        }
        
    def _calculate_odd_even_ratio(self, position):
        """计算奇偶比例"""
        numbers = self.processed_data[position]
        odd_count = sum(numbers % 2 == 1)
        even_count = sum(numbers % 2 == 0)
        total = len(numbers)
        
        return {
            'odd_ratio': odd_count / total,
            'even_ratio': even_count / total
        }
        
    def _calculate_012_way(self, position):
        """计算012路分布"""
        numbers = self.processed_data[position]
        max_num = 9 if position != '位置7' else 14
        
        # 计算每个数字的除3余数
        remainders = numbers.apply(lambda x: x % 3)
        total = len(numbers)
        
        way_0 = sum(remainders == 0) / total
        way_1 = sum(remainders == 1) / total
        way_2 = sum(remainders == 2) / total
        
        return {
            'way_0': way_0,
            'way_1': way_1,
            'way_2': way_2
        }

    def _calculate_span_value(self, position):
        """计算跨度值（与上期号码的差值）"""
        numbers = self.processed_data[position].values
        spans = defaultdict(int)
        
        for i in range(len(numbers)-1):
            span = abs(numbers[i] - numbers[i+1])
            spans[span] += 1
            
        total = sum(spans.values())
        return {k: v/total for k, v in spans.items()}

    def _calculate_same_period_pattern(self, position):
        """分析历史同期规律"""
        try:
            current_period = str(self.processed_data['期号'].iloc[0])
            current_period_suffix = current_period[-3:] if len(current_period) >= 3 else current_period
            
            historical_same_period = self.processed_data[
                self.processed_data['期号'].str[-3:] == current_period_suffix
            ][position].values
            
            if len(historical_same_period) == 0:
                return {}
                
            # 统计同期号码的出现频率
            same_period_freq = {}
            for num in historical_same_period:
                same_period_freq[num] = same_period_freq.get(num, 0) + 1
                
            total = len(historical_same_period)
            return {k: v/total for k, v in same_period_freq.items()}
        except Exception as e:
            print(f"Warning: Error in calculating same period pattern for {position}: {str(e)}")
            return {}

    def _calculate_number_correlations(self):
        """计算号码之间的关联性"""
        correlations = {}
        
        # 计算相邻位置的号码关联
        for i in range(6):
            pos1 = f'位置{i+1}'
            pos2 = f'位置{i+2}'
            
            # 计算两个位置之间的条件概率
            joint_counts = defaultdict(lambda: defaultdict(int))
            total_counts = defaultdict(int)
            
            for _, row in self.processed_data.iterrows():
                num1 = row[pos1]
                num2 = row[pos2]
                joint_counts[num1][num2] += 1
                total_counts[num1] += 1
            
            # 转换为条件概率
            cond_probs = {}
            for num1 in total_counts:
                cond_probs[num1] = {
                    num2: count/total_counts[num1]
                    for num2, count in joint_counts[num1].items()
                }
            
            correlations[f'{pos1}-{pos2}'] = cond_probs
        
        self.correlation_data = correlations

    def analyze_latest_draw(self):
        """分析最新一期的数据（增强版）"""
        latest = self.processed_data.iloc[0]
        print("\n最新一期分析:")
        print(f"期号: {latest['期号']}")
        print(f"开奖时间: {latest['开奖时间']}")
        print(f"中奖号码: {latest['中奖号码']}")
        
        numbers = [latest[f'位置{i+1}'] for i in range(7)]
        
        # 基础统计
        print(f"和值: {sum(numbers)}")
        print(f"跨度值: {max(numbers) - min(numbers)}")
        
        # 大小比
        big_count = sum(n >= 5 for n in numbers[:-1]) + (numbers[-1] >= 7)
        small_count = 7 - big_count
        print(f"大小比: {big_count}:{small_count}")
        
        # 奇偶比
        odd_count = sum(n % 2 == 1 for n in numbers)
        even_count = 7 - odd_count
        print(f"奇偶比: {odd_count}:{even_count}")
        
        # 012路统计
        way_counts = [0, 0, 0]
        for n in numbers:
            way_counts[n % 3] += 1
        print(f"012路比: {way_counts[0]}:{way_counts[1]}:{way_counts[2]}")
        
        # 重复号码分析
        unique_nums = len(set(numbers))
        print(f"重复号码数: {7 - unique_nums}")

    def _calculate_span_score(self, num, features):
        """计算跨度值得分"""
        try:
            # 获取最近一期的号码
            latest_num = self.processed_data[features['position']].iloc[0]
            current_span = abs(num - latest_num)
            
            # 获取历史跨度值分布
            span_dist = features['跨度值']
            
            # 如果当前跨度值在历史分布中，使用其概率；否则使用最小概率
            score = span_dist.get(current_span, min(span_dist.values()) if span_dist else 0.1)
            
            return score
        except Exception as e:
            print(f"Warning: Error in calculating span score: {str(e)}")
            return 0.1

    def _predict_position(self, position):
        """预测指定位置的号码"""
        features = self.position_data[position]
        features['position'] = position
        max_number = 9 if position != '位置7' else 14
        scores = {}
        
        for num in range(max_number + 1):
            # 基础分数从100开始
            score = 100
            
            # 根据出现频率调整分数
            freq_score = features['出现频率'].get(num, 0) * 100
            score += freq_score
            
            # 根据遗漏值调整分数（遗漏值越大，分数越高，但有上限）
            missing_score = min(features['遗漏值'].get(num, 0), 20) * 2
            score += missing_score
            
            # 根据上期重复情况调整分数
            repeat_penalty = -20 if num in features['上期重复'] else 0
            score += repeat_penalty
            
            # 根据大小比调整分数
            size_ratio = features['大小比']
            if (num > max_number/2 and size_ratio['big_ratio'] < 0.4) or \
               (num <= max_number/2 and size_ratio['small_ratio'] < 0.4):
                score += 10
            
            # 根据奇偶比调整分数
            odd_even_ratio = features['奇偶比']
            if (num % 2 == 1 and odd_even_ratio['odd_ratio'] < 0.4) or \
               (num % 2 == 0 and odd_even_ratio['even_ratio'] < 0.4):
                score += 10
            
            # 根据012路调整分数
            way_score = features['012路'].get(f'way_{num % 3}', 0) * 50
            score += way_score
            
            # 根据跨度值调整分数
            span_score = self._calculate_span_score(num, features) * 50
            score += span_score
            
            # 根据同期规律调整分数
            period_score = 0
            if num in features['同期规律']:
                period_score = features['同期规律'][num] * 50
            score += period_score
            
            # 归一化分数到0-100之间
            scores[num] = max(0, min(100, score/5))
        
        # 选择得分最高的三个号码
        top_numbers = sorted(scores.items(), key=lambda x: x[1], reverse=True)[:3]
        selected_numbers = [num for num, _ in top_numbers]
        
        # 计算置信度（基于前三名的分数差异）
        confidence = sum(score for _, score in top_numbers) / (3 * 100)
        
        return selected_numbers, confidence

    def predict_next_draw(self):
        """预测下一期号码"""
        # 获取最新一期信息
        latest_draw = self.processed_data.iloc[0]
        next_draw_number = str(int(latest_draw['期号']) + 1)
        
        # 计算下一期开奖时间
        latest_date = latest_draw['开奖时间']
        days_to_add = 2 if latest_date.weekday() == 6 else 3 if latest_date.weekday() == 1 else 3
        next_draw_date = latest_date + pd.Timedelta(days=days_to_add)
        
        print(f"\n下一期预测 (期号: {next_draw_number}, 开奖时间: {next_draw_date.strftime('%Y-%m-%d')})")
        all_predictions = []
        all_confidences = []
        
        for i in range(7):
            position = f'位置{i+1}'
            numbers, confidence = self._predict_position(position)
            all_predictions.append(numbers)
            all_confidences.append(confidence)
            print(f"{position}: {numbers} (置信度: {confidence:.2f})")
        
        print("\n推荐号码组合:")
        combinations = []
        for _ in range(3):
            combination = []
            for pos_nums, conf in zip(all_predictions, all_confidences):
                # 根据置信度加权随机选择
                weights = [conf, (1-conf)/2, (1-conf)/2]
                number = np.random.choice(pos_nums, p=weights)
                combination.append(number)
            combinations.append(combination)
            print(f"组合 {len(combinations)}: {' '.join(map(str, combination))}")

if __name__ == "__main__":
    predictor = QXCPredictor()
    predictor.load_data('qxc_results_all.csv')
    predictor.preprocess_data()
    predictor.calculate_basic_features()
    predictor.analyze_latest_draw()
    predictor.predict_next_draw() 