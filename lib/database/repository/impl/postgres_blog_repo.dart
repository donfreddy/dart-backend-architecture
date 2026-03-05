import 'package:dart_backend_architecture/core/errors/api_error.dart';
import 'package:dart_backend_architecture/core/logger.dart';
import 'package:dart_backend_architecture/database/model/blog.dart';
import 'package:dart_backend_architecture/database/model/user.dart';
import 'package:dart_backend_architecture/database/repository/interfaces/blog_repo.dart';
import 'package:postgres/postgres.dart';

final class PostgresBlogRepo implements BlogRepo {
  final Pool<dynamic> _pool;
  final _log = AppLogger.get('PostgresBlogRepo');

  PostgresBlogRepo(this._pool);

  static const _baseSelect = '''
    b.id,
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
    b.created_at,
    b.updated_at,
    a.id,
    a.email,
    a.name,
    a.profile_pic_url,
    a.created_at,
    cb.id,
    cb.email,
    cb.name,
    cb.profile_pic_url,
    cb.created_at,
    ub.id,
    ub.email,
    ub.name,
    ub.profile_pic_url,
    ub.created_at
  ''';

  @override
  Future<Blog> create(Blog blog) async {
    try {
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

      final id = result.first[0] as String;
      final created = await findBlogAllDataById(id);
      if (created == null) throw const InternalError('Failed to load created blog');
      return created;
    } catch (e, st) {
      _log.severe('create failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<void> update(Blog blog) async {
    try {
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
    } on ApiError {
      rethrow;
    } catch (e, st) {
      _log.severe('update failed', e, st);
      throw const InternalError();
    }
  }

  @override
  Future<Blog?> findInfoById(String id) => _findOne(whereClause: 'b.id = @id AND b.status = TRUE', params: {'id': id});

  @override
  Future<Blog?> findInfoWithTextById(String id) =>
      _findOne(whereClause: 'b.id = @id AND b.status = TRUE', params: {'id': id});

  @override
  Future<Blog?> findInfoWithTextAndDraftTextById(String id) =>
      _findOne(whereClause: 'b.id = @id AND b.status = TRUE', params: {'id': id});

  @override
  Future<Blog?> findBlogAllDataById(String id) =>
      _findOne(whereClause: 'b.id = @id AND b.status = TRUE', params: {'id': id});

  @override
  Future<Blog?> findByUrl(String blogUrl) => _findOne(
        whereClause: 'b.blog_url = @blogUrl AND b.status = TRUE',
        params: {'blogUrl': blogUrl},
      );

  @override
  Future<Blog?> findUrlIfExists(String blogUrl) =>
      _findOne(whereClause: 'b.blog_url = @blogUrl', params: {'blogUrl': blogUrl});

  @override
  Future<List<Blog>> findByTagAndPaginated(String tag, int pageNumber, int limit) async {
    final offset = _offset(pageNumber, limit);
    return _findMany(
      whereClause: 'b.status = TRUE AND b.is_published = TRUE AND @tag = ANY(b.tags)',
      params: {'tag': tag, 'limit': limit, 'offset': offset},
      orderBy: 'b.updated_at DESC',
      limit: true,
    );
  }

  @override
  Future<List<Blog>> findAllPublishedForAuthor(User user) {
    return _findMany(
      whereClause: 'b.author_id = @authorId AND b.status = TRUE AND b.is_published = TRUE',
      params: {'authorId': user.id},
      orderBy: 'b.updated_at DESC',
    );
  }

  @override
  Future<List<Blog>> findAllDrafts() =>
      _findMany(whereClause: 'b.is_draft = TRUE AND b.status = TRUE', orderBy: 'b.updated_at DESC');

  @override
  Future<List<Blog>> findAllSubmissions() => _findMany(
        whereClause: 'b.is_submitted = TRUE AND b.status = TRUE',
        orderBy: 'b.updated_at DESC',
      );

  @override
  Future<List<Blog>> findAllPublished() =>
      _findMany(whereClause: 'b.is_published = TRUE AND b.status = TRUE', orderBy: 'b.updated_at DESC');

  @override
  Future<List<Blog>> findAllSubmissionsForWriter(User user) => _findMany(
        whereClause: 'b.author_id = @authorId AND b.status = TRUE AND b.is_submitted = TRUE',
        params: {'authorId': user.id},
        orderBy: 'b.updated_at DESC',
      );

  @override
  Future<List<Blog>> findAllPublishedForWriter(User user) => _findMany(
        whereClause: 'b.author_id = @authorId AND b.status = TRUE AND b.is_published = TRUE',
        params: {'authorId': user.id},
        orderBy: 'b.updated_at DESC',
      );

  @override
  Future<List<Blog>> findAllDraftsForWriter(User user) => _findMany(
        whereClause: 'b.author_id = @authorId AND b.status = TRUE AND b.is_draft = TRUE',
        params: {'authorId': user.id},
        orderBy: 'b.updated_at DESC',
      );

  @override
  Future<List<Blog>> findLatestBlogs(int pageNumber, int limit) async {
    final offset = _offset(pageNumber, limit);
    return _findMany(
      whereClause: 'b.status = TRUE AND b.is_published = TRUE',
      params: {'limit': limit, 'offset': offset},
      orderBy: 'b.published_at DESC NULLS LAST',
      limit: true,
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
      params: {'query': blog.title, 'title': blog.title, 'limit': limit, 'offset': 0},
      orderBy: '''
        ts_rank(
          to_tsvector('simple', coalesce(b.title,'') || ' ' || coalesce(b.description,'')),
          plainto_tsquery('simple', @query)
        ) DESC,
        b.updated_at DESC
      ''',
      limit: true,
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
      limit: true,
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
      limit: true,
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
    bool limit = false,
  }) async {
    final rows = await _runSelect(
      whereClause: whereClause,
      params: params,
      orderBy: orderBy,
      withLimit: limit,
    );
    return rows.map(_mapBlog).toList(growable: false);
  }

  Future<Result> _runSelect({
    required String whereClause,
    required Map<String, Object?> params,
    required String orderBy,
    bool withLimit = false,
    bool limitOne = false,
  }) async {
    try {
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
    } catch (e, st) {
      _log.severe('blog query failed', e, st);
      throw const InternalError();
    }
  }

  Blog _mapBlog(ResultRow row) {
    final author = User(
      id: row[17] as String,
      email: row[18] as String,
      name: row[19] as String,
      profilePicUrl: row[20] as String?,
      createdAt: row[21] as DateTime,
    );

    final createdBy = row[22] == null
        ? null
        : User(
            id: row[22] as String,
            email: row[23] as String,
            name: row[24] as String,
            profilePicUrl: row[25] as String?,
            createdAt: row[26] as DateTime,
          );

    final updatedBy = row[27] == null
        ? null
        : User(
            id: row[27] as String,
            email: row[28] as String,
            name: row[29] as String,
            profilePicUrl: row[30] as String?,
            createdAt: row[31] as DateTime,
          );

    final tagsRaw = row[5];
    final tags = switch (tagsRaw) {
      final List<dynamic> values => values.cast<String>(),
      _ => const <String>[],
    };

    return Blog(
      id: row[0] as String,
      title: row[1] as String,
      description: row[2] as String,
      text: row[3] as String?,
      draftText: row[4] as String?,
      tags: tags,
      author: author,
      imgUrl: row[6] as String?,
      blogUrl: row[7] as String,
      likes: row[8] as int?,
      score: row[9] as num,
      isSubmitted: row[10] as bool,
      isDraft: row[11] as bool,
      isPublished: row[12] as bool,
      status: row[13] as bool?,
      publishedAt: row[14] as DateTime?,
      createdAt: row[15] as DateTime?,
      updatedAt: row[16] as DateTime?,
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
