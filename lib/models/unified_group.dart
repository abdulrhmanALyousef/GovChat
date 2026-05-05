class UnifiedGroup {
  final String id;
  final String name;

  /// 'company' | 'department' | 'project'
  final String type;

  final String messagesPath;
  final bool isDeletable;
  final int memberCount;

  const UnifiedGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.messagesPath,
    this.isDeletable = false,
    this.memberCount = 0,
  });
}
