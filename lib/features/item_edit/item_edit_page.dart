import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../domain/calc/calc_engine.dart';
import '../../domain/models/calc_inputs.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/item.dart';
import '../home/application/home_providers.dart';
import 'item_form_validators.dart';

/// 记一笔 / 编辑记录。
class ItemEditPage extends ConsumerStatefulWidget {
  const ItemEditPage.create({super.key}) : itemId = null;

  const ItemEditPage.edit({super.key, required this.itemId});

  /// 非空为编辑模式。
  final int? itemId;

  @override
  ConsumerState<ItemEditPage> createState() => _ItemEditPageState();
}

class _ItemEditPageState extends ConsumerState<ItemEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _residual;
  late final TextEditingController _usageDays;
  late final TextEditingController _totalUses;
  late final TextEditingController _usesPerDay;
  late final TextEditingController _totalHours;
  late final TextEditingController _hoursPerDay;
  late final TextEditingController _cycleLength;
  late final TextEditingController _note;
  late final TextEditingController _tagInput;

  String _category = kDefaultCategory;
  CalcMode _calcMode = CalcMode.fixedDays;
  DepreciationMethod _depreciation = DepreciationMethod.straightLine;
  CycleUnit _cycleUnit = CycleUnit.monthly;
  DateTime _purchaseDate = DateTime.now();
  DateTime? _endDate;
  final List<String> _tags = [];

  Item? _editing;
  var _loadingEdit = false;

  bool get _isEdit => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _price = TextEditingController();
    _residual = TextEditingController(text: '0');
    _usageDays = TextEditingController();
    _totalUses = TextEditingController();
    _usesPerDay = TextEditingController();
    _totalHours = TextEditingController();
    _hoursPerDay = TextEditingController();
    _cycleLength = TextEditingController(text: '1');
    _note = TextEditingController();
    _tagInput = TextEditingController();
    if (_isEdit) _loadForEdit();
  }

  Future<void> _loadForEdit() async {
    setState(() => _loadingEdit = true);
    final item = await ref
        .read(itemRepositoryProvider)
        .findById(widget.itemId!);
    if (!mounted) return;
    setState(() {
      _loadingEdit = false;
      if (item == null) return;
      _editing = item;
      _name.text = item.name;
      _price.text = item.price.toStringAsFixed(2);
      _residual.text = item.residual.toStringAsFixed(2);
      _category = item.category;
      _purchaseDate = item.purchaseDate;
      _endDate = item.endDate;
      _calcMode = item.calcMode;
      _depreciation = item.depreciation;
      _cycleUnit = item.cycleUnit ?? CycleUnit.monthly;
      _tags.addAll(item.tags);
      _usageDays.text = item.usageDays?.toString() ?? '';
      _totalUses.text = item.totalUses?.toString() ?? '';
      _usesPerDay.text = item.usesPerDay?.toString() ?? '';
      _totalHours.text = item.totalHours?.toString() ?? '';
      _hoursPerDay.text = item.hoursPerDay?.toString() ?? '';
      _cycleLength.text = item.cycleLength?.toString() ?? '1';
      _note.text = item.note;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name, _price, _residual, _usageDays, _totalUses, _usesPerDay,
      _totalHours, _hoursPerDay, _cycleLength, _note, _tagInput,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _loadingEdit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(_isEdit ? '编辑' : '记一笔'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              maxLength: kMaxNameLength,
              decoration: const InputDecoration(labelText: '名称'),
              validator: validateName,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '价格', prefixText: '¥ '),
              validator: validatePrice,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _residual,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '残值',
                helperText: '用完后还值多少钱（可填 0）',
                prefixText: '¥ ',
                errorText: _residualWarning(),
              ),
              validator: validateResidual,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _label('分类'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kCategories)
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _label('购买日期'),
            _DateField(
              date: _purchaseDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _purchaseDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _purchaseDate = picked);
              },
            ),
            const SizedBox(height: 12),
            _label('计算方式'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in CalcMode.values)
                  ChoiceChip(
                    label: Text(_modeLabel(m)),
                    selected: _calcMode == m,
                    onSelected: (_) => setState(() => _calcMode = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ..._modeFields(),
            const SizedBox(height: 12),
            _label('折旧方式'),
            SegmentedButton<DepreciationMethod>(
              segments: const [
                ButtonSegment(
                  value: DepreciationMethod.straightLine,
                  label: Text('直线折旧'),
                ),
                ButtonSegment(
                  value: DepreciationMethod.decliningBalance,
                  label: Text('余额递减'),
                ),
              ],
              selected: {_depreciation},
              onSelectionChanged: (s) =>
                  setState(() => _depreciation = s.first),
            ),
            const SizedBox(height: 4),
            Text(
              '只影响卡片上的剩余价值曲线',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLength: kMaxNoteLength,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '备注'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _label('标签'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in _tags)
                  InputChip(
                    label: Text(tag),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                  ),
              ],
            ),
            if (_tags.length < kMaxTags)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagInput,
                      maxLength: kMaxTagLength,
                      decoration: const InputDecoration(
                        hintText: '输入标签后回车添加',
                        counterText: '',
                      ),
                      onSubmitted: _addTag,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addTag(_tagInput.text),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            _LivePreviewCard(inputs: _currentInputs()),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _modeLabel(CalcMode m) => switch (m) {
    CalcMode.fixedDays => '固定天数',
    CalcMode.endDate => '到期日',
    CalcMode.subscription => '订阅周期',
    CalcMode.actualDays => '实际天数',
    CalcMode.perUse => '按次',
    CalcMode.perHour => '按小时',
  };

  String? _residualWarning() {
    final price = double.tryParse(_price.text.trim());
    final residual = double.tryParse(_residual.text.trim());
    if (price != null && residual != null && residual > price) {
      return '残值高于价格';
    }
    return null;
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

  List<Widget> _modeFields() {
    switch (_calcMode) {
      case CalcMode.fixedDays:
        return [
          TextFormField(
            controller: _usageDays,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '使用天数'),
            validator: (v) => validatePositiveInt(v, label: '使用天数'),
            onChanged: (_) => setState(() {}),
          ),
        ];
      case CalcMode.endDate:
        return [
          _label('到期日'),
          _DateField(
            date: _endDate,
            placeholder: '选择到期日',
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate ?? _purchaseDate.add(const Duration(days: 30)),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _endDate = picked);
            },
          ),
          if (_endDateError() != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _endDateError()!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ];
      case CalcMode.subscription:
        return [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<CycleUnit>(
                  initialValue: _cycleUnit,
                  decoration: const InputDecoration(labelText: '周期'),
                  items: const [
                    DropdownMenuItem(value: CycleUnit.weekly, child: Text('每周')),
                    DropdownMenuItem(value: CycleUnit.monthly, child: Text('每月')),
                    DropdownMenuItem(value: CycleUnit.yearly, child: Text('每年')),
                  ],
                  onChanged: (v) =>
                      setState(() => _cycleUnit = v ?? CycleUnit.monthly),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cycleLength,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '周期数'),
                  validator: (v) => validatePositiveInt(v, label: '周期数'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ];
      case CalcMode.actualDays:
        return [
          Text(
            '适合长期使用的东西，日均每天自动重算',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ];
      case CalcMode.perUse:
        return [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _totalUses,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '预估总次数'),
                  validator: (v) => validatePositiveInt(v, label: '预估总次数'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _usesPerDay,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '每日次数'),
                  validator: (v) => validatePositiveDouble(v, label: '每日次数'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ];
      case CalcMode.perHour:
        return [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _totalHours,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '预估总小时'),
                  validator: (v) => validatePositiveInt(v, label: '预估总小时'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _hoursPerDay,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '每日小时'),
                  validator: (v) => validatePositiveDouble(v, label: '每日小时'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ];
    }
  }

  String? _endDateError() {
    if (_calcMode != CalcMode.endDate || _endDate == null) return null;
    if (_endDate!.difference(_purchaseDate).inDays < 1) {
      return '到期日须晚于购买日';
    }
    return null;
  }

  CalcInputs _currentInputs() => CalcInputs(
    price: double.tryParse(_price.text.trim()) ?? 0,
    residual: double.tryParse(_residual.text.trim()) ?? 0,
    mode: _calcMode,
    depreciation: _depreciation,
    purchaseDate: _purchaseDate,
    endDate: _calcMode == CalcMode.endDate ? _endDate : null,
    usageDays: int.tryParse(_usageDays.text.trim()),
    totalUses: int.tryParse(_totalUses.text.trim()),
    usesPerDay: double.tryParse(_usesPerDay.text.trim()),
    totalHours: int.tryParse(_totalHours.text.trim()),
    hoursPerDay: double.tryParse(_hoursPerDay.text.trim()),
    cycleUnit: _calcMode == CalcMode.subscription ? _cycleUnit : null,
    cycleLength: int.tryParse(_cycleLength.text.trim()),
  );

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    if (tag.length > kMaxTagLength || _tags.length >= kMaxTags) return;
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
      _tagInput.clear();
    });
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    final endDateError = _endDateError();
    if (!formOk || endDateError != null) return;

    // 引擎校验兜底（error 阻断，warning 不阻断）
    final issues = validateInputs(_currentInputs());
    final blocking = issues
        .where((e) => e.severity == CalcIssueSeverity.error)
        .toList();
    if (blocking.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocking.first.messageZh)),
      );
      return;
    }

    final draft = ItemDraft(
      name: _name.text.trim(),
      price: double.parse(_price.text.trim()),
      residual: double.tryParse(_residual.text.trim()) ?? 0,
      category: _category,
      purchaseDate: _purchaseDate,
      endDate: _calcMode == CalcMode.endDate ? _endDate : null,
      usageDays: _calcMode == CalcMode.fixedDays
          ? int.tryParse(_usageDays.text.trim())
          : null,
      totalUses: _calcMode == CalcMode.perUse
          ? int.tryParse(_totalUses.text.trim())
          : null,
      usesPerDay: _calcMode == CalcMode.perUse
          ? double.tryParse(_usesPerDay.text.trim())
          : null,
      totalHours: _calcMode == CalcMode.perHour
          ? int.tryParse(_totalHours.text.trim())
          : null,
      hoursPerDay: _calcMode == CalcMode.perHour
          ? double.tryParse(_hoursPerDay.text.trim())
          : null,
      cycleUnit: _calcMode == CalcMode.subscription ? _cycleUnit : null,
      cycleLength: _calcMode == CalcMode.subscription
          ? int.tryParse(_cycleLength.text.trim())
          : null,
      calcMode: _calcMode,
      depreciation: _depreciation,
      note: _note.text.trim(),
      tags: List.of(_tags),
    );

    final notifier = ref.read(itemsProvider.notifier);
    if (_isEdit) {
      final original = _editing!;
      await notifier.updateItem(
        original.copyWith(
          name: draft.name,
          price: draft.price,
          residual: draft.residual,
          category: draft.category,
          purchaseDate: draft.purchaseDate,
          endDate: draft.endDate,
          usageDays: draft.usageDays,
          totalUses: draft.totalUses,
          usesPerDay: draft.usesPerDay,
          totalHours: draft.totalHours,
          hoursPerDay: draft.hoursPerDay,
          cycleUnit: draft.cycleUnit,
          cycleLength: draft.cycleLength,
          calcMode: draft.calcMode,
          depreciation: draft.depreciation,
          note: draft.note,
          tags: draft.tags,
        ),
      );
    } else {
      await notifier.addItem(draft);
    }
    if (!mounted) return;
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
  }

  Future<void> _confirmDelete() async {
    final item = _editing;
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text('「${item.name}」将移入回收站（后续版本提供恢复入口）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(itemsProvider.notifier).softDelete(item.id);
    if (!mounted) return;
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「${item.name}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => ref.read(itemsProvider.notifier).restore(item.id),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap, this.placeholder});

  final DateTime? date;
  final VoidCallback onTap;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          hintText: placeholder,
        ),
        child: Text(
          date == null ? (placeholder ?? '') : dateLong(date!),
          style: date == null
              ? theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _LivePreviewCard extends StatelessWidget {
  const _LivePreviewCard({required this.inputs});

  final CalcInputs inputs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = calculate(inputs);
    final String detail = switch (inputs.mode) {
      CalcMode.actualDays => '日均随天数变化',
      CalcMode.subscription => '每 ${result.totalDays?.toInt() ?? 0} 天',
      _ => '共 ${result.totalDays?.toInt() ?? 0} 天',
    };

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '日均 ${money(result.dailyCost)}',
                  style: theme.textTheme.moneyInline,
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.trending_down, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
