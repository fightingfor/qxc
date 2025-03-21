# 七星彩预测系统

这是一个基于历史数据分析的七星彩预测系统。该系统包含数据采集和预测分析两个主要模块，使用多维度特征分析和统计方法，对七星彩的开奖号码进行预测。

## 系统架构

系统由两个主要模块组成：

1. **数据采集模块** (qxc_crawler.py)
   - 从体彩官网API自动获取历史开奖数据
   - 支持分页获取全部历史数据
   - 数据包含：开奖时间、期号、中奖号码
   - 自动保存为CSV格式文件
   - 包含请求延迟和错误处理机制

2. **预测分析模块** (qxc_predictor.py)
   - 读取历史开奖数据
   - 进行多维度特征分析
   - 使用统计方法预测下一期号码
   - 生成多组推荐号码组合

## 预测策略

### 1. 分层数据分析

系统采用分层数据分析策略，根据数据的时效性分配不同的权重：

1. **最近数据**（100期）
   - 权重：0.5
   - 主要反映近期走势和热点号码
   - 对短期规律最敏感

2. **中期数据**（500期）
   - 权重：0.3
   - 平衡短期和长期特征
   - 反映中等周期的规律

3. **全量数据**（3000期）
   - 权重：0.2
   - 提供长期统计规律
   - 稳定性最好

### 2. 特征分析维度

#### 2.1 基础特征分析

1. **出现频率分析**
   - 统计每个号码在各位置的历史出现频率
   - 计算加权平均频率
   - 频率越高得分越高（最高100分）

2. **遗漏值分析**
   - 计算每个号码的遗漏期数
   - 遗漏值越大，出现概率相应提高
   - 每增加1期遗漏值加2分（上限40分）

3. **重复号码分析**
   - 分析相邻期号码的重复情况
   - 对重复号码施加惩罚机制
   - 重复出现扣除20分

4. **大小比例分析**
   - 统计号码大小比例的历史分布
   - 当比例失衡时，倾向于选择平衡的号码
   - 比例失衡时选择平衡号码加10分

5. **奇偶比例分析**
   - 统计号码奇偶比例的历史分布
   - 当比例失衡时，倾向于选择平衡的号码
   - 比例失衡时选择平衡号码加10分

6. **012路分析**
   - 分析号码除3余数的分布
   - 计算每个余数的历史概率
   - 根据历史概率加权（最高50分）

7. **跨度值分析**
   - 计算相邻期号码的差值分布
   - 根据跨度值的历史概率加权
   - 符合历史跨度规律加分（最高50分）

#### 2.2 时间序列分析

1. **移动平均分析**
   - 计算5期移动平均值
   - 分析数字走势
   - 上升趋势加20分，下降趋势减10分

2. **趋势分析**
   - 识别上升、下降和稳定趋势
   - 计算趋势强度
   - 根据趋势强度调整分数

3. **波动性分析**
   - 计算号码出现间隔的方差
   - 评估号码的稳定性
   - 波动性越大，扣除越多分数（每单位波动性减5分）

#### 2.3 周期性分析

1. **主要周期识别**
   - 分析号码出现的周期性
   - 计算周期强度
   - 根据周期强度和预期出现时间调整分数

2. **周期可靠性评估**
   - 计算周期的稳定性
   - 评估预测的可信度
   - 预期下期出现且周期强时加30分

3. **间隔分析**
   - 计算号码出现的间隔分布
   - 预测下次出现的最佳时机
   - 预期间隔过长时扣20分

#### 2.4 历史模式分析

1. **月度模式**
   - 分析每月号码分布规律
   - 计算当前月份的号码概率
   - 根据月度概率加权（最高40分）

2. **星期模式**
   - 分析每个星期的号码规律
   - 计算当前星期的号码概率
   - 根据星期概率加权（最高30分）

3. **季节模式**
   - 分析季节性号码分布
   - 计算当前季节的号码概率
   - 根据季节概率加权（最高35分）

4. **同期规律**
   - 分析历史同期号码规律（前5年）
   - 计算同期号码概率
   - 根据同期概率加权（最高50分）

#### 2.5 组合模式分析

1. **数字对分析**
   - 分析相邻位置的号码组合
   - 计算数字对的出现频率
   - 每次历史出现加2分

2. **三位组合分析**
   - 分析连续三个位置的号码组合
   - 识别高频组合模式
   - 根据组合频率调整分数

3. **位置相关性分析**
   - 计算不同位置之间的关联强度
   - 分析位置间的依赖关系
   - 根据相关性调整预测策略

### 3. 预测流程

1. **数据准备**
   - 获取分层历史数据
   - 初始化特征存储
   - 准备分析环境

2. **特征计算**
   - 分层计算各维度特征
   - 应用时间权重
   - 合并特征数据

3. **分数计算**
   - 基础分：100分
   - 叠加各维度特征得分
   - 归一化到0-100分

4. **号码选择**
   - 选择每个位置得分最高的三个号码
   - 计算预测置信度
   - 生成推荐组合

### 4. 组合生成策略

1. **置信度计算**
   - 基于前三名号码的平均得分
   - 考虑分数差异
   - 反映预测可靠性

2. **权重随机选择**
   - 根据置信度设置权重
   - 使用加权随机选择
   - 生成多样化组合

3. **平衡性控制**
   - 确保大小比例平衡
   - 保持奇偶比例合理
   - 避免极端组合

## 功能特点

1. **数据处理**
   - 自动采集历史开奖数据
   - 支持增量更新数据
   - 自动处理期号、开奖时间和中奖号码
   - 数据格式标准化处理

2. **数据分析**
   - 最新一期详细分析
   - 历史数据统计分析
   - 多维度特征提取
   - 号码关联性分析

3. **预测功能**
   - 预测下一期开奖号码
   - 提供每个位置的多个备选号码
   - 生成多组推荐号码组合
   - 计算预测置信度

## 使用方法

1. **环境要求**
   ```
   Python 3.x
   pandas
   numpy
   scikit-learn
   requests
   ```

2. **安装依赖**
   ```bash
   pip install -r requirements.txt
   ```

3. **执行步骤**
   
   步骤1：获取历史数据
   ```bash
   python qxc_crawler.py
   ```
   这个步骤会从体彩官网获取历史开奖数据，并保存为 qxc_results_all.csv 文件。
   如果已经有最新的数据文件，可以跳过这一步。

   步骤2：运行预测分析
   ```bash
   python qxc_predictor.py
   ```
   这个步骤会读取 qxc_results_all.csv 文件中的数据，进行分析并输出预测结果。
   每次想要获取预测结果时都需要执行这一步。

   注意：首次使用时必须按顺序执行步骤1和步骤2。后续使用时，如果只是想获取预测结果，直接执行步骤2即可。

## 输出说明

1. **最新一期分析**
   - 期号和开奖时间
   - 中奖号码
   - 和值和跨度值
   - 大小比、奇偶比
   - 012路比
   - 重复号码数量

2. **预测结果**
   - 下一期期号和开奖时间
   - 每个位置的推荐号码和置信度
   - 三组推荐号码组合

## 数据文件说明

**qxc_results_all.csv**
- 包含所有历史开奖数据
- 字段：开奖时间、期号、中奖号码
- 按期号降序排列
- UTF-8编码，带BOM头

## 注意事项

- 该预测系统仅供参考，不保证预测结果的准确性
- 购彩需理性，切勿沉迷
- 建议结合多种分析方法，理性决策
- 数据爬取请控制频率，避免对目标网站造成压力

## 后续优化方向

1. **算法优化**
   - 引入机器学习模型
   - 优化特征权重分配
   - 改进周期性分析方法
   - 增强组合模式分析

2. **功能扩展**
   - 添加图形化分析界面
   - 支持自定义参数配置
   - 增加历史预测效果分析
   - 提供API接口服务

3. **性能提升**
   - 优化数据处理效率
   - 改进缓存策略
   - 支持并行计算
   - 减少内存占用

4. **用户体验**
   - 添加可视化展示
   - 优化输出格式
   - 提供详细分析报告
   - 支持自定义策略 