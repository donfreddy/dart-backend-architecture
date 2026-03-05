abstract final class CacheKeys {
  CacheKeys._();

  // ── Blogs ──────────────────────────────────────────────────
  static String blog(String id) => 'blog:$id';
  static String blogList(int page, int pageSize) => 'blogs:p$page:s$pageSize';
  static const blogListPattern = 'blogs:*';
  static const blogTtl = Duration(hours: 1);

  // ── Users ──────────────────────────────────────────────────
  static String userProfile(String id) => 'user:profile:$id';
  static const userTtl = Duration(minutes: 30);

  // ── Keystore ───────────────────────────────────────────────
  static String keystore(String userId) => 'keystore:$userId';
  static const keystoreTtl = Duration(minutes: 5);

  // ── Rate limiting ──────────────────────────────────────────
  static String rateLimit(String ip) => 'rate_limit:$ip';
}
