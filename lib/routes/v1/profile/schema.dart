import 'package:zema/zema.dart';

final profileUserIdSchema = z.object({
  'id': z.string().min(1),
});

final profileUpdateSchema = z.object({
  'name': z.string().min(3).optional(),
  'profilePicUrl': z.string().url().optional(),
});
