/// Centralised string constants for values stored in [shelf.Request.context].
///
/// Using typed constants instead of raw string literals ensures that a typo
/// in a middleware key is caught at compile time rather than at runtime.
abstract final class RequestContextKeys {
  RequestContextKeys._();

  // ── Auth middleware ──────────────────────────────────────────────────────
  static const accessToken = 'access_token';
  static const userPayload = 'user_payload';
  static const authUser = 'auth_user';
  static const authKeystore = 'auth_keystore';

  // ── Authorization middleware ─────────────────────────────────────────────
  static const currentRoleCode = 'current_role_code';

  // ── API key middleware ───────────────────────────────────────────────────
  static const apiKey = 'api_key';
}
