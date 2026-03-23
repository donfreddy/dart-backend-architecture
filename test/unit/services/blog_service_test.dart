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

  group('BlogService — NATS event publication', () {
    late MockBlogRepo blogRepo;
    late MockNatsService nats;
    late BlogService sut;

    setUpAll(() {
      registerFallbackValue(blog);
    });

    setUp(() {
      blogRepo = MockBlogRepo();
      nats = MockNatsService();
      // BlogService receives a CachingBlogRepo in production.
      // In unit tests we pass a plain MockBlogRepo — cache behaviour
      // is covered separately in caching_blog_repo_test.dart.
      sut = BlogService(blogRepo: blogRepo, nats: nats);
    });

    test('create publishes blog.created event', () async {
      when(() => blogRepo.create(any())).thenAnswer((_) async => blog);
      when(() => nats.publish(any(), any())).thenAnswer((_) async {});

      await sut.create(blog);

      verify(() => nats.publish('blog.created', any())).called(1);
    });

    test('update publishes blog.updated event', () async {
      when(() => blogRepo.update(blog)).thenAnswer((_) async {});
      when(() => nats.publish(any(), any())).thenAnswer((_) async {});

      await sut.update(blog);

      verify(() => nats.publish('blog.updated', any())).called(1);
    });

    test('create still succeeds when NATS is unavailable', () async {
      when(() => blogRepo.create(any())).thenAnswer((_) async => blog);
      when(() => nats.publish(any(), any()))
          .thenThrow(Exception('NATS down'));

      // Must not rethrow — NATS events are best-effort
      await expectLater(sut.create(blog), completes);
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
