# 🔴 Audit Approfondi — Architecture Backend Dart

> **Posture** : Cet audit évalue le système comme s'il devait encaisser des millions de requêtes/jour en production distribuée. Aucun compliment, uniquement les failles.

---

## 1. Revue d'Architecture (Critique)

### 1.1 Frontières de modules : séparation logique, pas physique

Les dossiers (`core/`, `database/`, `cache/`, `services/`, `messaging/`, `workers/`) donnent une **illusion** de modularité. En réalité :

- Tout vit dans un seul package Dart (`dart_backend_architecture`). Il n'y a **aucune barrière de compilation** entre les couches. Rien n'empêche un handler de `routes/` d'importer directement `postgres.dart` et de court-circuiter le repository.
- Le fichier [composition_root.dart](file:///Users/macbookpro/StudioProjects/dart-backend-architecture/lib/di/composition_root.dart) importe **à la fois** les interfaces et les implémentations concrètes — c'est normal pour un composition root, mais les getters qui recréent des instances à chaque accès (lignes 114–128) sont un problème grave (voir §1.4).

### 1.2 Couplage entre couches — violations de la Clean Architecture

| Violation | Fichier | Détail |
|-----------|---------|--------|
| **Service → Infra concrète** | [auth_service.dart:10](file:///Users/macbookpro/StudioProjects/dart-backend-architecture/lib/services/auth_service.dart#L10) | `AuthService` importe `CryptoWorker` directement (classe concrète), pas une interface `PasswordHasher`. |
| **Repo → Repo** | [postgres_user_repo.dart:15](file:///Users/macbookpro/StudioProjects/dart-backend-architecture/lib/database/repository/impl/postgres_user_repo.dart#L15) | `PostgresUserRepo` dépend de `KeystoreRepo` et `RoleRepo`. Un repository qui orchestre d'autres repositories viole le SRP — c'est le travail d'un service. |
| **DTO dans le Service** | [auth_service.dart:21-52](file:///Users/macbookpro/StudioProjects/dart-backend-architecture/lib/services/auth_service.dart#L21-L52) | `LoginDto`, `SignupDto` et `AuthResult` sont définis dans le fichier du service au lieu d'être dans `core/` ou un module dédié. |

### 1.3 Direction des dépendances

```
routes/ → services/ → repositories (interfaces) ✅
routes/ → core/middleware/ → repositories (interfaces) ✅
composition_root → tout (normal pour DI) ✅
postgres_user_repo → keystore_repo, role_repo ❌ (repo→repo)
auth_service → CryptoWorker (concret) ❌
```

La direction est globalement correcte, **sauf** `PostgresUserRepo` qui est un mini-service déguisé en repository.

### 1.4 🔴 Composition Root — Faille critique : recréation d'instances à chaque accès

```dart
// composition_root.dart — lignes 114-128
PostgresUserRepo get _userRepo =>
    PostgresUserRepo(_db.pool, _keystoreRepo, _roleRepo);

PostgresKeystoreRepo get _keystoreRepo => PostgresKeystoreRepo(_db.pool);

PostgresRoleRepo get _roleRepo => PostgresRoleRepo(_db.pool);

UserCache get _userCache => UserCache(_cache);

BlogRepo get _cachingBlogRepo => CachingBlogRepo(
      inner: PostgresBlogRepo(_db.pool),
      cache: BlogCache(_cache),
    );
```

**Chaque appel au getter `router` crée :**
- 1 × `PostgresUserRepo` (qui crée aussi 1 × `PostgresKeystoreRepo` + 1 × `PostgresRoleRepo`)
- 1 × `PostgresBlogRepo` + 1 × `BlogCache` + 1 × `CachingBlogRepo`
- 1 × `AuthService` + 1 × `BlogService`
- 1 × `UserCache`

**Le getter `router` est appelé UNE SEULE FOIS** au démarrage dans `server.dart` ligne 217, donc aujourd'hui ce n'est pas un problème de performance. **Mais** c'est un piège architectural : si quelqu'un appelle `root.router` une seconde fois (monitoring, test, reload), il obtient des instances orphelines. Les repos devraient être `late final` et non des getters.

### 1.5 État global et singletons

| Risque | Localisation | Sévérité |
|--------|-------------|----------|
| `_startedAt` en top-level | [health_handler.dart:8](file:///Users/macbookpro/StudioProjects/dart-backend-architecture/lib/routes/health_handler.dart#L8) | Faible — sans conséquence |
| `_log` en top-level (multiple fichiers) | `nats_service.dart:8`, `cache_service.dart:6`, etc. | Faible — loggers sont thread-safe |
| `_errorCounter`, `_requestCounter`, `_durationHistogram` | [error_handler_middleware.dart:11](file:///Users/macbookpro/StudioProjects/dart-backend-architecture/lib/core/middleware/error_handler_middleware.dart#L11), [tracing_middleware.dart:9-10](file:///Users/macbookpro/StudioProjects/dart-backend-architecture/lib/core/middleware/tracing_middleware.dart#L9-L10) | **Moyen** — initialisés avec `??=` (non-atomique en théorie, mais safe dans le single-threaded event loop de Dart) |

### 1.6 Verdict Architecture

> **Ce qui cassera en premier sous charge** : l'absence de circuit-breaker sur les dépendances externes (DB, Redis, NATS). Si PostgreSQL ralentit, les requêtes s'empilent, le pool se sature, et l'effet cascade démarre.

> **Sur-ingéniéré** : le système d'isolates workers avec sémaphore pour le boot. Pour un serveur Shelf basique, `shared: true` + `HttpServer.bind` dans N isolates est bien, mais le sémaphore est de la complexité accidentelle qui ne résout pas un vrai problème (les pools DB gèrent déjà leur propre throttling de connexions).

> **Sous-ingéniéré** : le système de messaging (NATS) est fire-and-forget sans aucune garantie de livraison, aucun outbox pattern, aucune idempotency.

---

## 2. Concurrence & Modèle Runtime (Dart-spécifique)

### 2.1 Utilisation des isolates

| Isolate | Rôle | CPU/IO | Verdict |
|---------|------|--------|---------|
| Workers HTTP (N isolates) | Servent les requêtes | IO-bound | ✅ Correct |
| `CryptoWorker` | bcrypt hash/verify | CPU-bound | ✅ Correct — bcrypt bloque ~100ms |
| `JwtWorker` | RSA verify | CPU-bound | ✅ Correct — RSA ~0.5-2ms |

**Problème** : Chaque worker HTTP spawne son **propre** `CryptoWorker` et `JwtWorker` (via `CompositionRoot.initialize`). Avec `WORKER_COUNT=8` :
- 8 isolates HTTP + 8 CryptoWorker + 8 JwtWorker = **24 isolates** au total
- Chaque `CryptoWorker` ne traite qu'**une seule opération à la fois** (un seul `ReceivePort` avec traitement séquentiel)
- Sous charge, les signup/login se sérialisent **par isolate HTTP**, ce qui est correct pour bcrypt (on ne veut pas paralléliser le hachage par isolate)

### 2.2 🔴 Goulot d'étranglement critique : CryptoWorker est un singleton séquentiel par worker

```dart
// crypto_worker.dart — L'isolate traite les messages un par un
receivePort.listen((dynamic message) {
  switch (message) {
    case _HashRequest(:final plaintext, :final replyPort):
      // SYNCHRONE — bloque pendant ~100ms (bcrypt logRounds: 12)
      final hash = _bcryptHash(plaintext);
      replyPort.send(hash);
```

Si 100 utilisateurs font signup simultanément sur le même worker isolate, les 100 opérations bcrypt se sérialisent (~10 secondes de latence pour le dernier). Ce n'est **pas** un bug en soi (on veut limiter la charge CPU), mais il n'y a **aucun mécanisme de backpressure** : pas de file d'attente bornée, pas de rejet si la file est pleine.

### 2.3 🟡 Contention sur Redis

`CacheService` utilise **une seule connexion Redis** (`RedisConnection` / `Command`) par worker isolate. Toutes les opérations Redis d'un worker se sérialisent sur cette connexion unique. Sous forte charge :
- Le rate-limiter (INCR + EXPIRE par requête)
- Le cache auth (GET keystore, GET user profile)
- Le cache blog (GET/SET)

...tout passe par le **même tuyau TCP**. La bibliothèque `redis` 4.x n'a pas de pipelining automatique. Chaque commande attend la réponse avant d'envoyer la suivante.

### 2.4 Message passing design

Le protocole entre main isolate et workers est propre (sealed classes, `WorkerReady`/`ShutdownAck`). Le sémaphore pour le boot est élégant mais complexe.

**Risque d'isolate spawning** : Le `_isolateErrorPort` (ligne 358–363) log l'erreur mais ne relance **jamais** le worker. En production, un worker crashé (OOM, exception non catchée) réduit silencieusement la capacité du serveur. Le `TODO` à la ligne 361 le confirme.

---

## 3. Couche Données & PostgreSQL

### 3.1 Risques N+1

| Méthode | Problème | Sévérité |
|---------|----------|----------|
| `PostgresBlogRepo.create()` | INSERT puis re-SELECT complet (ligne 122: `findBlogAllDataById(id)`) | 🟡 2 requêtes au lieu d'un RETURNING complet |
| `PostgresUserRepo.create()` | INSERT user → INSERT user_role → `findById()` → `keystoreRepo.create()` = **4 requêtes séparées** | 🔴 **Pas de transaction** |
| `BlogService.update()` | `findBlogAllDataById` (pour détecter l'événement) puis `_blogRepo.update()` = 2 requêtes | 🟡 Requête supplémentaire pour la détection d'événement |

### 3.2 🔴 Absence de transactions dans `PostgresUserRepo.create()`

```dart
// postgres_user_repo.dart — lignes 46-87
final result = await _pool.execute(/* INSERT user */);
final userId = result.first[0] as String;
await _pool.execute(/* INSERT user_role */);            // ← PAS dans une transaction
final createdUser = await findById(userId);              // ← Requête 3
final keystore = await _keystoreRepo.create(...);        // ← Requête 4
```

Si le serveur crash entre l'INSERT user et l'INSERT user_role, on obtient un utilisateur sans rôle. Si le crash survient avant `keystoreRepo.create()`, on a un utilisateur sans keystore → **impossible de se connecter**.

Le commentaire dans `auth_service.dart` ligne 105 dit : _"creates user + keystore atomically in a single transaction"_ — **c'est faux**. Il n'y a aucune transaction.

### 3.3 Connection pooling

```dart
// db_pool.dart
PoolSettings(
  maxConnectionCount: maxConnections,  // default 20
  connectTimeout: Duration(seconds: 5),
  queryTimeout: Duration(seconds: 30),
)
```

- Avec `WORKER_COUNT=8` et `DB_POOL_SIZE=20` → **160 connexions PostgreSQL**. Le défaut PostgreSQL est `max_connections=100`. **Le serveur ne démarrera pas** avec les réglages par défaut.
- `queryTimeout: 30s` est excessif pour un backend API. Une requête bloquée 30 secondes occupe une connexion du pool. Avec 20 connexions et des timeouts de 30s, 20 requêtes lentes suffisent à saturer un worker entier.

### 3.4 Abstraction leakage dans les repositories

- `_mapBlog()` (ligne 425) accède aux colonnes par **index numérique** (`row[17]`, `row[22]`, etc.) — fragile, tout changement dans le SELECT casse le mapping silencieusement.
- `findInfoById`, `findInfoWithTextById`, `findInfoWithTextAndDraftTextById`, `findBlogAllDataById` — ces **4 méthodes** exécutent exactement la **même requête SQL** (même `_baseSelect`, même `whereClause`). La distinction de "projection" (info seul, avec texte, avec draft) n'existe pas côté SQL — c'est du code mort.

### 3.5 Verdict : la DB sera-t-elle le premier goulot ?

**Oui, sans aucun doute.** Raisons :

1. **160 connexions** avec les défauts → crash au boot
2. **Aucune transaction** → corruption de données possible
3. **Query timeout à 30s** → saturation de pool sous charge
4. Les requêtes non-paginées (`findAllPublished`, `findAllDrafts`, `findAllSubmissions`) retournent **toutes** les lignes → OOM + latence linéaire
5. Les requêtes full-text search (`to_tsvector` à la volée dans le WHERE) sont indexées (GIN), c'est bien, mais le `ORDER BY ts_rank(...)` force un **seq scan** sur les résultats filtrés

---

## 4. Stratégie de Cache (Redis)

### 4.1 Stratégie d'invalidation

Le pattern `CachingBlogRepo` (decorator) est propre architecturalement. L'invalidation est :
- **Par clé unitaire** : `evictById` + `evictByUrl` après chaque write ✅
- **Par pattern** : `evictAllLists` utilise `SCAN + DEL` pour invalider `blogs:*` ✅

### 4.2 🔴 Cache stampede (effet de troupeau)

```dart
// blog_cache.dart — getByIdWithLoader()
final cached = await _get(CacheKeys.blog(id));
if (cached != null) return cached;

final fresh = await loader();  // ← N requêtes concurrentes = N hits DB simultanés
```

Quand une clé populaire expire (TTL 1h), **toutes** les requêtes concurrentes ratent le cache et frappent la DB simultanément. Pas de mutex, pas de singleflight, pas de probabilistic early expiration.

**Même problème** dans `CacheService.getOrSet()` — le pattern cache-aside est naïf.

### 4.3 Modèle de cohérence

- **Eventual consistency** avec fenêtre de TTL (1h blogs, 30min users, 5min keystores)
- **Risque** : entre un `update()` et le `evictById()`, un autre worker peut lire la valeur périmée. Avec N workers chacun ayant son propre CacheService pointant vers le même Redis, c'est correct car Redis est partagé. Mais le **double-write** (`_evictSingleBestEffort` + `_evictListsBestEffort`) n'est pas atomique.

### 4.4 🟡 `invalidatePattern` utilise SCAN — coûteux

```dart
// cache_service.dart — lignes 60-85
var cursor = '0';
do {
  final result = await _execute(
    (cmd) => cmd.send_object(['SCAN', cursor, 'MATCH', pattern, 'COUNT', 200]),
  );
  // ...
  await _execute((cmd) => cmd.send_object(['DEL', ...keys]));
} while (cursor != '0');
```

`SCAN` sur un Redis avec des millions de clés est O(N). Chaque mutation de blog déclenche un `evictAllLists()`. À 1000 writes/min, ça génère 1000 SCAN complets. Solution : utiliser des tags Redis ou un namespace avec TTL au lieu de SCAN.

### 4.5 Isolation via decorator pattern

`CachingBlogRepo` est un bon exemple de decorator. **Mais** il n'existe **pas** pour `UserRepo` ni `KeystoreRepo`. Le cache user/keystore est fait dans le middleware `auth_middleware.dart` directement (inline, mélangé avec la logique d'authentification). Inconsistance architecturale.

---

## 5. Messaging & NATS

### 5.1 Design des événements

Les sujets sont bien nommés et granulaires : `user.signed_up`, `user.logged_in`, `blog.created`, `blog.published`, etc. **Mais** :

- Il n'y a **aucun subscriber** dans tout le codebase. Les événements sont publiés dans le vide. Le système de messaging est une coquille vide.
- Pas de schema/contrat pour les payloads des événements. Les `Map<String, dynamic>` sont envoyés sans validation.

### 5.2 🔴 Garanties de fiabilité : inexistantes

```dart
// nats_service.dart — publish()
Future<void> publish(String subject, Map<String, dynamic> payload) async {
  await _ensureConnected();
  try {
    await _client.pubString(subject, jsonEncode(payload));
  } catch (e) {
    _connected = false;
    await _ensureConnected();
    try {
      await _client.pubString(subject, jsonEncode(payload));  // retry une fois
    } catch (e) {
      _log.warning('NATS publish failed after retry [$subject]: $e');
      // → L'ÉVÉNEMENT EST PERDU SILENCIEUSEMENT
    }
  }
}
```

- **Pas d'at-least-once delivery** : un publish échoué est juste loggé en warning.
- **Pas de NATS JetStream** : utilisation du core NATS pur (fire-and-forget).
- **Pas d'outbox pattern** : les événements ne sont pas écrits en DB dans la même transaction que la mutation.
- **Pas d'idempotency** : aucun ID d'événement, aucun mécanisme de déduplication.

### 5.3 `NoOpEventBus` en production ?

Le fallback `NoOpEventBus` est utilisé quand NATS est down ou non configuré. En production, si NATS crash temporairement, le système bascule silencieusement vers le NoOp et **tous les événements sont perdus**. Aucune alerte, aucun mécanisme de replay. Le log dit juste `NoOpEventBus: dropped event [topic]` en level `info` — devrait être `warning`.

---

## 6. Modes de Défaillance

### Top 10 des scénarios de panne réalistes

| # | Scénario | Comportement | Cascade ? | Dégradation gracieuse ? |
|---|----------|-------------|-----------|------------------------|
| 1 | **PostgreSQL down** | Toutes les requêtes échouent immédiatement (pool.execute throw). Error handler retourne 500. | ❌ Non, mais 100% indisponible | ❌ Non — aucun mode dégradé |
| 2 | **PostgreSQL lent (100ms→5s)** | Les connexions du pool se saturent. Les requêtes s'empilent pendant 30s (queryTimeout). Le worker HTTP entier est bloqué. | 🔴 **OUI — cascade totale** | ❌ Non — pas de circuit-breaker |
| 3 | **Redis down** | Cache miss → toutes les requêtes frappent la DB. Rate limiter bypassed (fail-open). | 🟡 Charge DB explose | 🟡 Partiel — le service continue mais la DB souffre |
| 4 | **Redis lent** | Chaque requête ajoute 2-5s de latence (GET cache + reconnect tentative). | 🔴 **OUI — latence cascade** | ❌ Non — pas de timeout sur les opérations Redis individuelles |
| 5 | **NATS down** | Fallback NoOpEventBus, événements perdus. Aucun impact sur les requêtes. | ❌ Non | ✅ Oui |
| 6 | **Worker isolate crash** | Le main isolate log l'erreur. Le port `shared: true` redistribue le trafic. Mais le worker est **perdu pour toujours** — pas de restart. | 🟡 Capacité réduite de 1/N | 🟡 Partiel — trafic redistribué mais capacité réduite |
| 7 | **OOM sur un worker** | L'isolate est tué par l'OS. Même effet que #6, mais potentiellement d'autres workers sont affectés si la mémoire est partagée au niveau du processus. | 🔴 **OUI — tout le processus peut être tué** | ❌ Non — Dart isolates partagent le même processus |
| 8 | **Expiration massive de cache** | Stampede : N workers × M requêtes concurrentes frappent la DB pour la même clé. | 🔴 **OUI — DB saturée** | ❌ Non — pas de singleflight |
| 9 | **Clé PEM invalide/manquante au boot** | `JwtService._loadKeys()` throw `InternalError`. Le worker crash. | ❌ Non — crash au boot est clean | ✅ Oui — fail fast |
| 10 | **Attaque de signup en masse** | Chaque signup = bcrypt hash (100ms) sérialisé dans le CryptoWorker. 1000 signups = 100s de queue. | 🟡 Signups légitimes timeout | ❌ Non — pas de rate-limit par endpoint, seulement par IP |

### Le scénario le plus dangereux : #2 (PostgreSQL lent)

Chronologie d'un incident :
1. PostgreSQL commence à ralentir (vacuum, lock contention, requête full-text coûteuse)
2. Les 20 connexions du pool se bloquent sur des requêtes de 5-30s
3. Les nouvelles requêtes attendent une connexion libre (connectTimeout: 5s)
4. Le CryptoWorker continue à tourner (pas affecté), mais les réponses ne partent pas car le handler attend la DB
5. Les requêtes HTTP s'empilent dans Shelf
6. Les clients timeout et retry → amplification de charge
7. **Tout le worker est down** en ~30-60 secondes

**Remède manquant** : circuit-breaker avec half-open state, query timeout agressif (3-5s max), shedding de charge.

---

## 7. Verdict de Scalabilité

### Limites actuelles estimées

| Ressource | Limite | Raison |
|-----------|--------|--------|
| **CPU** | ~2000 req/s (lecture), ~100 req/s (signup/login) | bcrypt = 100ms par hash, sérialisé par worker |
| **DB connexions** | `WORKER_COUNT × DB_POOL_SIZE` — crash si > PG `max_connections` | Pas de pool global, chaque worker a son pool |
| **Redis** | ~5000 ops/s par worker (une seule connexion TCP sans pipelining) | Bibliothèque `redis` 4.x est primitive |
| **Messaging** | Illimité (fire-and-forget) | Pas un goulot mais pas fiable non plus |
| **Mémoire** | Risque OOM sur les requêtes non-paginées (`findAllPublished`, etc.) | Charge toutes les lignes en mémoire |

### Scalabilité horizontale : est-ce possible tel quel ?

**Partiellement.** Le modèle multi-isolate + `shared: true` permet de scaler verticalement (plus de cores). Pour scaler horizontalement (plusieurs machines) :

- ✅ Le serveur est stateless (pas de session en mémoire)
- ✅ Redis est centralisé (rate limiter et cache partagés)
- ❌ **Pas de mécanisme de découverte de service**
- ❌ **Pas de distributed locking** (deux instances peuvent créer le même utilisateur en race condition)
- ❌ **Le rate limiter utilise l'IP** — derrière un load balancer, toutes les requêtes viennent de la même IP interne
- ❌ **Les keystores ne sont pas nettoyés** — ils s'accumulent sans limite en DB

### Pour scaler ×10 (10M req/jour)

| Priorité | Action |
|----------|--------|
| **P0** | Fixer les connexions DB (`WORKER_COUNT × DB_POOL_SIZE` < PG `max_connections`) |
| **P0** | Ajouter des transactions dans `UserRepo.create()` |
| **P0** | Paginer TOUTES les requêtes de liste |
| **P1** | Ajouter un circuit-breaker sur PostgreSQL et Redis |
| **P1** | Remplacer `redis` 4.x par une bibliothèque avec connection pooling |
| **P2** | Implémenter singleflight/mutex sur le cache-aside |

### Pour scaler ×100 (100M req/jour)

| Priorité | Action |
|----------|--------|
| **P0** | Migrer vers NATS JetStream + outbox pattern |
| **P0** | Read replicas PostgreSQL pour les lectures |
| **P0** | Connection pooler externe (PgBouncer) |
| **P1** | Séparer les workers de lecture et d'écriture |
| **P1** | Sharding du cache par namespace |
| **P2** | CDN pour les blog contents statiques |

---

## 8. Recommandations Concrètes

### 🔴 Haute priorité — À faire avant production

#### 8.1 Ajouter des transactions dans `PostgresUserRepo.create()`

```dart
// Remplacer les 4 requêtes séparées par :
await _pool.runTx((session) async {
  await session.execute(/* INSERT user */);
  await session.execute(/* INSERT user_role */);
  await session.execute(/* INSERT keystore */);
});
```

**Impact** : empêche les utilisateurs orphelins sans rôle ni keystore.

#### 8.2 Convertir les getters en `late final` dans `CompositionRoot`

```dart
// Au lieu de :
PostgresUserRepo get _userRepo => PostgresUserRepo(_db.pool, _keystoreRepo, _roleRepo);

// Faire :
late final _userRepo = PostgresUserRepo(_db.pool, _keystoreRepo, _roleRepo);
late final _keystoreRepo = PostgresKeystoreRepo(_db.pool);
late final _roleRepo = PostgresRoleRepo(_db.pool);
// etc.
```

**Impact** : une seule instance par dépendance, comportement prévisible.

#### 8.3 Réduire `queryTimeout` de 30s à 5s

```dart
PoolSettings(
  queryTimeout: const Duration(seconds: 5),  // au lieu de 30
)
```

**Impact** : empêche la saturation du pool par des requêtes lentes.

#### 8.4 Paginer les requêtes de liste non-bornées

`findAllPublished()`, `findAllDrafts()`, `findAllSubmissions()` etc. — toutes ces méthodes n'ont **aucun LIMIT**. Ajouter une pagination obligatoire.

#### 8.5 Implémenter le restart automatique des workers crashés

```dart
// server.dart — remplacer le TODO de _isolateErrorPort
RawReceivePort _isolateErrorPort(int workerId, Logger log) {
  return RawReceivePort((dynamic error) {
    log.severe('[worker-$workerId] Uncaught error: $error');
    // Respawn l'isolate après un backoff
    Future.delayed(Duration(seconds: 2), () => _respawnWorker(workerId));
  });
}
```

#### 8.6 Aligner `WORKER_COUNT × DB_POOL_SIZE` < `max_connections`

Avec le docker-compose actuel, `WORKER_COUNT=1` et `DB_POOL_SIZE=20` par défaut → 20 connexions. OK pour dev. Mais **documenter** la formule et ajouter une validation au boot.

---

### 🟡 Priorité moyenne — Amélioration significative

#### 8.7 Ajouter un circuit-breaker pour la DB et Redis

Quand le taux d'erreur dépasse un seuil, court-circuiter les appels pendant N secondes au lieu de continuer à envoyer des requêtes vers un service en détresse.

#### 8.8 Extraire une interface `PasswordHasher` pour `CryptoWorker`

```dart
abstract interface class PasswordHasher {
  Future<String> hashPassword(String plaintext);
  Future<bool> verifyPassword(String plaintext, String hash);
}
```

**Impact** : respecte la Clean Architecture, facilite les tests.

#### 8.9 Protéger le cache contre le stampede

Implémenter un mécanisme de singleflight :
```dart
final _inflight = <String, Future<T>>{};

Future<T> getOrSetOnce<T>(String key, Future<T> Function() loader, ...) async {
  if (_inflight.containsKey(key)) return _inflight[key]! as Future<T>;
  final future = _doGetOrSet(key, loader, ...);
  _inflight[key] = future;
  try { return await future; } finally { _inflight.remove(key); }
}
```

#### 8.10 Utiliser des noms de colonnes au lieu d'index numériques

```dart
// Au lieu de row[17], row[22], etc.
// Utiliser row.toColumnMap() ou des named columns
```

#### 8.11 Ajouter un timeout sur les opérations Redis individuelles

`CacheService._execute()` n'a aucun timeout. Si Redis freeze, la requête HTTP attend indéfiniment.

#### 8.12 Supprimer les méthodes repository dupliquées

`findInfoById`, `findInfoWithTextById`, `findInfoWithTextAndDraftTextById`, `findBlogAllDataById` exécutent la même requête SQL. Consolider en une seule méthode ou différencier réellement les projections SQL.

---

### ⚪ Optionnel — Optimisations

#### 8.13 Migrer vers NATS JetStream pour l'at-least-once delivery

#### 8.14 Implémenter un outbox pattern pour les événements critiques

#### 8.15 Ajouter un pool de `CryptoWorker` au lieu d'un singleton

Pour scaler le signup, on peut avoir 2-4 CryptoWorkers par isolate HTTP et distribuer les hash avec un round-robin.

#### 8.16 Remplacer la bibliothèque `redis` 4.x

Utiliser `resp_client` ou une bibliothèque supportant le pipelining et le connection pooling.

#### 8.17 Ajouter des rate limits par endpoint

Le rate limiter actuel est global (100 req/min par IP). Les endpoints sensibles (signup, login) devraient avoir des limites spécifiques plus strictes.

#### 8.18 Nettoyer les keystores périmés

Aucun mécanisme de garbage collection sur la table `keystores`. Chaque login crée une nouvelle entrée. Après 1M logins → 1M lignes dans `keystores`.

---

## Résumé Exécutif

| Dimension | Score | Commentaire |
|-----------|-------|-------------|
| Architecture | 🟡 6/10 | Bonne structure mais violations Clean Architecture et getters non-singletons |
| Concurrence | 🟢 7/10 | Utilisation correcte des isolates, manque le restart automatique |
| Données (PostgreSQL) | 🔴 4/10 | Pas de transactions, requêtes non-paginées, pool sizing dangereux |
| Cache (Redis) | 🟡 5/10 | Bon pattern decorator, mais stampede, SCAN coûteux, pas de timeout |
| Messaging (NATS) | 🔴 3/10 | Coquille vide — fire-and-forget sans subscribers ni garanties |
| Résilience | 🔴 3/10 | Pas de circuit-breaker, pas de restart d'isolate, cascade certaine sur DB lente |
| Scalabilité horizontale | 🟡 5/10 | Stateless mais rate limiter naïf, pas de distributed locking |

**Verdict global** : Le codebase est un **bon squelette d'architecture** avec des patterns modernes (decorator, composition root, isolates), mais il **n'est pas prêt pour la production à grande échelle**. Les trois failles les plus critiques sont : l'absence de transactions, le risque de cascade sur DB lente, et le système de messaging non-fiable.
