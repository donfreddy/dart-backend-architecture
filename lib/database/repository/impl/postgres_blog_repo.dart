import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/database/db_pool.dart';
import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';
import 'package:postgres/postgres.dart';

final class PostgresBlogRepo implements BlogRepo {
  final DatabasePool _pool;

  PostgresBlogRepo(this._pool);

  static const _baseSelect = '''
    b.id            AS blog_id,
    b.title,
    b.description,
    b.text,
    b.draft_text,
    b.tags,
    b.img_url,
    b.blog_url,
    b.likes,
    b.score,
    b.is_submitted,
    b.is_draft,
    b.is_published,
    b.status,
    b.published_at,
    b.created_at    AS blog_created_at,
    b.updated_at,
    a.id            AS author_id,
    a.email         AS author_email,
    a.name          AS author_name,
    a.profile_pic_url AS author_profile_pic_url,
    a.created_at    AS author_created_at,
    cb.id           AS created_by_id,
    cb.email        AS created_by_email,
    cb.name         AS created_by_name,
    cb.profile_pic_url AS created_by_profile_pic_url,
    cb.created_at   AS created_by_created_at,
    ub.id           AS updated_by_id,
    ub.email        AS updated_by_email,
    ub.name         AS updated_by_name,
    ub.profile_pic_url AS updated_by_profile_pic_url,
    ub.created_at   AS updated_by_created_at
  ''';

  @override
  Future<Blog> create(Blog blog) async {
    final now = DateTime.now().toUtc();
    final result = await _pool.execute(
      Sql.named('''
        INSERT INTO blogs (
          title,
          description,
          text,
          draft_text,
          tags,
          author_id,
          img_url,
          blog_url,
          likes,
          score,
          is_submitted,
          is_draft,
          is_published,
          status,
          published_at,
          created_by,
          updated_by,
          created_at,
          updated_at
        ) VALUES (
          @title,
          @description,
          @text,
          @draftText,
          @tags,
          @authorId,
          @imgUrl,
          @blogUrl,
          @likes,
          @score,
          @isSubmitted,
          @isDraft,
          @isPublished,
          @status,
          @publishedAt,
          @createdBy,
          @updatedBy,
          @createdAt,
          @updatedAt
        )
        RETURNING id
      '''),
      parameters: {
        'title': blog.title,
        'description': blog.description,
        'text': blog.text,
        'draftText': blog.draftText,
        'tags': blog.tags,
        'authorId': blog.author.id,
        'imgUrl': blog.imgUrl,
        'blogUrl': blog.blogUrl,
        'likes': blog.likes ?? 0,
        'score': blog.score,
        'isSubmitted': blog.isSubmitted,
        'isDraft': blog.isDraft,
        'isPublished': blog.isPublished,
        'status': blog.status ?? true,
        'publishedAt': blog.publishedAt,
        'createdBy': blog.createdBy?.id,
        'updatedBy': blog.updatedBy?.id,
        'createdAt': blog.createdAt ?? now,
        'updatedAt': blog.updatedAt ?? now,
      },
    );

    final id = result.first.toColumnMap()['id'] as String;
    final created = await findById(id);
    if (created == null) {
      throw const InternalError('Failed to load created blog');
    }
    return created;
  }

  @override
  Future<void> update(Blog blog) async {
    final blogId = blog.id;
    if (blogId == null || blogId.isEmpty) {
      throw const BadRequestError('Blog id is required for update');
    }

    await _pool.execute(
      Sql.named('''
        UPDATE blogs
        SET
          title = @title,
          description = @description,
          text = @text,
          draft_text = @draftText,
          tags = @tags,
          img_url = @imgUrl,
          likes = @likes,
          score = @score,
          is_submitted = @isSubmitted,
          is_draft = @isDraft,
          is_published = @isPublished,
          status = @status,
          published_at = @publishedAt,
          created_by = @createdBy,
          updated_by = @updatedBy,
          updated_at = @updatedAt
        WHERE id = @id AND deleted_at IS NULL
      '''),
      parameters: {
        'id': blogId,
        'title': blog.title,
        'description': blog.description,
        'text': blog.text,
        'draftText': blog.draftText,
        'tags': blog.tags,
        'imgUrl': blog.imgUrl,
        'likes': blog.likes ?? 0,
        'score': blog.score,
        'isSubmitted': blog.isSubmitted,
        'isDraft': blog.isDraft,
        'isPublished': blog.isPublished,
        'status': blog.status ?? true,
        'publishedAt': blog.publishedAt,
        'createdBy': blog.createdBy?.id,
        'updatedBy': blog.updatedBy?.id,
        'updatedAt': DateTime.now().toUtc(),
      },
    );
  }

  @override
  Future<Blog?> findById(String id) => _findOne(
        whereClause: 'b.id = @id AND b.status = TRUE',
        params: {'id': id},
      );

  @override
  Future<Blog?> findByUrl(String blogUrl) => _findOne(
        whereClause: 'b.blog_url = @blogUrl AND b.status = TRUE',
        params: {'blogUrl': blogUrl},
      );

  @override
  Future<Blog?> findUrlIfExists(String blogUrl) => _findOne(
        whereClause: 'b.blog_url = @blogUrl',
        params: {'blogUrl': blogUrl},
      );

  @override
  Future<({List<Blog> items, int total})> findByTagAndPaginated(
    String tag,
    int pageNumber,
    int limit,
  ) async {
    final offset = _offset(pageNumber, limit);
    return _findManyWithTotal(
      whereClause:
          'b.status = TRUE AND b.is_published = TRUE AND @tag = ANY(b.tags)',
      params: {'tag': tag, 'limit': limit, 'offset': offset},
      orderBy: 'b.updated_at DESC',
    );
  }

  @override
  Future<({List<Blog> items, int total})> findAllPublishedForAuthor(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  }) {
    final offset = _offset(pageNumber, limit);
    return _findManyWithTotal(
      whereClause:
          'b.author_id = @authorId AND b.status = TRUE AND b.is_published = TRUE',
      params: {'authorId': user.id, 'limit': limit, 'offset': offset},
      orderBy: 'b.updated_at DESC',
    );
  }

  @override
  Future<({List<Blog> items, int total})> findAllDrafts({
    int pageNumber = 1,
    int limit = 10,
  }) {
    final offset = _offset(pageNumber, limit);
    return _findManyWithTotal(
      whereClause: 'b.is_draft = TRUE AND b.status = TRUE',
      params: {'limit': limit, 'offset': offset},
      orderBy: 'b.updated_at DESC',
    );
  }

  @override
  Future<({List<Blog> items, int total})> findAllSubmissions({
    int pageNumber = 1,
    int limit = 10,
  }) {
    final offset = _offset(pageNumber, limit);
    return _findManyWithTotal(
      whereClause: 'b.is_submitted = TRUE AND b.status = TRUE',
      params: {'limit': limit, 'offset': offset},
      orderBy: 'b.updated_at DESC',
    );
  }

  @override
  Future<({List<Blog> items, int total})> findAllPublished({
    int pageNumber = 1,
    int limit = 10,
  }) {
    final offset = _offset(pageNumber, limit);
    return _findManyWithTotal(
      whereClause: 'b.is_published = TRUE AND b.status = TRUE',
      params: {'limit': limit, 'offset': offset},
      orderBy: 'b.updated_at DESC',
    );
  }

  @override
  Future<({List<Blog> items, int total})> findAllSubmissionsForWriter(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  }) {
    final offset = _offset(pageNumber, limit);
    return _findManyWithTotal(
      whereClause:
          'b.author_id = @authorId AND b.status = TRUE AND b.is_submitted = TRUE',
      params: {'authorId': user.id, 'limit': limit, 'offset': offset},
      orderBy: 'b.updated_at DESC',
    );
  }

  @override
  Future<({List<Blog> items, int total})> findAllPublishedForWriter(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  }) {
    final offset = _offset(pageNumber, limit);
    return _findManyWithTotal(
      whereClause:
          'b.author_id = @authorId AND b.status = TRUE AND b.is_published = TRUE',
      params: {'authorId': user.id, 'limit': limit, 'offset': offset},
      orderBy: 'b.updated_at DESC',
    );
  }

  @override
  Future<({List<Blog> items, int total})> findAllDraftsForWriter(
    User user, {
    int pageNumber = 1,
    int limit = 10,
  }) {
    final offset = _offset(pageNumber, limit);
    return _findManyWithTotal(
      whereClause:
          'b.author_id = @authorId AND b.status = TRUE AND b.is_draft = TRUE',
      params: {'authorId': user.id, 'limit': limit, 'offset': offset},
      orderBy: 'b.updated_at DESC',
    );
  }

  @override
  Future<({List<Blog> items, int total})> findLatestBlogs(
    int pageNumber,
    int limit,
  ) async {
    final offset = _offset(pageNumber, limit);
    return _findManyWithTotal(
      whereClause: 'b.status = TRUE AND b.is_published = TRUE',
      params: {'limit': limit, 'offset': offset},
      orderBy: 'b.published_at DESC NULLS LAST',
    );
  }

  @override
  Future<List<Blog>> searchSimilarBlogs(Blog blog, int limit) {
    return _findMany(
      whereClause: '''
        b.status = TRUE
        AND b.is_published = TRUE
        AND b.title <> @title
        AND to_tsvector('simple', coalesce(b.title,'') || ' ' || coalesce(b.description,''))
            @@ plainto_tsquery('simple', @query)
      ''',
      params: {
        'query': blog.title,
        'title': blog.title,
        'limit': limit,
        'offset': 0,
      },
      orderBy: '''
        ts_rank(
          to_tsvector('simple', coalesce(b.title,'') || ' ' || coalesce(b.description,'')),
          plainto_tsquery('simple', @query)
        ) DESC,
        b.updated_at DESC
      ''',
    );
  }

  @override
  Future<List<Blog>> search(String query, int limit) {
    return _findMany(
      whereClause: '''
        b.status = TRUE
        AND b.is_published = TRUE
        AND to_tsvector('simple', coalesce(b.title,'') || ' ' || coalesce(b.description,''))
            @@ plainto_tsquery('simple', @query)
      ''',
      params: {'query': query, 'limit': limit, 'offset': 0},
      orderBy: '''
        ts_rank(
          to_tsvector('simple', coalesce(b.title,'') || ' ' || coalesce(b.description,'')),
          plainto_tsquery('simple', @query)
        ) DESC
      ''',
    );
  }

  @override
  Future<List<Blog>> searchLike(String query, int limit) {
    return _findMany(
      whereClause: '''
        b.status = TRUE
        AND b.is_published = TRUE
        AND b.title ILIKE @query
      ''',
      params: {'query': '%$query%', 'limit': limit, 'offset': 0},
      orderBy: 'b.score DESC',
    );
  }

  Future<Blog?> _findOne({
    required String whereClause,
    required Map<String, Object?> params,
  }) async {
    final rows = await _runSelect(
      whereClause: whereClause,
      params: params,
      orderBy: 'b.updated_at DESC',
      limitOne: true,
    );
    if (rows.isEmpty) return null;
    return _mapBlog(rows.first);
  }

  Future<List<Blog>> _findMany({
    required String whereClause,
    Map<String, Object?> params = const {},
    required String orderBy,
  }) async {
    final rows = await _runSelect(
      whereClause: whereClause,
      params: params,
      orderBy: orderBy,
      withLimit: true,
    );
    return rows.map(_mapBlog).toList(growable: false);
  }

  Future<({List<Blog> items, int total})> _findManyWithTotal({
    required String whereClause,
    required Map<String, Object?> params,
    required String orderBy,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT $_baseSelect, COUNT(*) OVER() AS _total
        FROM blogs b
        INNER JOIN users a ON a.id = b.author_id
        LEFT JOIN users cb ON cb.id = b.created_by
        LEFT JOIN users ub ON ub.id = b.updated_by
        WHERE $whereClause
          AND b.deleted_at IS NULL
          AND a.deleted_at IS NULL
        ORDER BY $orderBy
        LIMIT @limit OFFSET @offset
      '''),
      parameters: params,
    );

    if (result.isEmpty) return (items: const <Blog>[], total: 0);

    final total = result.first.toColumnMap()['_total'] as int;
    final items = result.map(_mapBlog).toList(growable: false);
    return (items: items, total: total);
  }

  Future<Result> _runSelect({
    required String whereClause,
    required Map<String, Object?> params,
    required String orderBy,
    bool withLimit = false,
    bool limitOne = false,
  }) async {
    return await _pool.execute(
      Sql.named('''
        SELECT $_baseSelect
        FROM blogs b
        INNER JOIN users a ON a.id = b.author_id
        LEFT JOIN users cb ON cb.id = b.created_by
        LEFT JOIN users ub ON ub.id = b.updated_by
        WHERE $whereClause
          AND b.deleted_at IS NULL
          AND a.deleted_at IS NULL
        ORDER BY $orderBy
        ${limitOne ? 'LIMIT 1' : (withLimit ? 'LIMIT @limit OFFSET @offset' : '')}
      '''),
      parameters: params,
    );
  }

  Blog _mapBlog(ResultRow row) {
    final map = row.toColumnMap();

    final author = User(
      id: map['author_id'] as String,
      email: map['author_email'] as String,
      name: map['author_name'] as String,
      profilePicUrl: map['author_profile_pic_url'] as String?,
      createdAt: map['author_created_at'] as DateTime,
    );

    final createdBy = map['created_by_id'] == null
        ? null
        : User(
            id: map['created_by_id'] as String,
            email: map['created_by_email'] as String,
            name: map['created_by_name'] as String,
            profilePicUrl: map['created_by_profile_pic_url'] as String?,
            createdAt: map['created_by_created_at'] as DateTime,
          );

    final updatedBy = map['updated_by_id'] == null
        ? null
        : User(
            id: map['updated_by_id'] as String,
            email: map['updated_by_email'] as String,
            name: map['updated_by_name'] as String,
            profilePicUrl: map['updated_by_profile_pic_url'] as String?,
            createdAt: map['updated_by_created_at'] as DateTime,
          );

    final tagsRaw = map['tags'];
    final tags = switch (tagsRaw) {
      final List<dynamic> values => values.cast<String>(),
      _ => const <String>[],
    };

    return Blog(
      id: map['blog_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      text: map['text'] as String?,
      draftText: map['draft_text'] as String?,
      tags: tags,
      author: author,
      imgUrl: map['img_url'] as String?,
      blogUrl: map['blog_url'] as String,
      likes: map['likes'] as int?,
      score: map['score'] as num,
      isSubmitted: map['is_submitted'] as bool,
      isDraft: map['is_draft'] as bool,
      isPublished: map['is_published'] as bool,
      status: map['status'] as bool?,
      publishedAt: map['published_at'] as DateTime?,
      createdAt: map['blog_created_at'] as DateTime?,
      updatedAt: map['updated_at'] as DateTime?,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }

  int _offset(int pageNumber, int limit) {
    final page = pageNumber < 1 ? 1 : pageNumber;
    final size = limit < 1 ? 1 : limit;
    return size * (page - 1);
  }
}
