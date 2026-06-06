import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/model/user.dart';

/// Read-only contract for blog data access.
///
/// Consumers that only need to query blogs (e.g. read-only use-cases, analytics)
/// depend on this narrower interface rather than the full [BlogRepo].
abstract interface class BlogQueryRepo {
  Future<Blog?> findById(String id);

  Future<Blog?> findByUrl(String blogUrl);
  Future<Blog?> findUrlIfExists(String blogUrl);

  Future<({List<Blog> items, int total})> findByTagAndPaginated(
    String tag,
    int pageNumber,
    int limit,
  );

  Future<({List<Blog> items, int total})> findAllPublishedForAuthor(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  });
  Future<({List<Blog> items, int total})> findAllDrafts({
    int pageNumber = 1,
    int limit = 10,
  });
  Future<({List<Blog> items, int total})> findAllSubmissions({
    int pageNumber = 1,
    int limit = 10,
  });
  Future<({List<Blog> items, int total})> findAllPublished({
    int pageNumber = 1,
    int limit = 10,
  });
  Future<({List<Blog> items, int total})> findAllSubmissionsForWriter(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  });
  Future<({List<Blog> items, int total})> findAllPublishedForWriter(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  });
  Future<({List<Blog> items, int total})> findAllDraftsForWriter(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  });

  Future<({List<Blog> items, int total})> findLatestBlogs(
    int pageNumber,
    int limit,
  );
  Future<List<Blog>> searchSimilarBlogs(Blog blog, int limit);
  Future<List<Blog>> search(String query, int limit);
  Future<List<Blog>> searchLike(String query, int limit);
}
