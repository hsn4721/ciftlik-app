class BulkMilkingModel {
  final int? id;
  final String session;
  final String date;
  final int animalCount;
  final double totalAmount;
  final String? notes;
  final String createdAt;

  const BulkMilkingModel({
    this.id,
    required this.session,
    required this.date,
    required this.animalCount,
    required this.totalAmount,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'session': session,
        'date': date,
        'animalCount': animalCount,
        'totalAmount': totalAmount,
        'notes': notes,
        'createdAt': createdAt,
      };

  factory BulkMilkingModel.fromMap(Map<String, dynamic> map) => BulkMilkingModel(
        id: map['id'],
        session: map['session'],
        date: map['date'],
        animalCount: map['animalCount'] as int,
        totalAmount: (map['totalAmount'] as num).toDouble(),
        notes: map['notes'],
        createdAt: map['createdAt'],
      );
}

class TankLogModel {
  final int? id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String? notes;
  final String date;
  final String createdAt;

  const TankLogModel({
    this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.notes,
    required this.date,
    required this.createdAt,
  });

  bool get isAddition => amount > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'balanceAfter': balanceAfter,
        'notes': notes,
        'date': date,
        'createdAt': createdAt,
      };

  factory TankLogModel.fromMap(Map<String, dynamic> map) => TankLogModel(
        id: map['id'],
        type: map['type'],
        amount: (map['amount'] as num).toDouble(),
        balanceAfter: (map['balanceAfter'] as num).toDouble(),
        notes: map['notes'],
        date: map['date'],
        createdAt: map['createdAt'],
      );
}
