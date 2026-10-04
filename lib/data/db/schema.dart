/// SQLite schema DDL 与种子数据。schemaVersion = 1。
library;

const int schemaVersion = 1;

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
];

/// settings 种子行。
const Map<String, String> settingsSeed = {
  'theme_mode': 'system',
  'coffee_price_fen': '1500',
};

/// settings 键名常量。
abstract final class SettingsKeys {
  static const themeMode = 'theme_mode';
  static const coffeePriceFen = 'coffee_price_fen';
}
