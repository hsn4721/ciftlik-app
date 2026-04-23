class FeedStockModel {
  final int? id;
  final String name;
  final String type;
  final double quantity;
  final String unit;
  final double? unitPrice;
  final double? minQuantity;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const FeedStockModel({
    this.id,
    required this.name,
    required this.type,
    required this.quantity,
    required this.unit,
    this.unitPrice,
    this.minQuantity,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLow => minQuantity != null && quantity <= minQuantity!;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'minQuantity': minQuantity,
    'notes': notes,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory FeedStockModel.fromMap(Map<String, dynamic> m) => FeedStockModel(
    id: m['id'],
    name: m['name'],
    type: m['type'],
    quantity: (m['quantity'] as num).toDouble(),
    unit: m['unit'],
    unitPrice: m['unitPrice'] != null ? (m['unitPrice'] as num).toDouble() : null,
    minQuantity: m['minQuantity'] != null ? (m['minQuantity'] as num).toDouble() : null,
    notes: m['notes'],
    createdAt: m['createdAt'],
    updatedAt: m['updatedAt'],
  );

  FeedStockModel copyWith({double? quantity, double? unitPrice, String? notes, double? minQuantity}) => FeedStockModel(
    id: id,
    name: name,
    type: type,
    quantity: quantity ?? this.quantity,
    unit: unit,
    unitPrice: unitPrice ?? this.unitPrice,
    minQuantity: minQuantity ?? this.minQuantity,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: DateTime.now().toIso8601String(),
  );
}

class FeedTransactionModel {
  final int? id;
  final int stockId;
  final String stockName;
  final String transactionType; // 'Giriş' | 'Çıkış' | 'Sabah Yemi' | 'Akşam Yemi'
  final double quantity;
  final String unit;
  final double? unitPrice;
  final String date;
  final String? notes;
  final String createdAt;

  const FeedTransactionModel({
    this.id,
    required this.stockId,
    required this.stockName,
    required this.transactionType,
    required this.quantity,
    required this.unit,
    this.unitPrice,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  bool get isEntry => transactionType == 'Giriş';
  bool get isFeeding => transactionType == 'Sabah Yemi' || transactionType == 'Akşam Yemi';
  double? get totalCost => unitPrice != null ? quantity * unitPrice! : null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'stockId': stockId,
    'transactionType': transactionType,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'date': date,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory FeedTransactionModel.fromMap(Map<String, dynamic> m) => FeedTransactionModel(
    id: m['id'],
    stockId: m['stockId'],
    stockName: m['stockName'] ?? '',
    transactionType: m['transactionType'],
    quantity: (m['quantity'] as num).toDouble(),
    unit: m['unit'],
    unitPrice: m['unitPrice'] != null ? (m['unitPrice'] as num).toDouble() : null,
    date: m['date'],
    notes: m['notes'],
    createdAt: m['createdAt'],
  );
}

class FeedPlanModel {
  final int? id;
  final int stockId;
  final String stockName;
  final String unit;
  final double morningAmount;
  final double eveningAmount;
  final String updatedAt;

  const FeedPlanModel({
    this.id,
    required this.stockId,
    required this.stockName,
    required this.unit,
    required this.morningAmount,
    required this.eveningAmount,
    required this.updatedAt,
  });

  double get dailyAmount => morningAmount + eveningAmount;

  Map<String, dynamic> toMap() => {
    'id': id,
    'stockId': stockId,
    'morningAmount': morningAmount,
    'eveningAmount': eveningAmount,
    'updatedAt': updatedAt,
  };

  factory FeedPlanModel.fromMap(Map<String, dynamic> m) => FeedPlanModel(
    id: m['id'],
    stockId: m['stockId'],
    stockName: m['stockName'] ?? '',
    unit: m['unit'] ?? '',
    morningAmount: (m['morningAmount'] as num).toDouble(),
    eveningAmount: (m['eveningAmount'] as num).toDouble(),
    updatedAt: m['updatedAt'],
  );
}

class FeedSessionModel {
  final int? id;
  final String date;
  final String session; // 'Sabah' | 'Akşam'
  final double? totalCost;
  final String? notes;
  final String createdAt;

  const FeedSessionModel({
    this.id,
    required this.date,
    required this.session,
    this.totalCost,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'session': session,
    'totalCost': totalCost,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory FeedSessionModel.fromMap(Map<String, dynamic> m) => FeedSessionModel(
    id: m['id'],
    date: m['date'],
    session: m['session'],
    totalCost: m['totalCost'] != null ? (m['totalCost'] as num).toDouble() : null,
    notes: m['notes'],
    createdAt: m['createdAt'],
  );
}
