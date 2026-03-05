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
