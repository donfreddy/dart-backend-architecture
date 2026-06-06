import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/services/blog_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../mocks/mocks.dart';

void main() {
  final author = User(
    id: 'u-1',
    email: 'x@y.com',
    name: 'Author',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final blog = Blog(
    id: 'b-1',
    title: 'Hello',
    description: 'Desc',
    text: 'Body',
    draftText: 'Draft',
    tags: const ['dart'],
    author: author,
    blogUrl: 'hello-world',
    score: 1,
    isSubmitted: true,
    isDraft: false,
    isPublished: true,
  );

  group('BlogService', () {
    late MockBlogRepo blogRepo;
    late BlogService sut;

    setUp(() {
      blogRepo = MockBlogRepo();
      sut = BlogService(blogRepo: blogRepo);
    });

    test('findByUrl delegates to repo', () async {
      when(() => blogRepo.findByUrl('hello-world'))
          .thenAnswer((_) async => blog);

      final result = await sut.findByUrl('hello-world');

      expect(result, blog);
      verify(() => blogRepo.findByUrl('hello-world')).called(1);
    });
  });
}
