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

  group('BlogService caching + events', () {
    late MockBlogRepo blogRepo;
    late MockBlogCache blogCache;
    late MockNatsService nats;
    late BlogService sut;

    setUpAll(() {
      registerFallbackValue(blog);
    });

    setUp(() {
      blogRepo = MockBlogRepo();
      blogCache = MockBlogCache();
      nats = MockNatsService();
      sut = BlogService(blogRepo: blogRepo, blogCache: blogCache, nats: nats);
    });

    test('findByUrl uses cache hit', () async {
      when(() => blogCache.getByUrlWithLoader('hello-world', any()))
          .thenAnswer((_) async => blog);

      final result = await sut.findByUrl('hello-world');

      expect(result, blog);
      verifyNever(() => blogRepo.findByUrl(any()));
    });

    test('findByUrl loads and caches on miss', () async {
      when(() => blogRepo.findByUrl('hello-world'))
          .thenAnswer((_) async => blog);
      when(() => blogCache.getByUrlWithLoader(any(), any()))
          .thenAnswer((inv) async {
        final loader = inv.positionalArguments[1] as Future<Blog?> Function();
        return loader();
      });

      final result = await sut.findByUrl('hello-world');

      expect(result, blog);
      verify(() => blogRepo.findByUrl('hello-world')).called(1);
    });

    test('findInfoWithTextById uses cache', () async {
      when(() => blogCache.getByIdWithLoader('b-1', any()))
          .thenAnswer((_) async => blog);

      final result = await sut.findInfoWithTextById('b-1');

      expect(result, blog);
      verifyNever(() => blogRepo.findInfoWithTextById(any()));
    });

    test('create evicts cache and publishes event', () async {
      when(() => blogRepo.create(any())).thenAnswer((_) async => blog);
      when(() => nats.publish(any(), any())).thenAnswer((_) async {});
      when(() => blogCache.evictAllLists()).thenAnswer((_) async {});
      when(() => blogCache.evictById(any())).thenAnswer((_) async {});
      when(() => blogCache.evictByUrl(any())).thenAnswer((_) async {});

      await sut.create(blog);

      verify(() => blogCache.evictAllLists()).called(1);
      verify(() => blogCache.evictById('b-1')).called(1);
      verify(() => blogCache.evictByUrl('hello-world')).called(1);
      verify(() => nats.publish('blog.created', any())).called(1);
    });

    test('update evicts caches and publishes event', () async {
      when(() => blogRepo.update(blog)).thenAnswer((_) async {});
      when(() => nats.publish(any(), any())).thenAnswer((_) async {});
      when(() => blogCache.evictAllLists()).thenAnswer((_) async {});
      when(() => blogCache.evictById(any())).thenAnswer((_) async {});
      when(() => blogCache.evictByUrl(any())).thenAnswer((_) async {});

      await sut.update(blog);

      verify(() => blogCache.evictAllLists()).called(1);
      verify(() => blogCache.evictById('b-1')).called(1);
      verify(() => blogCache.evictByUrl('hello-world')).called(1);
      verify(() => nats.publish('blog.updated', any())).called(1);
    });
  });
}
