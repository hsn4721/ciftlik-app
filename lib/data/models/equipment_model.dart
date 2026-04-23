class EquipmentModel {
  final int? id;
  final String name;
  final String category;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String status;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final String? notes;
  final String createdAt;

  const EquipmentModel({
    this.id,
    required this.name,
    required this.category,
    this.brand,
    this.model,
    this.serialNumber,
    this.purchaseDate,
    this.purchasePrice,
    required this.status,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.notes,
    required this.createdAt,
  });

  bool get isMaintenanceDue {
    if (nextMaintenanceDate == null) return false;
    return nextMaintenanceDate!.isBefore(DateTime.now().add(const Duration(days: 7)));
  }

  bool get isMaintenanceOverdue {
    if (nextMaintenanceDate == null) return false;
    return nextMaintenanceDate!.isBefore(DateTime.now());
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'brand': brand,
    'model': model,
    'serialNumber': serialNumber,
    'purchaseDate': purchaseDate?.toIso8601String().split('T').first,
    'purchasePrice': purchasePrice,
    'status': status,
    'lastMaintenanceDate': lastMaintenanceDate?.toIso8601String().split('T').first,
    'nextMaintenanceDate': nextMaintenanceDate?.toIso8601String().split('T').first,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory EquipmentModel.fromMap(Map<String, dynamic> m) => EquipmentModel(
    id: m['id'],
    name: m['name'],
    category: m['category'],
    brand: m['brand'],
    model: m['model'],
    serialNumber: m['serialNumber'],
    purchaseDate: m['purchaseDate'] != null ? DateTime.tryParse(m['purchaseDate']) : null,
    purchasePrice: m['purchasePrice'] != null ? (m['purchasePrice'] as num).toDouble() : null,
    status: m['status'],
    lastMaintenanceDate: m['lastMaintenanceDate'] != null ? DateTime.tryParse(m['lastMaintenanceDate']) : null,
    nextMaintenanceDate: m['nextMaintenanceDate'] != null ? DateTime.tryParse(m['nextMaintenanceDate']) : null,
    notes: m['notes'],
    createdAt: m['createdAt'],
  );

  EquipmentModel copyWith({String? status, DateTime? lastMaintenanceDate, DateTime? nextMaintenanceDate, String? notes}) => EquipmentModel(
    id: id,
    name: name,
    category: category,
    brand: brand,
    model: model,
    serialNumber: serialNumber,
    purchaseDate: purchaseDate,
    purchasePrice: purchasePrice,
    status: status ?? this.status,
    lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
    nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );
}
