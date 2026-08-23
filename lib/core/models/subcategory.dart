import 'package:equatable/equatable.dart';

import 'life_domain.dart';

/// A user-customizable subsection within a [LifeDomain].
///
/// E.g. Health -> Fitness, Sleep, Nutrition (see TRD §10).
/// Domains are fixed; subcategories are not — users can rename, add,
/// archive, and reorder them.
class Subcategory extends Equatable {
  final String id;
  final String userId;
  final LifeDomain domainId;
  final String name;
  final String icon;
  final int order;
  final bool isActive;
  final DateTime createdAt;

  const Subcategory({
    required this.id,
    required this.userId,
    required this.domainId,
    required this.name,
    required this.icon,
    required this.order,
    required this.isActive,
    required this.createdAt,
  });

  Subcategory copyWith({
    String? name,
    String? icon,
    int? order,
    bool? isActive,
  }) {
    return Subcategory(
      id: id,
      userId: userId,
      domainId: domainId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    domainId,
    name,
    icon,
    order,
    isActive,
    createdAt,
  ];
}
