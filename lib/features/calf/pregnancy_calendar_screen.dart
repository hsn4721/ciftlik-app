import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/calf_model.dart';
import '../../data/repositories/calf_repository.dart';

/// Gebelik Takvimi — aylık takvim görünümünde gebe hayvanların tahmini
/// doğum tarihleri noktalı olarak işaretlenir. Tıklanan günde doğum
/// bekleyen hayvanlar listelenir.
class PregnancyCalendarScreen extends StatefulWidget {
  const PregnancyCalendarScreen({super.key});

  @override
  State<PregnancyCalendarScreen> createState() => _PregnancyCalendarScreenState();
}

class _PregnancyCalendarScreenState extends State<PregnancyCalendarScreen> {
  final _repo = CalfRepository();
  List<BreedingModel> _pregnancies = [];
  DateTime _focusMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _repo.getAllBreedings();
      if (!mounted) return;
      setState(() {
        _pregnancies = all
            .where((b) => b.status == 'Gebe' && b.expectedBirthDate != null)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Belirli bir gün için doğum bekleyen hayvanlar.
  List<BreedingModel> _forDay(DateTime day) {
    return _pregnancies.where((b) {
      final d = DateTime.tryParse(b.expectedBirthDate!);
      if (d == null) return false;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();
  }

  /// Takvim görünen ayda doğum bekleyen toplam sayı.
  int _monthCount() {
    return _pregnancies.where((b) {
      final d = DateTime.tryParse(b.expectedBirthDate!);
      if (d == null) return false;
      return d.year == _focusMonth.year && d.month == _focusMonth.month;
    }).length;
  }

  void _prevMonth() {
    setState(() {
      _focusMonth = DateTime(_focusMonth.year, _focusMonth.month - 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _focusMonth = DateTime(_focusMonth.year, _focusMonth.month + 1);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedList = _selectedDay == null
        ? <BreedingModel>[]
        : _forDay(_selectedDay!);
    final monthCount = _monthCount();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Gebelik Takvimi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Column(children: [
              // Ay başlığı + navigation
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _prevMonth,
                  ),
                  Expanded(
                    child: Column(children: [
                      Text(
                        DateFormat('MMMM yyyy', 'tr_TR').format(_focusMonth),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (monthCount > 0)
                        Text('$monthCount hayvan doğum bekliyor',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            )),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextMonth,
                  ),
                ]),
              ),

              // Takvim grid
              _MonthGrid(
                month: _focusMonth,
                getCountForDay: (d) => _forDay(d).length,
                selectedDay: _selectedDay,
                onDaySelected: (d) => setState(() => _selectedDay = d),
              ),

              const Divider(height: 1),

              // Seçili gün detayı veya tüm ay özeti
              Expanded(
                child: _selectedDay != null
                    ? _DayDetail(day: _selectedDay!, items: selectedList)
                    : _MonthSummary(
                        month: _focusMonth,
                        all: _pregnancies,
                      ),
              ),
            ]),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final int Function(DateTime) getCountForDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  const _MonthGrid({
    required this.month,
    required this.getCountForDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Pazartesi=1..Pazar=7 → grid Pazartesi başı
    final leadingBlanks = (first.weekday - 1);
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(children: [
        // Hafta günleri
        Row(children: const ['Pzt','Sal','Çar','Per','Cum','Cmt','Paz']
            .map((d) => Expanded(child: Center(child: Text(d,
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey,
                    fontWeight: FontWeight.w700)))))
            .toList()),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Row(children: List.generate(7, (c) {
            final cellIdx = r * 7 + c;
            final dayNum = cellIdx - leadingBlanks + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const Expanded(child: SizedBox(height: 48));
            }
            final day = DateTime(month.year, month.month, dayNum);
            final count = getCountForDay(day);
            final isToday = day.year == today.year &&
                day.month == today.month && day.day == today.day;
            final isSelected = selectedDay != null &&
                selectedDay!.year == day.year &&
                selectedDay!.month == day.month &&
                selectedDay!.day == day.day;

            return Expanded(
              child: GestureDetector(
                onTap: () => onDaySelected(day),
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : isToday
                            ? AppColors.primaryGreen.withValues(alpha: 0.12)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: count > 0 && !isSelected
                        ? Border.all(color: AppColors.primaryGreen, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: count > 0 ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : count > 0
                                  ? AppColors.primaryGreen
                                  : AppColors.textDark,
                        ),
                      ),
                      if (count > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? AppColors.primaryGreen : Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          })),
      ]),
    );
  }
}

class _DayDetail extends StatelessWidget {
  final DateTime day;
  final List<BreedingModel> items;
  const _DayDetail({required this.day, required this.items});

  @override
  Widget build(BuildContext context) {
    final daysAway = day.difference(DateTime.now()).inDays;
    final label = DateFormat('d MMMM yyyy EEEE', 'tr_TR').format(day);

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.event_busy, size: 48, color: AppColors.textGrey),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Bu günde doğum bekleyen hayvan yok',
                style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
          ]),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: Row(children: [
          const Icon(Icons.event, color: AppColors.primaryGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: daysAway < 0
                  ? AppColors.errorRed.withValues(alpha: 0.12)
                  : daysAway <= 7
                      ? AppColors.gold.withValues(alpha: 0.12)
                      : AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              daysAway == 0
                  ? 'Bugün'
                  : daysAway < 0
                      ? '${-daysAway} gün gecikmiş'
                      : '$daysAway gün kaldı',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: daysAway < 0
                    ? AppColors.errorRed
                    : daysAway <= 7
                        ? AppColors.gold
                        : AppColors.primaryGreen,
              ),
            ),
          ),
        ]),
      ),
      ...items.map((b) => _PregnancyTile(item: b)),
    ]);
  }
}

class _MonthSummary extends StatelessWidget {
  final DateTime month;
  final List<BreedingModel> all;
  const _MonthSummary({required this.month, required this.all});

  @override
  Widget build(BuildContext context) {
    final monthItems = all.where((b) {
      final d = DateTime.tryParse(b.expectedBirthDate!);
      if (d == null) return false;
      return d.year == month.year && d.month == month.month;
    }).toList()
      ..sort((a, b) => a.expectedBirthDate!.compareTo(b.expectedBirthDate!));

    if (monthItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_month, size: 48, color: AppColors.textGrey),
            SizedBox(height: 12),
            Text('Bu ayda doğum bekleyen yok',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: Text(
          'Bu Ay Doğum Bekleyenler',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: AppColors.primaryGreen),
        ),
      ),
      ...monthItems.map((b) => _PregnancyTile(item: b)),
    ]);
  }
}

class _PregnancyTile extends StatelessWidget {
  final BreedingModel item;
  const _PregnancyTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final expDate = DateTime.tryParse(item.expectedBirthDate!);
    final daysAway = expDate?.difference(DateTime.now()).inDays ?? 0;
    final color = daysAway < 0
        ? AppColors.errorRed
        : daysAway <= 7
            ? AppColors.gold
            : AppColors.primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.child_friendly, color: color, size: 22),
        ),
        title: Text(
          item.animalEarTag ?? 'Hayvan #${item.animalId}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (item.animalName != null)
            Text(item.animalName!, style: const TextStyle(fontSize: 12)),
          Text(
            'Tahmini: ${expDate != null ? fmt.format(expDate) : "—"} · '
            'Tohumlama: ${fmt.format(DateTime.parse(item.breedingDate))}',
            style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
          ),
          if (item.bullBreed != null)
            Text('Boğa: ${item.bullBreed}',
                style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ]),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            daysAway == 0
                ? 'Bugün'
                : daysAway < 0
                    ? '${-daysAway}g gecikti'
                    : '$daysAway gün',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
