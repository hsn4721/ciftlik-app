import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/finance_repository.dart';
import '../../shared/widgets/empty_state.dart';

const _incomeColor = Color(0xFF2E7D32);
final _expenseColor = AppColors.errorRed;
final _fmt = NumberFormat('#,##0.00', 'tr_TR');
final _fmtShort = NumberFormat.compactCurrency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

class AnalysisTab extends StatefulWidget {
  final int year;
  final int month;
  final Map<String, double> incomeByCategory;
  final Map<String, double> expenseByCategory;

  const AnalysisTab({
    super.key,
    required this.year,
    required this.month,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  final _repo = FinanceRepository();
  List<DailyCashflowPoint> _daily = [];
  List<MonthlyCashflowPoint> _monthly = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final results = await Future.wait([
      _repo.getDailyCashflow(30),
      _repo.getLastMonthsCashflow(6),
    ]);
    if (!mounted) return;
    setState(() {
      _daily = results[0] as List<DailyCashflowPoint>;
      _monthly = results[1] as List<MonthlyCashflowPoint>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final hasAny = _daily.any((d) => d.income > 0 || d.expense > 0) ||
        widget.incomeByCategory.isNotEmpty ||
        widget.expenseByCategory.isNotEmpty;

    if (!hasAny) {
      return const Center(
        child: EmptyState(
          icon: Icons.insights,
          title: 'Analiz İçin Veri Yok',
          subtitle: 'Birkaç gelir/gider kaydı girdikten sonra grafikler burada görünecek.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _CashflowLineCard(points: _daily),
          const SizedBox(height: 12),
          _IncomePieCard(totals: widget.incomeByCategory),
          const SizedBox(height: 12),
          _MonthlyBarCard(points: _monthly),
          const SizedBox(height: 12),
          _ExpensePieCard(totals: widget.expenseByCategory),
        ],
      ),
    );
  }
}

// ─── Card Wrapper ────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─── Nakit Akışı Line Chart ──────────────────────────────────────────────────

class _CashflowLineCard extends StatelessWidget {
  final List<DailyCashflowPoint> points;
  const _CashflowLineCard({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _ChartCard(
        title: 'Nakit Akışı',
        subtitle: 'Son 30 gün günlük net kâr/zarar',
        child: SizedBox(height: 160, child: Center(child: Text('Veri yok', style: TextStyle(color: AppColors.textGrey)))),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].net));
    }

    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    if (maxY == minY) { maxY += 100; minY -= 100; }
    // Hafif pay bırak
    final pad = (maxY - minY) * 0.15;
    maxY += pad;
    minY -= pad;

    final totalNet = points.fold(0.0, (s, p) => s + p.net);
    final netColor = totalNet >= 0 ? _incomeColor : _expenseColor;

    return _ChartCard(
      title: 'Nakit Akışı',
      subtitle: 'Son 30 gün günlük net',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: netColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${totalNet >= 0 ? '+' : ''}₺${_fmt.format(totalNet)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: netColor),
        ),
      ),
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 4,
              getDrawingHorizontalLine: (v) => FlLine(
                color: v == 0 ? AppColors.textGrey.withValues(alpha: 0.4) : Colors.grey.shade200,
                strokeWidth: v == 0 ? 1 : 0.5,
                dashArray: v == 0 ? null : [3, 3],
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 46,
                  interval: (maxY - minY) / 4,
                  getTitlesWidget: (value, meta) => Text(
                    _fmtShort.format(value),
                    style: const TextStyle(fontSize: 9, color: AppColors.textGrey),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: (points.length / 5).floorToDouble().clamp(1, 30),
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                    if (idx % ((points.length / 5).floor().clamp(1, 30)) != 0 && idx != points.length - 1) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('d MMM', 'tr_TR').format(points[idx].date),
                        style: const TextStyle(fontSize: 9, color: AppColors.textGrey),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.2,
                color: AppColors.primaryGreen,
                barWidth: 2.2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryGreen.withValues(alpha: 0.25),
                      AppColors.primaryGreen.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.textDark.withValues(alpha: 0.9),
                getTooltipItems: (spots) => spots.map((s) {
                  final p = points[s.spotIndex];
                  final date = DateFormat('d MMM', 'tr_TR').format(p.date);
                  final color = p.net >= 0 ? const Color(0xFF81C784) : const Color(0xFFEF9A9A);
                  return LineTooltipItem(
                    '$date\n${p.net >= 0 ? '+' : ''}₺${_fmt.format(p.net)}',
                    TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Aylık Bar Chart (Son 6 Ay) ──────────────────────────────────────────────

class _MonthlyBarCard extends StatelessWidget {
  final List<MonthlyCashflowPoint> points;
  const _MonthlyBarCard({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _ChartCard(
        title: 'Aylık Gelir & Gider',
        subtitle: 'Son 6 ay karşılaştırma',
        child: SizedBox(height: 180, child: Center(child: Text('Veri yok', style: TextStyle(color: AppColors.textGrey)))),
      );
    }

    double maxY = 0;
    for (final p in points) {
      if (p.income > maxY) maxY = p.income;
      if (p.expense > maxY) maxY = p.expense;
    }
    if (maxY == 0) maxY = 100;
    maxY = maxY * 1.2;

    return _ChartCard(
      title: 'Aylık Gelir & Gider',
      subtitle: 'Son 6 ay karşılaştırma',
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 0.5, dashArray: [3, 3]),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 46,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) => Text(
                    _fmtShort.format(value),
                    style: const TextStyle(fontSize: 9, color: AppColors.textGrey),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                    final d = DateTime(points[idx].year, points[idx].month, 1);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('MMM', 'tr_TR').format(d),
                        style: const TextStyle(fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barGroups: [
              for (int i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 4,
                  barRods: [
                    BarChartRodData(
                      toY: points[i].income,
                      color: _incomeColor,
                      width: 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                    BarChartRodData(
                      toY: points[i].expense,
                      color: _expenseColor,
                      width: 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ],
                ),
            ],
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.textDark.withValues(alpha: 0.9),
                getTooltipItem: (group, groupIdx, rod, rodIdx) {
                  final p = points[group.x];
                  final label = rodIdx == 0 ? 'Gelir' : 'Gider';
                  final color = rodIdx == 0 ? const Color(0xFF81C784) : const Color(0xFFEF9A9A);
                  final dateLabel = DateFormat('MMM yyyy', 'tr_TR').format(DateTime(p.year, p.month, 1));
                  return BarTooltipItem(
                    '$dateLabel\n$label: ₺${_fmt.format(rod.toY)}',
                    TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Gelir Pie ───────────────────────────────────────────────────────────────

class _IncomePieCard extends StatelessWidget {
  final Map<String, double> totals;
  const _IncomePieCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return const _ChartCard(
        title: 'Gelir Dağılımı',
        subtitle: 'Bu ay kategori bazlı',
        child: SizedBox(height: 160, child: Center(child: Text('Bu ay gelir yok', style: TextStyle(color: AppColors.textGrey)))),
      );
    }
    return _CategoryPieCard(
      title: 'Gelir Dağılımı',
      subtitle: 'Bu ay kategori bazlı',
      totals: totals,
      baseColor: _incomeColor,
    );
  }
}

class _ExpensePieCard extends StatelessWidget {
  final Map<String, double> totals;
  const _ExpensePieCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return const _ChartCard(
        title: 'Gider Dağılımı',
        subtitle: 'Bu ay kategori bazlı',
        child: SizedBox(height: 160, child: Center(child: Text('Bu ay gider yok', style: TextStyle(color: AppColors.textGrey)))),
      );
    }
    return _CategoryPieCard(
      title: 'Gider Dağılımı',
      subtitle: 'Bu ay kategori bazlı',
      totals: totals,
      baseColor: _expenseColor,
    );
  }
}

class _CategoryPieCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Map<String, double> totals;
  final Color baseColor;

  const _CategoryPieCard({
    required this.title,
    required this.subtitle,
    required this.totals,
    required this.baseColor,
  });

  @override
  State<_CategoryPieCard> createState() => _CategoryPieCardState();
}

class _CategoryPieCardState extends State<_CategoryPieCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final total = widget.totals.values.fold(0.0, (s, v) => s + v);
    final sorted = widget.totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return _ChartCard(
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: Text('₺${_fmt.format(total)}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.baseColor)),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 44,
                startDegreeOffset: -90,
                sections: [
                  for (int i = 0; i < sorted.length; i++)
                    PieChartSectionData(
                      value: sorted[i].value,
                      color: _colorForIndex(i, widget.baseColor),
                      radius: _touched == i ? 58 : 50,
                      title: total > 0
                          ? '${(sorted[i].value / total * 100).toStringAsFixed(0)}%'
                          : '',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                ],
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touched = null;
                        return;
                      }
                      _touched = response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Legend
          ...sorted.asMap().entries.map((e) {
            final idx = e.key;
            final item = e.value;
            final color = _colorForIndex(idx, widget.baseColor);
            final pct = total > 0 ? (item.value / total * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.key, style: const TextStyle(fontSize: 12))),
                  Text('₺${_fmt.format(item.value)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 44,
                    child: Text('%${pct.toStringAsFixed(1)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Base color'dan türeyen farklı ton paletine çevirir.
  Color _colorForIndex(int i, Color base) {
    const palette = [
      Color(0xFF1B5E20), Color(0xFFE65100), Color(0xFF1565C0),
      Color(0xFF6A1B9A), Color(0xFFAD1457), Color(0xFF00838F),
      Color(0xFF4E342E), Color(0xFF455A64),
    ];
    // Kategoriye özel renk varsa al, yoksa palet
    return palette[i % palette.length];
  }
}
