// import 'dart:convert';

import 'package:dart_backend_architecture/cache/cache_service.dart';
import 'package:dart_backend_architecture/cache/keys.dart';
// import 'package:dart_backend_architecture/cache/keys.dart';
// import 'package:dart_backend_architecture/database/model/blog.dart';
// import 'package:dart_backend_architecture/services/blog_service.dart';

final class BlogCache {
  final CacheService _cache;

  const BlogCache(this._cache);

  // // ── Single blog ────────────────────────────────────────────

  // Future<Blog?> findById(String id) async {
  //   final raw = await _cache.get(CacheKeys.blog(id));
  //   if (raw == null) return null;

  //   try {
  //     return Blog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  //   } catch (_) {
  //     // Corrupt entry — evict silently
  //     await _cache.invalidate(CacheKeys.blog(id));
  //     return null;
  //   }
  // }

  // Future<void> saveById(Blog blog) async {
  //   await _cache.set(
  //     CacheKeys.blog(blog.id),
  //     jsonEncode(blog.toJson()),
  //     ttl: CacheKeys.blogTtl,
  //   );
  // }

  // Future<void> evictById(String id) async {
  //   await _cache.invalidate(CacheKeys.blog(id));
  // }

  // // ── Blog list ──────────────────────────────────────────────

  // Future<BlogListResult?> findList(int page, int pageSize) async {
  //   final raw = await _cache.get(CacheKeys.blogList(page, pageSize));
  //   if (raw == null) return null;

  //   try {
  //     return BlogListResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  //   } catch (_) {
  //     await _cache.invalidate(CacheKeys.blogList(page, pageSize));
  //     return null;
  //   }
  // }

  // Future<void> saveList(int page, int pageSize, BlogListResult result) async {
  //   await _cache.set(
  //     CacheKeys.blogList(page, pageSize),
  //     jsonEncode(result.toJson()),
  //     ttl: CacheKeys.blogTtl,
  //   );
  // }

  // Evict all paginated list entries — called on create / publish / unpublish
  Future<void> evictAllLists() async {
    await _cache.invalidatePattern(CacheKeys.blogListPattern);
  }
}
