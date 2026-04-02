import 'package:zema/zema.dart';

final blogUrlQuerySchema = z.object({
  'endpoint': z.string().min(1),
});

final blogIdParamSchema = z.object({
  'id': z.string().uuid(),
});

final blogTagParamSchema = z.object({
  'tag': z.string().uuid(),
});

final authorIdParamSchema = z.object({
  'id': z.string().uuid(),
});

final blogPaginationQuerySchema = z.object({
  'page_number': z.coerce().integer(min: 1).withDefault(1),
  'page_item_count': z.coerce().integer(min: 1).withDefault(10),
});

final blogCreateSchema = z.object({
  'title': z.string().min(1),
  'description': z.string().min(1),
  'text': z.string().min(1),
  'tags': z.array(z.string().min(1)).min(1),
  'blog_url': z.string().min(1),
  'img_url': z.string().url().optional(),
  'score': z.integer().withDefault(0),
});

final blogUpdateSchema = z.object({
  'title': z.string().min(1).optional(),
  'description': z.string().min(1).optional(),
  'text': z.string().min(1).optional(),
  'tags': z.array(z.string().min(1)).min(1).optional(),
  'blog_url': z.string().min(1).optional(),
  'img_url': z.string().url().optional(),
  'score': z.coerce().integer(min: 0).optional(),
});
