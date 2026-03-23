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

  group('BlogService — event publication', () {
    late MockBlogRepo blogRepo;
    late MockEventBus eventBus;
    late BlogService sut;

    setUpAll(() {
      registerFallbackValue(blog);
    });

    setUp(() {
      blogRepo = MockBlogRepo();
      eventBus = MockEventBus();
      sut = BlogService(blogRepo: blogRepo, eventBus: eventBus);
    });

    test('create publishes blog.created event', () async {
      when(() => blogRepo.create(any())).thenAnswer((_) async => blog);
      when(() => eventBus.publish(any(), any())).thenAnswer((_) async {});

      await sut.create(blog);

      verify(() => eventBus.publish('blog.created', any())).called(1);
    });

    test('update publishes blog.updated event', () async {
      when(() => blogRepo.update(blog)).thenAnswer((_) async {});
      when(() => eventBus.publish(any(), any())).thenAnswer((_) async {});

      await sut.update(blog);

      verify(() => eventBus.publish('blog.updated', any())).called(1);
    });

    test('create still succeeds when event bus is unavailable', () async {
      when(() => blogRepo.create(any())).thenAnswer((_) async => blog);
      when(() => eventBus.publish(any(), any()))
          .thenThrow(Exception('event bus down'));

      // Must not rethrow — events are best-effort
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
