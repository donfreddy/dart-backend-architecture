import 'dart:convert';

import 'package:dart_backend_architecture/cache/cache_service.dart';
import 'package:dart_backend_architecture/cache/keys.dart';
import 'package:dart_backend_architecture/database/model/blog.dart';

class BlogCache {
  final CacheService _cache;

  const BlogCache(this._cache);

  // ── Single blog (read-through) ───────────────────────────────

  Future<Blog?> getByIdWithLoader(
    String id,
    Future<Blog?> Function() loader,
  ) async {
    final cached = await _get(CacheKeys.blog(id));
    if (cached != null) return cached;

    final fresh = await loader();
    if (fresh == null || fresh.id == null) return fresh;

    await _set(CacheKeys.blog(fresh.id!), fresh);
    await _set(CacheKeys.blogUrl(fresh.blogUrl), fresh);
    return fresh;
  }

  Future<Blog?> getByUrlWithLoader(
    String url,
    Future<Blog?> Function() loader,
  ) async {
    final cached = await _get(CacheKeys.blogUrl(url));
    if (cached != null) return cached;

    final fresh = await loader();
    if (fresh == null || fresh.id == null) return fresh;

    await _set(CacheKeys.blog(fresh.id!), fresh);
    await _set(CacheKeys.blogUrl(fresh.blogUrl), fresh);
    return fresh;
  }

  Future<void> evictById(String id) async {
    await _cache.invalidate(CacheKeys.blog(id));
  }

  Future<void> evictByUrl(String url) async {
    await _cache.invalidate(CacheKeys.blogUrl(url));
  }

  // Evict all paginated list entries — called on create / publish / unpublish
  Future<void> evictAllLists() async {
    await _cache.invalidatePattern(CacheKeys.blogListPattern);
  }

  Future<Blog?> _get(String key) async {
    final raw = await _cache.get(key);
    if (raw == null) return null;

    try {
      return Blog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await _cache.invalidate(key);
      return null;
    }
  }

  Future<void> _set(String key, Blog blog) {
    return _cache.set(
      key,
      jsonEncode(blog.toJson()),
      ttl: CacheKeys.blogTtl,
    );
  }
}
