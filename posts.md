## r/dartlang

**Title:** I built a production-ready Dart backend architecture (Shelf, PostgreSQL, Redis, NATS)

```
I spent weeks porting the AfterAcademy Node.js architecture to pure Dart
— no code generation, no service locator, no magic.

What it shows:
• Dedicated isolates for BCrypt + RSA JWT → the HTTP event loop stays uncontested
• Sealed ApiError hierarchy with pattern matching → no more unreadable stack traces
• Single Composition Root → all dependency wiring in one file
• Caching decorator (Redis) wrapping Postgres repo → the service layer is cache-unaware
• OpenTelemetry + NATS → distributed tracing and async messaging

Stack: shelf, postgres (raw SQL), redis, dart_nats, dart_jsonwebtoken, zema

The project: https://github.com/donfreddy/dart-backend-architecture

Dart is criminally underrated for backend. Change my mind.
```

---

## r/programming

**Title:** I rebuilt a production Node.js backend architecture in pure Dart — here's what I learned

```
I've been working on a reference backend architecture in Dart, porting the popular
AfterAcademy Node.js design. The results surprised me.

Key differences:
• No event loop blocking — CPU-bound work (bcrypt, RSA verify) runs in dedicated
  Dart isolates, not on the HTTP thread
• Sealed error hierarchy with exhaustive pattern matching instead of ad-hoc error classes
• Decorator-based caching — a CachingBlogRepo transparently wraps PostgresBlogRepo
  with Redis read-through, zero changes to the service layer
• Multi-isolate server — each CPU core runs a separate isolate sharing the same port
• Fail-open design — Redis outage never kills a request, rate limiter bypasses silently
• Single Composition Root for all dependency wiring (no service locator, no DI framework)

Stack: Dart 3, Shelf, PostgreSQL, Redis, NATS, OpenTelemetry

The code is MIT, clean, and documented:
https://github.com/donfreddy/dart-backend-architecture

Happy to answer architecture questions. What's your take on Dart for backend?
```

**Title:** I rebuilt a production Node.js backend architecture in pure Dart (here's what I learned)

A few weeks ago, I started porting the architecture from the AfterAcademy Node.js backend series to pure Dart.

The goal wasn't to prove that Dart is "better" than Node.js, but to explore what a modern backend architecture looks like when built around Dart's strengths.

Some interesting observations:

• CPU-intensive operations such as BCrypt hashing and RSA JWT verification can be offloaded to dedicated isolates, keeping HTTP request handling responsive

• Dart's sealed classes and pattern matching make error handling surprisingly elegant compared to large hierarchies of exception classes

• The Decorator pattern works extremely well for cross-cutting concerns like caching. A Redis-backed repository can wrap a PostgreSQL repository without leaking cache logic into the service layer

• Running multiple server isolates across CPU cores feels closer to a built-in concurrency model than an afterthought

• Infrastructure failures don't have to cascade. In this project, Redis outages degrade functionality gracefully instead of taking down requests

• Keeping all dependency wiring in a single Composition Root made the codebase easier to reason about than previous projects where dependencies were scattered across modules

Stack:

* Dart 3
* Shelf
* PostgreSQL
* Redis
* NATS
* OpenTelemetry

The project is open source (MIT):

https://github.com/donfreddy/dart-backend-architecture

One thing that surprised me is how mature backend development in Dart feels today, despite receiving far less attention than ecosystems like Node.js, Go, or Java.

For those who've used Dart on the server side: what worked well for you, and what didn't?
