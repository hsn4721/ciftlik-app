class StaffModel {
  final int? id;
  final String name;
  final String role;
  final String? phone;
  final String? email;
  final DateTime? startDate;
  final double? salary;
  final bool isActive;
  final String? notes;
  final String createdAt;

  const StaffModel({
    this.id,
    required this.name,
    required this.role,
    this.phone,
    this.email,
    this.startDate,
    this.salary,
    this.isActive = true,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'role': role,
    'phone': phone,
    'email': email,
    'startDate': startDate?.toIso8601String().split('T').first,
    'salary': salary,
    'isActive': isActive ? 1 : 0,
    'notes': notes,
    'createdAt': createdAt,
  };

  factory StaffModel.fromMap(Map<String, dynamic> m) => StaffModel(
    id: m['id'],
    name: m['name'],
    role: m['role'],
    phone: m['phone'],
    email: m['email'],
    startDate: m['startDate'] != null ? DateTime.tryParse(m['startDate']) : null,
    salary: m['salary'] != null ? (m['salary'] as num).toDouble() : null,
    isActive: (m['isActive'] as int? ?? 1) == 1,
    notes: m['notes'],
    createdAt: m['createdAt'],
  );

  StaffModel copyWith({bool? isActive, double? salary, String? phone, String? notes}) => StaffModel(
    id: id,
    name: name,
    role: role,
    phone: phone ?? this.phone,
    email: email,
    startDate: startDate,
    salary: salary ?? this.salary,
    isActive: isActive ?? this.isActive,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );
}

class TaskModel {
  final int? id;
  final String title;
  final String? description;
  final int? assignedToId;
  final String? assignedToName;
  final String? dueDate;
  final bool isCompleted;
  final String priority;
  final String createdAt;

  const TaskModel({
    this.id,
    required this.title,
    this.description,
    this.assignedToId,
    this.assignedToName,
    this.dueDate,
    this.isCompleted = false,
    this.priority = 'Normal',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'assignedToId': assignedToId,
    'dueDate': dueDate,
    'isCompleted': isCompleted ? 1 : 0,
    'priority': priority,
    'createdAt': createdAt,
  };

  factory TaskModel.fromMap(Map<String, dynamic> m) => TaskModel(
    id: m['id'],
    title: m['title'],
    description: m['description'],
    assignedToId: m['assignedToId'],
    assignedToName: m['staffName'],
    dueDate: m['dueDate'],
    isCompleted: (m['isCompleted'] as int? ?? 0) == 1,
    priority: m['priority'] ?? 'Normal',
    createdAt: m['createdAt'],
  );
}
