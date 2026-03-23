import 'package:dart_backend_architecture/database/repository/interfaces/blog_query_repo.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_write_repo.dart';

export 'blog_query_repo.dart';
export 'blog_write_repo.dart';

/// Combined blog repository interface (read + write).
///
/// Use [BlogQueryRepo] or [BlogWriteRepo] directly when a consumer only needs
/// one side of the contract — this keeps dependencies minimal (ISP).
///
/// [PostgresBlogRepo], [CachingBlogRepo], and [BlogService] all implement
/// this interface so callers are not affected by the split.
abstract interface class BlogRepo implements BlogQueryRepo, BlogWriteRepo {}
