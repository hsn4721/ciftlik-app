class MilkingModel {
  final int? id;
  final int animalId;
  final String animalEarTag;
  final String animalName;
  final String date;
  final String session;
  final double amount;
  final String? notes;
  final String createdAt;

  const MilkingModel({
    this.id,
    required this.animalId,
    this.animalEarTag = '',
    this.animalName = '',
    required this.date,
    required this.session,
    required this.amount,
    this.notes,
    required this.createdAt,
  });

  MilkingModel copyWith({
    int? id,
    int? animalId,
    String? animalEarTag,
    String? animalName,
    String? date,
    String? session,
    double? amount,
    String? notes,
    String? createdAt,
  }) => MilkingModel(
    id: id ?? this.id,
    animalId: animalId ?? this.animalId,
    animalEarTag: animalEarTag ?? this.animalEarTag,
    animalName: animalName ?? this.animalName,
    date: date ?? this.date,
    session: session ?? this.session,
    amount: amount ?? this.amount,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toMap() => {
        'id': id,
        'animalId': animalId,
        'date': date,
        'session': session,
        'amount': amount,
        'notes': notes,
        'createdAt': createdAt,
      };

  factory MilkingModel.fromMap(Map<String, dynamic> map) => MilkingModel(
        id: map['id'],
        animalId: map['animalId'],
        animalEarTag: map['earTag'] ?? '',
        animalName: map['name'] ?? map['earTag'] ?? '',
        date: map['date'],
        session: map['session'],
        amount: (map['amount'] as num).toDouble(),
        notes: map['notes'],
        createdAt: map['createdAt'],
      );
}
