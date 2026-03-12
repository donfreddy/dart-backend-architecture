import 'package:dart_backend_architecture/cache/repository/blog_cache.dart';
import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';
import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/messaging/nats_service.dart';

/// Blog domain service that wraps the repo with caching and event emission.
class BlogService implements BlogRepo {
  final BlogRepo _blogRepo;
  final BlogCache _blogCache;
  final NatsService _nats;

  const BlogService({
    required BlogRepo blogRepo,
    required BlogCache blogCache,
    required NatsService nats,
  })  : _blogRepo = blogRepo,
        _blogCache = blogCache,
        _nats = nats;

  @override
  Future<Blog> create(Blog blog) async {
    final created = await _blogRepo.create(blog);
    await _evictListsBestEffort();
    await _evictSingleBestEffort(created);
    await _publishBestEffort(
      subject: 'blog.created',
      payload: {
        if (created.id != null) 'id': created.id,
        'authorId': created.author.id,
        'blogUrl': created.blogUrl,
      },
    );
    return created;
  }

  @override
  Future<List<Blog>> findAllDrafts() {
    return _blogRepo.findAllDrafts();
  }

  @override
  Future<List<Blog>> findAllDraftsForWriter(User user) {
    return _blogRepo.findAllDraftsForWriter(user);
  }

  @override
  Future<List<Blog>> findAllPublished() {
    return _blogRepo.findAllPublished();
  }

  @override
  Future<List<Blog>> findAllPublishedForAuthor(User user) {
    return _blogRepo.findAllPublishedForAuthor(user);
  }

  @override
  Future<List<Blog>> findAllPublishedForWriter(User user) {
    return _blogRepo.findAllPublishedForWriter(user);
  }

  @override
  Future<List<Blog>> findAllSubmissions() {
    return _blogRepo.findAllSubmissions();
  }

  @override
  Future<List<Blog>> findAllSubmissionsForWriter(User user) {
    return _blogRepo.findAllSubmissionsForWriter(user);
  }

  @override
  Future<Blog?> findBlogAllDataById(String id) {
    _requireId(id);
    return _blogRepo.findBlogAllDataById(id);
  }

  @override
  Future<List<Blog>> findByTagAndPaginated(
    String tag,
    int pageNumber,
    int limit,
  ) {
    _requireNonEmpty(tag, field: 'tag');
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findByTagAndPaginated(tag, page, size);
  }

  @override
  Future<Blog?> findByUrl(String blogUrl) {
    _requireNonEmpty(blogUrl, field: 'blogUrl');
    return _blogCache.getByUrlWithLoader(
      blogUrl,
      () => _blogRepo.findByUrl(blogUrl),
    );
  }

  @override
  Future<Blog?> findInfoById(String id) {
    _requireId(id);
    return _blogRepo.findInfoById(id);
  }

  @override
  Future<Blog?> findInfoWithTextAndDraftTextById(String id) {
    _requireId(id);
    return _blogRepo.findInfoWithTextAndDraftTextById(id);
  }

  @override
  Future<Blog?> findInfoWithTextById(String id) {
    _requireId(id);
    return _blogCache.getByIdWithLoader(
      id,
      () => _blogRepo.findInfoWithTextById(id),
    );
  }

  @override
  Future<List<Blog>> findLatestBlogs(int pageNumber, int limit) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findLatestBlogs(page, size);
  }

  @override
  Future<Blog?> findUrlIfExists(String blogUrl) {
    _requireNonEmpty(blogUrl, field: 'blogUrl');
    return _blogRepo.findUrlIfExists(blogUrl);
  }

  @override
  Future<List<Blog>> search(String query, int limit) {
    _requireNonEmpty(query, field: 'query');
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.search(query, size);
  }

  @override
  Future<List<Blog>> searchLike(String query, int limit) {
    _requireNonEmpty(query, field: 'query');
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.searchLike(query, size);
  }

  @override
  Future<List<Blog>> searchSimilarBlogs(Blog blog, int limit) {
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.searchSimilarBlogs(blog, size);
  }

  @override
  Future<void> update(Blog blog) async {
    await _blogRepo.update(blog);
    await _evictListsBestEffort();
    await _evictSingleBestEffort(blog);
    await _publishBestEffort(
      subject: 'blog.updated',
      payload: {
        if (blog.id != null) 'id': blog.id,
        'authorId': blog.author.id,
        'blogUrl': blog.blogUrl,
      },
    );
  }

  static void _requireId(String id) {
    if (id.trim().isEmpty) {
      throw const BadRequestError('Blog id is required');
    }
  }

  static void _requireNonEmpty(String value, {required String field}) {
    if (value.trim().isEmpty) {
      throw BadRequestError('$field is required');
    }
  }

  Future<void> _evictListsBestEffort() async {
    try {
      await _blogCache.evictAllLists();
    } catch (_) {}
  }

  Future<void> _evictSingleBestEffort(Blog blog) async {
    try {
      if (blog.id != null) {
        await _blogCache.evictById(blog.id!);
      }
      await _blogCache.evictByUrl(blog.blogUrl);
    } catch (_) {}
  }

  Future<void> _publishBestEffort({
    required String subject,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _nats.publish(subject, payload);
    } catch (_) {}
  }
}
