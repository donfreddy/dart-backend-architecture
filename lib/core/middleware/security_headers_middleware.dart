import 'package:shelf/shelf.dart';

/// Adds security-related HTTP response headers on every response.
///
/// Covers OWASP A05 (Security Misconfiguration) baseline:
/// - [X-Content-Type-Options] prevents MIME-sniffing attacks.
/// - [X-Frame-Options] blocks clickjacking via iframes.
/// - [Strict-Transport-Security] enforces HTTPS for 1 year (includeSubDomains).
/// - [Content-Security-Policy] denies all resource loading by default (pure API).
/// - [Referrer-Policy] limits referrer leakage on cross-origin requests.
/// - [X-XSS-Protection] set to 0 per modern browser guidance (CSP replaces it).
///
/// Should be placed near the top of the pipeline, after error handling and
/// tracing, so that security headers are present on all responses including
/// error ones.
Middleware securityHeadersMiddleware() {
  const headers = <String, String>{
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '0',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'Content-Security-Policy': "default-src 'none'",
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
  };

  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      return response.change(headers: {...response.headers, ...headers});
    };
  };
}
