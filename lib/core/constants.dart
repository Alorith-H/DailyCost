/// 应用常量。
library;

/// 版本号（设置页「关于」展示）。
const String kAppVersion = '0.1.0';

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
