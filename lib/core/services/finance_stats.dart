import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/animal_repository.dart';
import '../constants/app_constants.dart';

/// Aylık finansal istatistikleri toparlayan yardımcı sınıf.
/// Birim ekonomi (₺/litre, hayvan başı vb.) ve ay-ay kıyası burada hesaplanır.
class FinanceStats {
  final FinanceRepository _finance;
  final AnimalRepository _animals;

  FinanceStats({FinanceRepository? finance, AnimalRepository? animals})
      : _finance = finance ?? FinanceRepository(),
        _animals = animals ?? AnimalRepository();

  /// Bir ay için tam özet: gelir, gider, net, marj, bir önceki ayla kıyas,
  /// birim ekonomi göstergeleri, kategori breakdown.
  Future<FinanceMonthReport> loadMonth(int year, int month) async {
    // Paralel sorgular
    final results = await Future.wait([
      _finance.getMonthTotals(year, month),
      _finance.getMonthTotals(_prevYear(year, month), _prevMonth(month)),
      _finance.getCategoryTotals(year, month, isIncome: true),
      _finance.getCategoryTotals(year, month, isIncome: false),
      _finance.getMonthMilkProduction(year, month),
      _animals.getTotalCount(),
    ]);

    final current = results[0] as Map<String, double>;
    final previous = results[1] as Map<String, double>;
    final incomeByCat = results[2] as Map<String, double>;
    final expenseByCat = results[3] as Map<String, double>;
    final milkLiters = results[4] as double;
    final animalCount = results[5] as int;

    final income = current['income'] ?? 0;
    final expense = current['expense'] ?? 0;
    final net = income - expense;
    final prevIncome = previous['income'] ?? 0;
    final prevExpense = previous['expense'] ?? 0;
    final prevNet = prevIncome - prevExpense;

    // Direkt maliyet = yem + vet + işçilik (profesyonel muhasebe "direct costs")
    final directCost = (expenseByCat[AppConstants.expenseFeed] ?? 0) +
        (expenseByCat[AppConstants.expenseVet] ?? 0) +
        (expenseByCat[AppConstants.expenseLabor] ?? 0);

    // ₺/litre süt — direkt maliyet ÷ üretilen litre
    final costPerLiter = milkLiters > 0 ? directCost / milkLiters : null;

    // Hayvan başı aylık gider
    final costPerAnimal = animalCount > 0 ? expense / animalCount : null;

    // Yem maliyet oranı: yem / toplam gider
    final feedExpense = expenseByCat[AppConstants.expenseFeed] ?? 0;
    final feedRatio = expense > 0 ? (feedExpense / expense) * 100 : null;

    // Kâr marjı %
    final margin = income > 0 ? (net / income) * 100 : null;

    return FinanceMonthReport(
      year: year,
      month: month,
      income: income,
      expense: expense,
      net: net,
      margin: margin,
      previousIncome: prevIncome,
      previousExpense: prevExpense,
      previousNet: prevNet,
      incomeByCategory: incomeByCat,
      expenseByCategory: expenseByCat,
      milkProductionLiters: milkLiters,
      animalCount: animalCount,
      costPerLiter: costPerLiter,
      costPerAnimal: costPerAnimal,
      feedCostRatio: feedRatio,
    );
  }

  int _prevMonth(int month) => month == 1 ? 12 : month - 1;
  int _prevYear(int year, int month) => month == 1 ? year - 1 : year;
}

/// Bir ayın finansal raporu — tüm KPI'lar tek DTO'da.
class FinanceMonthReport {
  final int year;
  final int month;
  final double income;
  final double expense;
  final double net;
  final double? margin;              // kâr marjı %
  final double previousIncome;
  final double previousExpense;
  final double previousNet;
  final Map<String, double> incomeByCategory;
  final Map<String, double> expenseByCategory;
  final double milkProductionLiters;
  final int animalCount;
  final double? costPerLiter;        // ₺/litre süt (direkt maliyet)
  final double? costPerAnimal;       // hayvan başı aylık gider
  final double? feedCostRatio;       // yem maliyeti / toplam gider %

  const FinanceMonthReport({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    required this.net,
    required this.margin,
    required this.previousIncome,
    required this.previousExpense,
    required this.previousNet,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.milkProductionLiters,
    required this.animalCount,
    required this.costPerLiter,
    required this.costPerAnimal,
    required this.feedCostRatio,
  });

  /// Yüzde değişim — önceki aya göre. null dönerse kıyas yapılamıyor demek
  /// (önceki ay verisi 0 veya yok).
  double? get incomeChange => _pctChange(income, previousIncome);
  double? get expenseChange => _pctChange(expense, previousExpense);
  double? get netChange => _pctChange(net, previousNet);

  double? _pctChange(double now, double prev) {
    if (prev == 0) return null;
    return ((now - prev) / prev.abs()) * 100;
  }
}
