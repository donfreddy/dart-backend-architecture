abstract final class CacheKeys {
  CacheKeys._();

  // ── Blogs ──────────────────────────────────────────────────
  static String blog(String id) => 'blog:$id';
  static String blogUrl(String endpoint) => 'blog:url:$endpoint';
  static String blogList(int page, int pageSize) => 'blogs:p$page:s$pageSize';
  static const blogListPattern = 'blogs:*';
  static const blogTtl = Duration(hours: 1);

  // ── Users ──────────────────────────────────────────────────
  static String userProfile(String id) => 'user:profile:$id';
  static const userTtl = Duration(minutes: 30);

  // ── Keystore ───────────────────────────────────────────────
  // Legacy single-session key (kept for backward compat, prefer keystoreEntry)
  static String keystore(String userId) => 'keystore:$userId';

  // Per-session key — supports multiple concurrent sessions per user.
  // Keyed by (userId, primaryKey) so each access token maps to its own entry.
  static String keystoreEntry(String userId, String primaryKey) =>
      'keystore:$userId:$primaryKey';
  static const keystoreTtl = Duration(minutes: 5);

  // ── Rate limiting ──────────────────────────────────────────
  static String rateLimit(String ip) => 'rate_limit:$ip';
}
