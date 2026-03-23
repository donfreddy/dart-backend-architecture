import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/model/user.dart';

/// Read-only contract for blog data access.
///
/// Consumers that only need to query blogs (e.g. read-only use-cases, analytics)
/// depend on this narrower interface rather than the full [BlogRepo].
abstract interface class BlogQueryRepo {
  Future<Blog?> findInfoById(String id);
  Future<Blog?> findInfoWithTextById(String id);
  Future<Blog?> findInfoWithTextAndDraftTextById(String id);
  Future<Blog?> findBlogAllDataById(String id);

  Future<Blog?> findByUrl(String blogUrl);
  Future<Blog?> findUrlIfExists(String blogUrl);

  Future<List<Blog>> findByTagAndPaginated(
    String tag,
    int pageNumber,
    int limit,
  );

  Future<List<Blog>> findAllPublishedForAuthor(User user);
  Future<List<Blog>> findAllDrafts();
  Future<List<Blog>> findAllSubmissions();
  Future<List<Blog>> findAllPublished();
  Future<List<Blog>> findAllSubmissionsForWriter(User user);
  Future<List<Blog>> findAllPublishedForWriter(User user);
  Future<List<Blog>> findAllDraftsForWriter(User user);

  Future<List<Blog>> findLatestBlogs(int pageNumber, int limit);
  Future<List<Blog>> searchSimilarBlogs(Blog blog, int limit);
  Future<List<Blog>> search(String query, int limit);
  Future<List<Blog>> searchLike(String query, int limit);
}
