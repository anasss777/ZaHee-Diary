import 'package:equatable/equatable.dart';

import 'notification_preferences.dart';

/// The authenticated user's profile (TRD §21).
///
/// [timezone] matters beyond display: daily goal completion is evaluated
/// against the user's *local* date, so this drives how "today" is
/// computed throughout the app.
class AppUser extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? photoURL;

  /// IANA timezone name, e.g. "Africa/Tunis". Defaults to the device
  /// timezone at signup and can be changed in settings.
  final String timezone;

  /// BCP-47 locale code, e.g. "en", "ar", "fr".
  final String locale;

  /// True once the user has been through the onboarding flow (TRD §20)
  /// — deliberately its own persisted flag rather than inferred from
  /// "does this user have any goals," since a user could later archive
  /// every goal without needing to be sent back through onboarding.
  final bool hasCompletedOnboarding;

  final NotificationPreferences notificationPreferences;

  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.timezone,
    required this.locale,
    this.hasCompletedOnboarding = false,
    this.notificationPreferences = const NotificationPreferences(),
    required this.createdAt,
    required this.updatedAt,
  });

  AppUser copyWith({
    String? displayName,
    String? photoURL,
    String? timezone,
    String? locale,
    bool? hasCompletedOnboarding,
    NotificationPreferences? notificationPreferences,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      timezone: timezone ?? this.timezone,
      locale: locale ?? this.locale,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    photoURL,
    timezone,
    locale,
    hasCompletedOnboarding,
    notificationPreferences,
    createdAt,
    updatedAt,
  ];
}
