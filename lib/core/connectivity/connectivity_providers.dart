import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently reports SOME network path (wifi/mobile/
/// ethernet) as available.
///
/// This is an OS-level reachability signal, not a guarantee Firestore
/// itself is reachable — a device can report "connected to wifi" with
/// no real internet behind it. Good enough for "should I tell the user
/// they're offline"; not a substitute for Firestore's own connection
/// state, which is handled separately (and automatically) by Firestore's
/// own offline persistence — see the comment in main.dart where that's
/// configured.
///
/// KNOWN GAP: Android doesn't deliver connectivity-change callbacks to
/// backgrounded apps (8.0+), so a change that happens while this app is
/// backgrounded won't be reflected until something re-triggers a check.
/// The initial checkConnectivity() call below makes this accurate at
/// launch and while foregrounded; a lifecycle-based re-check on app
/// resume would close the remaining gap and is a reasonable, bounded
/// follow-up rather than something built here.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _hasConnection(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_hasConnection);
});

bool _hasConnection(List<ConnectivityResult> results) {
  return results.isNotEmpty && !results.contains(ConnectivityResult.none);
}
