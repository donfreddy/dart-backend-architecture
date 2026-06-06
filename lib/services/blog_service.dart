import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';
import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/messaging/event_bus.dart';

/// Blog domain service.
///
/// Responsibilities:
///   - Business-rule validation (non-empty fields, page bounds).
///   - NATS event publication on writes (best-effort, never fatal).
///
/// Cache read-through and write invalidation are handled by [CachingBlogRepo],
/// which is injected as the [blogRepo] dependency. This keeps the service
/// focused on domain logic and free of infrastructure concerns.
class BlogService {
  final BlogRepo _blogRepo;
  final EventBus _eventBus;

  const BlogService({
    required BlogRepo blogRepo,
    required EventBus eventBus,
  })  : _blogRepo = blogRepo,
        _eventBus = eventBus;

  Future<Blog> create(Blog blog) async {
    final created = await _blogRepo.create(blog);
    await _publishBestEffort(
      subject: 'blog.created',
      payload: {
        if (created.id != null) 'id': created.id,
        'author_id': created.author.id,
        'blog_url': created.blogUrl,
      },
    );
    return created;
  }

  Future<List<Blog>> findAllDrafts({
    int pageNumber = 1,
    int limit = 10,
  }) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findAllDrafts(pageNumber: page, limit: size);
  }

  Future<List<Blog>> findAllDraftsForWriter(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  }) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findAllDraftsForWriter(
      user,
      pageNumber: page,
      limit: size,
    );
  }

  Future<List<Blog>> findAllPublished({
    int pageNumber = 1,
    int limit = 10,
  }) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findAllPublished(pageNumber: page, limit: size);
  }

  Future<List<Blog>> findAllPublishedForAuthor(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  }) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findAllPublishedForAuthor(
      user,
      pageNumber: page,
      limit: size,
    );
  }

  Future<List<Blog>> findAllPublishedForWriter(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  }) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findAllPublishedForWriter(
      user,
      pageNumber: page,
      limit: size,
    );
  }

  Future<List<Blog>> findAllSubmissions({
    int pageNumber = 1,
    int limit = 10,
  }) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findAllSubmissions(pageNumber: page, limit: size);
  }

  Future<List<Blog>> findAllSubmissionsForWriter(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  }) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findAllSubmissionsForWriter(
      user,
      pageNumber: page,
      limit: size,
    );
  }

  Future<Blog?> findBlogAllDataById(String id) {
    _requireId(id);
    return _blogRepo.findBlogAllDataById(id);
  }

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

  Future<Blog?> findByUrl(String blogUrl) {
    _requireNonEmpty(blogUrl, field: 'blogUrl');
    return _blogRepo.findByUrl(blogUrl);
  }

  Future<Blog?> findInfoById(String id) {
    _requireId(id);
    return _blogRepo.findInfoById(id);
  }

  Future<Blog?> findInfoWithTextAndDraftTextById(String id) {
    _requireId(id);
    return _blogRepo.findInfoWithTextAndDraftTextById(id);
  }

  Future<Blog?> findInfoWithTextById(String id) {
    _requireId(id);
    return _blogRepo.findInfoWithTextById(id);
  }

  Future<List<Blog>> findLatestBlogs(int pageNumber, int limit) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findLatestBlogs(page, size);
  }

  Future<Blog?> findUrlIfExists(String blogUrl) {
    _requireNonEmpty(blogUrl, field: 'blogUrl');
    return _blogRepo.findUrlIfExists(blogUrl);
  }

  Future<List<Blog>> search(String query, int limit) {
    _requireNonEmpty(query, field: 'query');
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.search(query, size);
  }

  Future<List<Blog>> searchLike(String query, int limit) {
    _requireNonEmpty(query, field: 'query');
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.searchLike(query, size);
  }

  Future<List<Blog>> searchSimilarBlogs(Blog blog, int limit) {
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.searchSimilarBlogs(blog, size);
  }

  Future<void> update(Blog blog) async {
    final old =
        blog.id != null ? await _blogRepo.findBlogAllDataById(blog.id!) : null;
    await _blogRepo.update(blog);
    await _publishBestEffort(
      subject: _detectEvent(old, blog),
      payload: {
        if (blog.id != null) 'id': blog.id,
        'author_id': blog.author.id,
        'blog_url': blog.blogUrl,
      },
    );
  }

  static String _detectEvent(Blog? old, Blog updated) {
    if (updated.status == false && old?.status != false) return 'blog.deleted';
    if (updated.isPublished == true && old?.isPublished != true) {
      return 'blog.published';
    }
    if (updated.isPublished == false && old?.isPublished == true) {
      return 'blog.unpublished';
    }
    if (updated.isSubmitted == true && old?.isSubmitted != true) {
      return 'blog.submitted';
    }
    if (updated.isSubmitted == false && old?.isSubmitted == true) {
      return 'blog.withdrawn';
    }
    return 'blog.updated';
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

  Future<void> _publishBestEffort({
    required String subject,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _eventBus.publish(subject, payload);
    } catch (_) {}
  }
}
