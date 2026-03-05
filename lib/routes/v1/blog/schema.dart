import 'package:zema/zema.dart';

final blogUrlQuerySchema = z.object({
  'endpoint': z.string().min(1),
});

final blogIdParamSchema = z.object({
  'id': z.string().min(1),
});

final blogTagParamSchema = z.object({
  'tag': z.string().min(1),
});

final authorIdParamSchema = z.object({
  'id': z.string().min(1),
});

final blogPaginationQuerySchema = z.object({
  'pageNumber': z.coerce().integer(min: 1).withDefault(1),
  'pageItemCount': z.coerce().integer(min: 1).withDefault(10),
});

final blogCreateSchema = z.object({
  'title': z.string().min(1),
  'description': z.string().min(1),
  'text': z.string().min(1),
  'tags': z.array(z.string().min(1)).min(1),
  'blogUrl': z.string().min(1),
  'imgUrl': z.string().url().optional(),
  'score': z.coerce().integer(min: 0).withDefault(0),
});

final blogUpdateSchema = z.object({
  'title': z.string().min(1).optional(),
  'description': z.string().min(1).optional(),
  'text': z.string().min(1).optional(),
  'tags': z.array(z.string().min(1)).min(1).optional(),
  'blogUrl': z.string().min(1).optional(),
  'imgUrl': z.string().url().optional(),
  'score': z.coerce().integer(min: 0).optional(),
});
