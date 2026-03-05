import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';

final class BlogService {
  final BlogRepo _blogRepo;

  const BlogService({required BlogRepo blogRepo}) : _blogRepo = blogRepo;

  Future<List<Blog>> listBlogs() => _blogRepo.findAllPublished();
}
