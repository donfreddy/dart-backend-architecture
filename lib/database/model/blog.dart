import 'package:dart_backend_architecture/database/model/user.dart';

final class Blog {
  final String title;
  final String description;
  final String? text;
  final String? draftText;
  final List<String> tags;
  final User author;
  final String? imgUrl;
  final String blogUrl;
  final int? likes;
  final num score;
  final bool isSubmitted;
  final bool isDraft;
  final bool isPublished;
  final bool? status;
  final DateTime? publishedAt;
  final User? createdBy;
  final User? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Blog({
    required this.title,
    required this.description,
    this.text,
    this.draftText,
    required this.tags,
    required this.author,
    this.imgUrl,
    required this.blogUrl,
    this.likes,
    required this.score,
    required this.isSubmitted,
    required this.isDraft,
    required this.isPublished,
    this.status,
    this.publishedAt,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  Blog copyWith({
    String? title,
    String? description,
    String? text,
    String? draftText,
    List<String>? tags,
    User? author,
    String? imgUrl,
    String? blogUrl,
    int? likes,
    num? score,
    bool? isSubmitted,
    bool? isDraft,
    bool? isPublished,
    bool? status,
    DateTime? publishedAt,
    User? createdBy,
    User? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Blog(
      title: title ?? this.title,
      description: description ?? this.description,
      text: text ?? this.text,
      draftText: draftText ?? this.draftText,
      tags: tags ?? this.tags,
      author: author ?? this.author,
      imgUrl: imgUrl ?? this.imgUrl,
      blogUrl: blogUrl ?? this.blogUrl,
      likes: likes ?? this.likes,
      score: score ?? this.score,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      isDraft: isDraft ?? this.isDraft,
      isPublished: isPublished ?? this.isPublished,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Blog.fromJson(Map<String, dynamic> json) {
    return Blog(
      title: json['title'] as String,
      description: json['description'] as String,
      text: json['text'] as String?,
      draftText: json['draft_text'] as String?,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      imgUrl: json['img_url'] as String?,
      blogUrl: json['blog_url'] as String,
      likes: json['likes'] as int?,
      score: (json['score'] as num),
      isSubmitted: json['is_submitted'] as bool,
      isDraft: json['is_draft'] as bool,
      isPublished: json['is_published'] as bool,
      status: json['status'] as bool?,
      publishedAt: _readDateTime(json['published_at']),
      createdBy: _readUser(json['created_by']),
      updatedBy: _readUser(json['updated_by']),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      if (text != null) 'text': text,
      if (draftText != null) 'draft_text': draftText,
      'tags': tags,
      'author': author.toJson(),
      if (imgUrl != null) 'img_url': imgUrl,
      'blog_url': blogUrl,
      if (likes != null) 'likes': likes,
      'score': score,
      'is_submitted': isSubmitted,
      'is_draft': isDraft,
      'is_published': isPublished,
      if (status != null) 'status': status,
      if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy!.toJson(),
      if (updatedBy != null) 'updated_by': updatedBy!.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Blog &&
        other.title == title &&
        other.blogUrl == blogUrl &&
        other.author == author;
  }

  @override
  int get hashCode => Object.hash(title, blogUrl, author);

  @override
  String toString() => 'Blog(title: $title, blogUrl: $blogUrl)';
}

DateTime? _readDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.parse(value as String);
}

User? _readUser(Object? value) {
  if (value == null) return null;
  return User.fromJson(value as Map<String, dynamic>);
}
