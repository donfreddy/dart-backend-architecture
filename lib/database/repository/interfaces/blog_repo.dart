import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/model/user.dart';

abstract interface class BlogRepo {
  Future<Blog> create(Blog blog);
  Future<void> update(Blog blog);

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
