import '../../core/constants/app_constants.dart';

class FinanceModel {
  final int? id;
  final String type;           // 'Gelir' | 'Gider'
  final String category;       // Kategori (AppConstants.incomeCategories/expenseCategories)
  final double amount;
  final String date;           // 'yyyy-MM-dd'
  final String? description;
  final int? relatedAnimalId;
  final String? invoiceNo;
  final String? notes;
  final String period;         // 'daily' | 'monthly' — geriye uyumluluk (UI artık kullanmıyor)
  final String createdAt;

  // ─── Yeni alanlar (v9) ───────────────────────────────────────────────
  final String source;         // AppConstants.srcManual / srcFeedPurchase / ...
  final String? sourceRef;     // 'table:id' — ör. 'vaccines:45'
  final String paymentMethod;  // AppConstants.pmCash / pmBank / pmCard / pmDeferred
  final bool isPaid;           // true=ödendi/tahsil edildi, false=bekliyor
  final String? dueDate;       // 'yyyy-MM-dd' — vadeli ödeme son tarihi
  final double? vatRate;       // KDV oranı % (ör. 10.0). null=KDV'siz

  const FinanceModel({
    this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
    this.relatedAnimalId,
    this.invoiceNo,
    this.notes,
    this.period = 'monthly',
    required this.createdAt,
    this.source = AppConstants.srcManual,
    this.sourceRef,
    this.paymentMethod = AppConstants.pmCash,
    this.isPaid = true,
    this.dueDate,
    this.vatRate,
  });

  bool get isIncome => type == 'Gelir';
  bool get isDaily => period == 'daily';
  bool get isAuto => source != AppConstants.srcManual;
  bool get isPending => !isPaid;

  String get sourceLabel => AppConstants.srcModuleLabel[source] ?? 'Manuel';
  String get paymentLabel => AppConstants.paymentMethodLabel[paymentMethod] ?? 'Nakit';

  // KDV hariç tutar (vatRate varsa)
  double? get netAmount => vatRate == null ? null : amount / (1 + vatRate! / 100);
  double? get vatAmount => vatRate == null ? null : amount - netAmount!;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'category': category,
        'amount': amount,
        'date': date,
        'description': description,
        'relatedAnimalId': relatedAnimalId,
        'invoiceNo': invoiceNo,
        'notes': notes,
        'period': period,
        'createdAt': createdAt,
        'source': source,
        'sourceRef': sourceRef,
        'paymentMethod': paymentMethod,
        'isPaid': isPaid ? 1 : 0,
        'dueDate': dueDate,
        'vatRate': vatRate,
      };

  factory FinanceModel.fromMap(Map<String, dynamic> map) => FinanceModel(
        id: map['id'],
        type: map['type'],
        category: map['category'],
        amount: (map['amount'] as num).toDouble(),
        date: map['date'],
        description: map['description'],
        relatedAnimalId: map['relatedAnimalId'],
        invoiceNo: map['invoiceNo'],
        notes: map['notes'],
        period: (map['period'] as String?) ?? 'monthly',
        createdAt: map['createdAt'],
        source: (map['source'] as String?) ?? AppConstants.srcManual,
        sourceRef: map['sourceRef'] as String?,
        paymentMethod: (map['paymentMethod'] as String?) ?? AppConstants.pmCash,
        isPaid: (map['isPaid'] as int?) != 0,
        dueDate: map['dueDate'] as String?,
        vatRate: (map['vatRate'] as num?)?.toDouble(),
      );

  FinanceModel copyWith({
    int? id,
    String? type,
    String? category,
    double? amount,
    String? date,
    String? description,
    int? relatedAnimalId,
    String? invoiceNo,
    String? notes,
    String? period,
    String? createdAt,
    String? source,
    String? sourceRef,
    String? paymentMethod,
    bool? isPaid,
    String? dueDate,
    double? vatRate,
  }) =>
      FinanceModel(
        id: id ?? this.id,
        type: type ?? this.type,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        description: description ?? this.description,
        relatedAnimalId: relatedAnimalId ?? this.relatedAnimalId,
        invoiceNo: invoiceNo ?? this.invoiceNo,
        notes: notes ?? this.notes,
        period: period ?? this.period,
        createdAt: createdAt ?? this.createdAt,
        source: source ?? this.source,
        sourceRef: sourceRef ?? this.sourceRef,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        isPaid: isPaid ?? this.isPaid,
        dueDate: dueDate ?? this.dueDate,
        vatRate: vatRate ?? this.vatRate,
      );
}
