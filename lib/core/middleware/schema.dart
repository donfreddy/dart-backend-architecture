import 'package:zema/zema.dart';

final apiKeyHeaderSchema = z.object({
  'x-api-key': z.string(),
});

final authHeaderSchema = z.object({
  'authorization': z.string().min(8),
});
