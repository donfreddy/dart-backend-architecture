import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

abstract final class Security {
  Security._();

  static final _random = Random.secure();

  // ── Random tokens ────────────────────────────────────────────

  // Cryptographically secure random string — used for API keys, reset tokens
  static String generateToken([int byteLength = 32]) {
    final bytes = Uint8List(byteLength);
    for (var i = 0; i < byteLength; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // Short numeric OTP — for email / SMS verification
  static String generateOtp([int digits = 6]) {
    final max = pow(10, digits).toInt();
    return _random.nextInt(max).toString().padLeft(digits, '0');
  }

  // ── Hashing ───────────────────────────────────────────────────

  // SHA-256 — for API key hashing before DB storage
  // Never store raw API keys in the database
  static String sha256Hash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  // HMAC-SHA256 — for webhook signature verification
  static String hmacSha256(String payload, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  // ── Comparison ────────────────────────────────────────────────

  // Constant-time string comparison — prevents timing attacks
  // Use this whenever comparing secrets, tokens, or hashes
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  // ── API key ───────────────────────────────────────────────────

  // Generate a prefixed API key — easy to identify in logs and scanners
  // Format: dba_<random> — e.g. dba_Xk9mP2qL...
  static ({String raw, String hashed}) generateApiKey() {
    final raw = 'dba_${generateToken(24)}';
    final hashed = sha256Hash(raw);
    return (raw: raw, hashed: hashed);
  }

  // ── Bearer token extraction ───────────────────────────────────

  static String? extractBearer(String? authorizationHeader) {
    if (authorizationHeader == null) return null;
    if (!authorizationHeader.startsWith('Bearer ')) return null;
    final token = authorizationHeader.substring(7).trim();
    return token.isEmpty ? null : token;
  }
}