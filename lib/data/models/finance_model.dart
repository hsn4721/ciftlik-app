class FinanceModel {
  final int? id;
  final String type;
  final String category;
  final double amount;
  final String date;
  final String? description;
  final int? relatedAnimalId;
  final String? invoiceNo;
  final String? notes;
  final String period; // 'daily' veya 'monthly'
  final String createdAt;

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
  });

  bool get isIncome => type == 'Gelir';
  bool get isDaily => period == 'daily';

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
      );
}
