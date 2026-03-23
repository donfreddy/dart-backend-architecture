import 'package:dart_backend_architecture/database/model/blog.dart';

/// Write contract for blog data access.
///
/// Consumers that only mutate blogs (e.g. import jobs, migration scripts)
/// depend on this narrower interface rather than the full [BlogRepo].
abstract interface class BlogWriteRepo {
  Future<Blog> create(Blog blog);
  Future<void> update(Blog blog);
}
