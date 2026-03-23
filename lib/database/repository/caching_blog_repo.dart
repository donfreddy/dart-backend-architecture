import 'package:dart_backend_architecture/cache/repository/blog_cache.dart';
import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';

/// Decorator around [BlogRepo] that adds read-through caching on hot read paths
/// and best-effort cache invalidation on every write.
///
/// Keeping cache logic here lets [BlogService] stay focused on business rules
/// (event publication, validation) without knowing about cache keys or TTLs.
class CachingBlogRepo implements BlogRepo {
  final BlogRepo _inner;
  final BlogCache _cache;

  const CachingBlogRepo({required BlogRepo inner, required BlogCache cache})
      : _inner = inner,
        _cache = cache;

  // ── Writes: delegate then invalidate ───────────────────────────────────────

  @override
  Future<Blog> create(Blog blog) async {
    final created = await _inner.create(blog);
    await _evictSingleBestEffort(created);
    await _evictListsBestEffort();
    return created;
  }

  @override
  Future<void> update(Blog blog) async {
    await _inner.update(blog);
    await _evictSingleBestEffort(blog);
    await _evictListsBestEffort();
  }

  // ── Cached reads ───────────────────────────────────────────────────────────

  @override
  Future<Blog?> findInfoWithTextById(String id) {
    return _cache.getByIdWithLoader(id, () => _inner.findInfoWithTextById(id));
  }

  @override
  Future<Blog?> findByUrl(String blogUrl) {
    return _cache.getByUrlWithLoader(
      blogUrl,
      () => _inner.findByUrl(blogUrl),
    );
  }

  // ── Pass-through reads ─────────────────────────────────────────────────────

  @override
  Future<Blog?> findInfoById(String id) => _inner.findInfoById(id);

  @override
  Future<Blog?> findInfoWithTextAndDraftTextById(String id) =>
      _inner.findInfoWithTextAndDraftTextById(id);

  @override
  Future<Blog?> findBlogAllDataById(String id) =>
      _inner.findBlogAllDataById(id);

  @override
  Future<Blog?> findUrlIfExists(String blogUrl) =>
      _inner.findUrlIfExists(blogUrl);

  @override
  Future<List<Blog>> findByTagAndPaginated(
    String tag,
    int pageNumber,
    int limit,
  ) =>
      _inner.findByTagAndPaginated(tag, pageNumber, limit);

  @override
  Future<List<Blog>> findAllPublishedForAuthor(User user) =>
      _inner.findAllPublishedForAuthor(user);

  @override
  Future<List<Blog>> findAllDrafts() => _inner.findAllDrafts();

  @override
  Future<List<Blog>> findAllSubmissions() => _inner.findAllSubmissions();

  @override
  Future<List<Blog>> findAllPublished() => _inner.findAllPublished();

  @override
  Future<List<Blog>> findAllSubmissionsForWriter(User user) =>
      _inner.findAllSubmissionsForWriter(user);

  @override
  Future<List<Blog>> findAllPublishedForWriter(User user) =>
      _inner.findAllPublishedForWriter(user);

  @override
  Future<List<Blog>> findAllDraftsForWriter(User user) =>
      _inner.findAllDraftsForWriter(user);

  @override
  Future<List<Blog>> findLatestBlogs(int pageNumber, int limit) =>
      _inner.findLatestBlogs(pageNumber, limit);

  @override
  Future<List<Blog>> searchSimilarBlogs(Blog blog, int limit) =>
      _inner.searchSimilarBlogs(blog, limit);

  @override
  Future<List<Blog>> search(String query, int limit) =>
      _inner.search(query, limit);

  @override
  Future<List<Blog>> searchLike(String query, int limit) =>
      _inner.searchLike(query, limit);

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _evictSingleBestEffort(Blog blog) async {
    try {
      if (blog.id != null) await _cache.evictById(blog.id!);
      await _cache.evictByUrl(blog.blogUrl);
    } catch (_) {}
  }

  Future<void> _evictListsBestEffort() async {
    try {
      await _cache.evictAllLists();
    } catch (_) {}
  }
}
