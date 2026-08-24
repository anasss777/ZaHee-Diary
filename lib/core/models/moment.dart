import 'package:equatable/equatable.dart';

import 'life_domain.dart';

/// A memorable event the user wants to keep, distinct from a
/// [Reflection] — TRD §12's framing: a reflection is "what did I think
/// about," a moment is "what happened that I want to remember." Both
/// are optional, both never block the daily goal-completion flow.
///
/// [title] is optional (not required) — forcing a title on every quick
/// capture would fight the "do first" philosophy this whole app is
/// built around; [content] carries the actual substance and is the only
/// required field beyond the date.
///
/// [media] is a list of storage URLs, present in the shape now for
/// forward-compatibility with TRD §12's "media" property, but NOT
/// wired to any actual upload yet — that needs `firebase_storage` and
/// an image picker, neither of which are dependencies yet. Every moment
/// created through this MVP will have an empty media list.
class Moment extends Equatable {
  final String id;
  final String userId;
  final DateTime date;
  final String? title;
  final String content;
  final LifeDomain? domainId;
  final List<String> media;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Moment({
    required this.id,
    required this.userId,
    required this.date,
    this.title,
    required this.content,
    this.domainId,
    this.media = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Moment copyWith({
    String? title,
    bool clearTitle = false,
    String? content,
    LifeDomain? domainId,
    bool clearDomain = false,
    List<String>? media,
    DateTime? updatedAt,
  }) {
    return Moment(
      id: id,
      userId: userId,
      date: date,
      title: clearTitle ? null : (title ?? this.title),
      content: content ?? this.content,
      domainId: clearDomain ? null : (domainId ?? this.domainId),
      media: media ?? this.media,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, date, title, content, domainId, media, createdAt, updatedAt];
}
