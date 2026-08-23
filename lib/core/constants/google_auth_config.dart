/// The OAuth 2.0 **Web** client ID for this Firebase project — NOT the
/// Android client ID.
///
/// `google_sign_in` v7 requires this to be passed to
/// `GoogleSignIn.instance.initialize()` in order to receive a Google
/// ID token that Firebase Auth will accept (the ID token's audience
/// must match a Web-type OAuth client registered on the project).
///
/// Where to find it:
///   Firebase Console → Project Settings → General → scroll to "Your apps"
///   → look for the entry with no platform icon (Web), OR
///   Firebase Console → Authentication → Sign-in method → Google →
///   expand "Web SDK configuration" → "Web client ID", OR
///   in an updated `google-services.json`, the `oauth_client` entry with
///   `"client_type": 3`.
///
/// This value is not secret (it's sent to Google as part of the normal
/// OAuth flow and is visible in network traffic / decompiled APKs), so
/// it's fine to commit as a plain constant.
const String kGoogleSignInServerClientId =
    '726480954111.apps.googleusercontent.com';
