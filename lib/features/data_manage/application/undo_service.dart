/// 撤销/重做：对物品操作维护最近操作栈（上限 30 步）。
library;

/// 一步可撤销操作。
class UndoableOp {
  const UndoableOp({
    required this.description,
    required this.undo,
    required this.redo,
  });

  final String description;
  final Future<void> Function() undo;
  final Future<void> Function() redo;
}

class UndoService {
  static const _maxDepth = 30;

  final _undoStack = <UndoableOp>[];
  final _redoStack = <UndoableOp>[];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  String? get undoLabel =>
      _undoStack.isEmpty ? null : _undoStack.last.description;
  String? get redoLabel =>
      _redoStack.isEmpty ? null : _redoStack.last.description;

  /// 记录新操作（清空重做栈）。
  void push(UndoableOp op) {
    _undoStack.add(op);
    if (_undoStack.length > _maxDepth) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final op = _undoStack.removeLast();
    await op.undo();
    _redoStack.add(op);
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final op = _redoStack.removeLast();
    await op.redo();
    _undoStack.add(op);
  }
}
