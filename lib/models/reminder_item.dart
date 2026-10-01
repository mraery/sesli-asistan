class ReminderItem {
  final String id;
  final String title;
  final DateTime scheduledTime;
  final bool isCompleted;
  final DateTime createdAt;

  ReminderItem({
    required this.id,
    required this.title,
    required this.scheduledTime,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  ReminderItem copyWith({
    String? id,
    String? title,
    DateTime? scheduledTime,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'scheduledTime': scheduledTime.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    return ReminderItem(
      id: json['id'] as String,
      title: json['title'] as String,
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
