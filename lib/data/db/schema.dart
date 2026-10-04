/// SQLite schema DDL 与种子数据。schemaVersion = 4。
///
/// v2: item_costs 表（TCO 附加成本）；items 增列 apr/installment/currency/photos。
/// v3: budgets 表（预算：日/周/月/年 + 分类子预算）。
/// v4: checkins 表（使用打卡）；items 增列 lifecycle/cooldown_until。
library;

const int schemaVersion = 4;

/// 建表语句（按依赖顺序执行）。
const List<String> schemaSql = [
  '''
CREATE TABLE items (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  name           TEXT    NOT NULL,
  price_fen      INTEGER NOT NULL CHECK (price_fen >= 0),
  residual_fen   INTEGER NOT NULL DEFAULT 0 CHECK (residual_fen >= 0),
  category       TEXT    NOT NULL DEFAULT '其他',
  purchase_date  TEXT    NOT NULL,
  end_date       TEXT,
  usage_days     INTEGER,
  total_uses     INTEGER,
  uses_per_day   REAL,
  total_hours    INTEGER,
  hours_per_day  REAL,
  cycle_unit     TEXT,
  cycle_length   INTEGER,
  calc_mode      TEXT    NOT NULL,
  depreciation   TEXT    NOT NULL DEFAULT 'straightLine',
  note           TEXT    NOT NULL DEFAULT '',
  apr_percent    REAL,
  installment_months INTEGER,
  currency       TEXT    NOT NULL DEFAULT 'CNY',
  photos         TEXT    NOT NULL DEFAULT '[]',
  lifecycle      TEXT    NOT NULL DEFAULT 'inUse',
  cooldown_until TEXT,
  created_at     TEXT    NOT NULL,
  updated_at     TEXT    NOT NULL,
  deleted_at     TEXT
)
''',
  'CREATE INDEX idx_items_deleted_at ON items(deleted_at)',
  'CREATE INDEX idx_items_active_dates ON items(purchase_date, end_date)',
  '''
CREATE TABLE tags (
  id   INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
)
''',
  '''
CREATE TABLE item_tags (
  item_id INTEGER NOT NULL,
  tag_id  INTEGER NOT NULL,
  PRIMARY KEY (item_id, tag_id),
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id)  REFERENCES tags(id)  ON DELETE CASCADE
)
''',
  'CREATE INDEX idx_item_tags_tag ON item_tags(tag_id)',
  '''
CREATE TABLE settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''',
  '''
CREATE TABLE item_costs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id    INTEGER NOT NULL,
  category   TEXT    NOT NULL DEFAULT '其他',
  amount_fen INTEGER NOT NULL CHECK (amount_fen >= 0),
  note       TEXT    NOT NULL DEFAULT '',
  created_at TEXT    NOT NULL,
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
)
''',
  'CREATE INDEX idx_item_costs_item ON item_costs(item_id)',
  '''
CREATE TABLE budgets (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  period     TEXT    NOT NULL,
  category   TEXT,
  amount_fen INTEGER NOT NULL CHECK (amount_fen > 0),
  created_at TEXT    NOT NULL,
  UNIQUE(period, category)
)
''',
  '''
CREATE TABLE checkins (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id   INTEGER NOT NULL,
  checked_on TEXT   NOT NULL,
  note      TEXT    NOT NULL DEFAULT '',
  UNIQUE(item_id, checked_on),
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
)
''',
  'CREATE INDEX idx_checkins_item ON checkins(item_id)',
];

/// v3 迁移语句（对 v2 库执行）。
const List<String> migrationV2ToV3 = [
  '''
CREATE TABLE budgets (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  period     TEXT    NOT NULL,
  category   TEXT,
  amount_fen INTEGER NOT NULL CHECK (amount_fen > 0),
  created_at TEXT    NOT NULL,
  UNIQUE(period, category)
)
''',
];

/// v4 迁移语句（对 v3 及更早的库执行）。
const List<String> migrationV3ToV4 = [
  "ALTER TABLE items ADD COLUMN lifecycle TEXT NOT NULL DEFAULT 'inUse'",
  'ALTER TABLE items ADD COLUMN cooldown_until TEXT',
  '''
CREATE TABLE checkins (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id   INTEGER NOT NULL,
  checked_on TEXT   NOT NULL,
  note      TEXT    NOT NULL DEFAULT '',
  UNIQUE(item_id, checked_on),
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
)
''',
  'CREATE INDEX idx_checkins_item ON checkins(item_id)',
];

/// v2 迁移语句（对 v1 库逐条执行）。
const List<String> migrationV1ToV2 = [
  "ALTER TABLE items ADD COLUMN apr_percent REAL",
  "ALTER TABLE items ADD COLUMN installment_months INTEGER",
  "ALTER TABLE items ADD COLUMN currency TEXT NOT NULL DEFAULT 'CNY'",
  "ALTER TABLE items ADD COLUMN photos TEXT NOT NULL DEFAULT '[]'",
  '''
CREATE TABLE item_costs (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id    INTEGER NOT NULL,
  category   TEXT    NOT NULL DEFAULT '其他',
  amount_fen INTEGER NOT NULL CHECK (amount_fen >= 0),
  note       TEXT    NOT NULL DEFAULT '',
  created_at TEXT    NOT NULL,
  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
)
''',
  'CREATE INDEX idx_item_costs_item ON item_costs(item_id)',
];

/// settings 种子行。
const Map<String, String> settingsSeed = {
  'theme_mode': 'system',
  'coffee_price_fen': '1500',
  'auto_update_check': '1',
};

/// settings 键名常量。
abstract final class SettingsKeys {
  static const themeMode = 'theme_mode';
  static const coffeePriceFen = 'coffee_price_fen';
  static const autoUpdateCheck = 'auto_update_check';
  static const fxRates = 'fx_rates';
  static const notifyExpiry = 'notify_expiry';
  static const notifyRenewal = 'notify_renewal';
  static const notifyWeekly = 'notify_weekly';
  static const notifyBackup = 'notify_backup';
}
