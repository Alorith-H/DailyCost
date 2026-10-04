/// 应用常量。
library;

/// 版本号（设置页「关于」展示）。
const String kAppVersion = '0.2.0';

/// 分类芯片列表（固定内置，未来可自定义）。
const List<String> kCategories = [
  '餐饮',
  '交通',
  '居住',
  '数码',
  '订阅',
  '娱乐',
  '健康',
  '学习',
  '其他',
];

/// 默认分类。
const String kDefaultCategory = '其他';

/// 咖啡单价默认值（分）= ¥15.00。
const int kCoffeePriceFenDefault = 1500;

/// 标签数量上限。
const int kMaxTags = 8;

/// 单个标签长度上限。
const int kMaxTagLength = 12;

/// 名称长度上限。
const int kMaxNameLength = 40;

/// 备注长度上限。
const int kMaxNoteLength = 200;

/// 时长单位（试算器），换算天数与订阅周期一致。
const Map<String, int> kDurationUnitDays = {'天': 1, '周': 7, '月': 30, '年': 365};

/// 支持的货币（离线汇率表）。
const List<String> kCurrencies = [
  'CNY', 'USD', 'EUR', 'JPY', 'HKD', 'GBP', 'KRW', 'AUD', 'CAD', 'SGD',
];

/// TCO 附加成本分类。
const List<String> kCostCategories = ['维护', '能耗', '保险', '配件', '其他'];

/// 默认离线汇率：1 单位外币 ≈ X 元（可在设置中修改）。
const Map<String, double> kDefaultFxToCny = {
  'CNY': 1,
  'USD': 7.10,
  'EUR': 7.70,
  'JPY': 0.048,
  'HKD': 0.91,
  'GBP': 9.10,
  'KRW': 0.0052,
  'AUD': 4.70,
  'CAD': 5.20,
  'SGD': 5.30,
};
