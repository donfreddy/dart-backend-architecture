import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';
import 'package:dart_backend_architecture/core/errors/api_error.dart';

class BlogService {
  final BlogRepo _blogRepo;

  const BlogService({
    required BlogRepo blogRepo,
  }) : _blogRepo = blogRepo;

  Future<Blog> create(Blog blog) async {
    return _blogRepo.create(blog);
  }

  Future<({List<Blog> items, int total})> findAllDrafts({
    int pageNumber = 1,
    int limit = 10,
  }) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findAllDrafts(pageNumber: page, limit: size);
  }

  Future<({List<Blog> items, int total})> findAllDraftsForWriter(
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

  Future<({List<Blog> items, int total})> findAllPublished({
    int pageNumber = 1,
    int limit = 10,
  }) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findAllPublished(pageNumber: page, limit: size);
  }

  Future<({List<Blog> items, int total})> findAllPublishedForAuthor(
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

  Future<({List<Blog> items, int total})> findAllPublishedForWriter(
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

  Future<({List<Blog> items, int total})> findAllSubmissions({
    int pageNumber = 1,
    int limit = 10,
  }) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findAllSubmissions(pageNumber: page, limit: size);
  }

  Future<({List<Blog> items, int total})> findAllSubmissionsForWriter(
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

  Future<({List<Blog> items, int total})> findByTagAndPaginated(
    String tag,
    int pageNumber,
    int limit,
  ) {
    _requireNonEmpty(tag, field: 'tag');
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return _blogRepo.findByTagAndPaginated(tag, page, size);
  }

  Future<Blog?> findById(String id) {
    _requireId(id);
    return _blogRepo.findById(id);
  }

  Future<Blog?> findByUrl(String blogUrl) {
    _requireNonEmpty(blogUrl, field: 'blogUrl');
    return _blogRepo.findByUrl(blogUrl);
  }

  Future<({List<Blog> items, int total})> findLatestBlogs(
    int pageNumber,
    int limit,
  ) {
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
    await _blogRepo.update(blog);
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
}
