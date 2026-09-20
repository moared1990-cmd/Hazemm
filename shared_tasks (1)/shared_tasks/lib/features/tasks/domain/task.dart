class Task {
  Task({
    required this.id,
    required this.workspaceId,
    required this.title,
    this.description,
    required this.createdBy,
    this.assignedTo,
    required this.completed,
    required this.priority,
    this.dueDate,
    required this.createdAt,
    this.completedAt,
    this.completedBy,
  });

  final String id, workspaceId, title, createdBy, priority;
  final String? description, assignedTo, completedBy;
  final bool completed;
  final DateTime? dueDate, completedAt;
  final DateTime createdAt;

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'],
        workspaceId: m['workspace_id'],
        title: m['title'],
        description: m['description'],
        createdBy: m['created_by'],
        assignedTo: m['assigned_to'],
        completed: m['status'] == 'completed',
        priority: m['priority'],
        dueDate: m['due_date'] == null ? null : DateTime.parse(m['due_date']),
        createdAt: DateTime.parse(m['created_at']).toLocal(),
        completedAt:
            m['completed_at'] == null ? null : DateTime.parse(m['completed_at']).toLocal(),
        completedBy: m['completed_by'],
      );
}
