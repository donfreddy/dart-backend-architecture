import 'package:zema/zema.dart';

final userCredentialSchema = z.object({
  'email': z.string().email(),
  'password': z.string().min(6),
});

final refreshTokenSchema = z.object({
  'refresh_token': z.string().min(1),
});

final authHeaderSchema = z.object({
  'authorization': z.string().min(8),
});

final signupSchema = z.object({
  'name': z.string().min(3),
  'email': z.string().email(),
  'password': z.string().min(6),
  'profile_pic_url': z.string().url().optional(),
});
