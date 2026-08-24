import 'package:equatable/equatable.dart';

import 'life_domain.dart';

/// An optional piece of free-text reflection (TRD §11) — never required,
/// never blocks the daily goal-completion flow.
///
/// TRD §11 describes reflections as attachable to a domain, a
/// subsection, a goal, a date, or the whole day. This MVP supports
/// [date] (always) and [domainId] (optional) only — subsection- and
/// goal-level linking are deferred, since they'd each need their own
/// picker UI for a feature whose entire premise is staying lightweight.
/// A null [domainId] means the reflection is about the day as a whole.
class Reflection extends Equatable {
  final String id;
  final String userId;
  final LifeDomain? domainId;
  final DateTime date;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reflection({
    required this.id,
    required this.userId,
    this.domainId,
    required this.date,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Reflection copyWith({
    LifeDomain? domainId,
    bool clearDomain = false,
    String? content,
    DateTime? updatedAt,
  }) {
    return Reflection(
      id: id,
      userId: userId,
      domainId: clearDomain ? null : (domainId ?? this.domainId),
      date: date,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, userId, domainId, date, content, createdAt, updatedAt];
}
