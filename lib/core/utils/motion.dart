import 'package:flutter/material.dart';

/// Returns [normal], or [Duration.zero] if the OS "reduce motion"
/// accessibility setting is on.
///
/// Built now, alongside the first animations added to the app, rather
/// than retrofitted later during a dedicated accessibility pass — TRD
/// §29 explicitly lists "reduced-motion support" as a requirement, and
/// it's far cheaper to route every new animation through one helper
/// from the start than to find and fix each one afterward.
///
/// [MediaQuery.disableAnimations] reflects the platform-level setting
/// (iOS "Reduce Motion", Android "Remove animations") — this isn't an
/// app-specific preference to build separately, just respecting what
/// the user already told their OS.
Duration motionDuration(BuildContext context, Duration normal) {
  return MediaQuery.of(context).disableAnimations ? Duration.zero : normal;
}
