---
description: Vert.x Standard Coding Style and Best Practices
applyTo: **/*.java
---

## 1. Logging

- Include meaningful and traceable logs at every significant operation boundary
- Every log must include a **trace/correlation ID** for end-to-end request tracking
- Never log sensitive data (passwords, tokens, PII, credit card numbers)
- Use structured logging with consistent fields: `traceId`, `action`, `status`, `durationMs`
- Log at appropriate levels: `DEBUG` for flow details, `INFO` for key lifecycle events, `WARN` for recoverable issues, `ERROR` for failures with stack traces
- Always log async failures in `.onFailure()` before propagating or responding

```java
// Good
log.info("Fetching order traceId={} orderId={}", traceId, orderId);
future.onFailure(err -> log.error("Failed to fetch order traceId={} orderId={}", traceId, orderId, err));

// Bad — no traceId, logs sensitive data
log.info("User {} logged in with password {}", user, password);
```

---

## 2. Naming Conventions

Follow **Google Java Style Guide** strictly.

| Element | Convention | Example |
|---|---|---|
| Classes | PascalCase | `OrderService` |
| Verticles | PascalCase + `Verticle` suffix | `OrderVerticle` |
| Methods | camelCase | `findOrderById` |
| Route handlers | camelCase prefixed with `handle` | `handleGetOrder` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Packages | lowercase, dot-separated | `com.example.order` |

---

## 3. REST API Design

- Use **plural nouns** for resources: `/api/v1/orders`, not `/api/v1/order`
- No verbs in paths — use HTTP methods to express intent
- Use **kebab-case** for multi-word resources: `/order-items`, `/shipping-addresses`
- Version all public APIs: `/api/v1/...`
- Use proper HTTP status codes:
  - `200 OK` — successful GET/PUT
  - `201 Created` — successful POST (include `Location` header)
  - `204 No Content` — successful DELETE
  - `400 Bad Request` — invalid input
  - `404 Not Found` — resource missing
  - `409 Conflict` — state conflict
  - `500 Internal Server Error` — unexpected server failure
- Always return a consistent error response body: `{ "traceId": "...", "code": "...", "message": "..." }`

---

## 4. Vert.x Async & Event Loop

### Golden Rule
**NEVER block the event loop thread.** No `Thread.sleep()`, no blocking I/O, no `synchronized` blocks, no heavy CPU loops.

### Future Chaining
Prefer `Future.compose()`, `.map()`, `.flatMap()`, `.recover()`, `.eventually()` for all async chains. Avoid raw `Promise` when chaining is possible.

```java
// Good — fluent Future chain
orderService.findById(orderId)
  .compose(order -> inventoryService.checkStock(order))
  .compose(stock -> paymentService.charge(stock))
  .onSuccess(result -> ctx.response().setStatusCode(200).end(result.encode()))
  .onFailure(err -> handleError(ctx, err));

// Bad — nested callbacks (callback hell)
orderService.findById(orderId, res -> {
  if (res.succeeded()) {
    inventoryService.checkStock(res.result(), res2 -> { ... });
  }
});
```

### Parallel Execution
Use `Future.all()` (previously `CompositeFuture.all()`) for independent async tasks rather than sequential chaining.

```java
Future.all(userService.getUser(userId), inventoryService.getStock(itemId))
  .onSuccess(cf -> { ... });
```

### Blocking Code
Use `vertx.executeBlocking()` only when unavoidable (e.g., legacy library calls). Always document why it is needed.

```java
vertx.executeBlocking(() -> {
    // Only truly blocking code goes here
    return legacyBlockingCall();
}).onSuccess(result -> { ... });
```

### Virtual Threads (Vert.x 5+)
For new verticles that benefit from a synchronous-looking style, consider `ThreadingModel.VIRTUAL_THREAD`. Do not mix virtual-thread verticles with classic event-loop verticles without care.

```java
DeploymentOptions options = new DeploymentOptions()
    .setThreadingModel(ThreadingModel.VIRTUAL_THREAD);
vertx.deployVerticle(new MyVerticle(), options);
```

### WebClient Rules
- Create `WebClient` once at verticle `start()` and reuse — never instantiate per-request
- Always set **timeout** via typed config (`AppConfig`) — never hardcode a timeout value or omit it entirely:
  ```java
  // Read from typed config at start()
  int timeoutMs = appConfig.getHttpClientTimeoutMs();

  webClient.get(host, path)
      .timeout(timeoutMs)
      .send();
  ```
- When calling any **DHP (Digital Health Platform) service**, always add the `x-efx-component` header set to the current service name:
  ```java
  webClient.post(dhpHost, "/api/v1/some-resource")
      .timeout(timeoutMs)
      .putHeader("x-efx-component", SERVICE_NAME) // constant, e.g. "order-service"
      .sendJsonObject(payload);
  ```
- Set `WebClientOptions.setFollowRedirects(false)` when calling internal services to avoid unexpected redirects

---

## 5. Error Handling

- Always attach `.onFailure()` or `.recover()` at the end of every Future chain — never leave failures unhandled
- Use `router.errorHandler(statusCode, ctx -> ...)` for centralised HTTP error responses
- Map domain errors to correct HTTP status codes; never expose stack traces or internal messages to clients
- Distinguish client errors (4xx) from server errors (5xx) explicitly
- Propagate failures cleanly via `Future.failedFuture(cause)` — do not swallow exceptions
- Register a global `vertx.exceptionHandler()` to catch uncaught event-loop exceptions

```java
// Centralised error handler in router setup
router.errorHandler(500, ctx -> {
    String traceId = ctx.get("traceId");
    log.error("Unhandled error traceId={}", traceId, ctx.failure());
    ctx.response()
        .setStatusCode(500)
        .putHeader("Content-Type", "application/json")
        .end(new JsonObject()
            .put("traceId", traceId)
            .put("code", "INTERNAL_ERROR")
            .put("message", "An unexpected error occurred")
            .encode());
});

// Global uncaught handler
vertx.exceptionHandler(err -> log.error("Uncaught exception on event loop", err));
```

---

## 6. Verticle Lifecycle

- Override `stop()` to release all resources: close DB pools, HTTP clients, timers, and event bus consumers
- Use `DeploymentOptions` to configure threading model, instances, and config — never hardcode
- Deploy child verticles sequentially from a `MainVerticle` using `Future.compose()` for controlled startup order
- Signal startup failure by calling `promise.fail(cause)` in `start(Promise<Void> startPromise)` — this propagates correctly to the deployer
- Set a global `vertx.exceptionHandler()` in `MainVerticle.start()` before deploying anything else

```java
// Sequential deployment with failure propagation
@Override
public void start(Promise<Void> startPromise) {
    Future.succeededFuture()
        .compose(v -> vertx.deployVerticle(new DatabaseVerticle(), dbOptions))
        .compose(v -> vertx.deployVerticle(new HttpVerticle(), httpOptions))
        .onSuccess(v -> startPromise.complete())
        .onFailure(startPromise::fail);
}

// Cleanup in stop()
@Override
public void stop(Promise<Void> stopPromise) {
    pool.close()
        .compose(v -> httpServer.close())
        .onComplete(stopPromise);
}
```

---

## 7. Database (SQLTemplate + JdbcPool)

- Use **`SQLTemplate`** (`io.vertx.ext.sql.SQLTemplate` from `vertx-sql-client-templates`) for all SQL queries — never use raw string-concatenated queries
- All database logic must live inside a **Repository class** (e.g., `OrderRepository`) — never write SQL directly in a Verticle or Service
- Create `JdbcPool` once at `start()` and inject it into repositories — never create a pool per-request
- **Without transaction** — use `jdbcPool.withConnection(conn -> ...)`: borrows a connection, executes, then returns it to the pool automatically
- **With transaction** — use `jdbcPool.withTransaction(conn -> ...)`: auto-commits on success, auto-rolls back on failure, and returns the connection automatically
- Always use named parameters in SQL templates (`:paramName`) — never concatenate user input into SQL strings
- Set `PoolOptions.setMaxSize()` explicitly via typed config — do not rely on defaults in production

```java
// Repository class — all SQL lives here
public class OrderRepository {

    private final JdbcPool jdbcPool;

    public OrderRepository(JdbcPool jdbcPool) {
        this.jdbcPool = jdbcPool;
    }

    // No transaction needed — use withConnection
    public Future<Order> findById(String orderId) {
        return jdbcPool.withConnection(conn ->
            SQLTemplate
                .forQuery(conn, "SELECT * FROM orders WHERE id = #{orderId}")
                .mapTo(Order.class)
                .execute(Map.of("orderId", orderId))
                .map(rows -> rows.iterator().hasNext() ? rows.iterator().next() : null)
        );
    }

    // Multi-step write — use withTransaction
    public Future<Void> createOrder(Order order) {
        return jdbcPool.withTransaction(conn ->
            SQLTemplate
                .forUpdate(conn, "INSERT INTO orders (id, status) VALUES (#{id}, #{status})")
                .execute(Map.of("id", order.getId(), "status", order.getStatus()))
                .compose(v -> SQLTemplate
                    .forUpdate(conn, "INSERT INTO audit_log (order_id, action) VALUES (#{orderId}, #{action})")
                    .execute(Map.of("orderId", order.getId(), "action", "CREATED")))
                .mapEmpty()
        );
    }
}
```

---

## 8. Security

- All SQL queries must use **parameterized queries** — no string concatenation ever
- Enable `CSRFHandler` on all state-changing endpoints (POST, PUT, PATCH, DELETE) for browser-facing APIs
- Set `BodyHandler` with an explicit size limit to prevent DDoS via large payloads:
  `BodyHandler.create().setBodyLimit(10 * 1024 * 1024)`
- Add security response headers globally via a root route handler:
  `Cache-Control`, `X-Content-Type-Options`, `Strict-Transport-Security`, `X-Frame-Options`, `X-XSS-Protection`
- Validate and sanitize **all** user input — use `vertx-web-validation` with `ValidationHandler` and JSON Schema for request bodies and path/query parameters
- `JsonObject.mapTo()` silently ignores unknown fields — always validate input shape explicitly before mapping
- No secrets or credentials in code — use config or env vars

```java
// Input validation with vertx-web-validation
router.post("/api/v1/orders")
    .handler(ValidationHandler.builder(schemaParser)
        .body(Bodies.json(orderSchema))
        .predicate(RequestPredicate.BODY_REQUIRED)
        .build())
    .handler(this::handleCreateOrder);
```

---

## 9. Router & Middleware Setup

- Register routes from **most specific to least specific** — route matching stops at the first match
- Always call `ctx.next()` in middleware handlers that do not end the response, or requests will hang silently
- Use `router.route()` for cross-cutting middleware (logging, auth, tracing) before registering resource routes
- Use sub-routers (`Router.router(vertx)`) to group related routes and keep `start()` clean
- Avoid mounting `BodyHandler` on individual routes — mount it globally early to ensure body parsing

```java
// Good — global middleware first, then sub-routers
router.route().handler(LoggerHandler.create());
router.route().handler(BodyHandler.create().setBodyLimit(10 * MB));
router.route().handler(CSRFHandler.create(vertx, csrfSecret));

Router ordersRouter = Router.router(vertx);
ordersRouter.get("/").handler(this::handleListOrders);
ordersRouter.post("/").handler(this::handleCreateOrder);
router.mountSubRouter("/api/v1/orders", ordersRouter);
```

---

## 10. Testing

- Use `@ExtendWith(VertxExtension.class)` for all Vert.x JUnit 5 tests
- Deploy the Verticle under test in `@BeforeEach` with `vertx.deployVerticle()` and undeploy in `@AfterEach` to prevent state leakage
- Use `VertxTestContext` with `checkpoint()` for all async assertions — never use `Thread.sleep()` to wait
- Mock external dependencies (HTTP, DB) — do not call real services in unit tests
- Test failure paths explicitly alongside the happy path; use `Future.failedFuture()` in mocks to simulate errors
- Set `vertx.exceptionHandler(tc.exceptionHandler())` in test setup to surface uncaught errors to JUnit

```java
@ExtendWith(VertxExtension.class)
class OrderVerticleTest {

    @BeforeEach
    void deploy(Vertx vertx, VertxTestContext tc) {
        vertx.deployVerticle(new OrderVerticle())
             .onComplete(tc.succeedingThenComplete());
    }

    @AfterEach
    void undeploy(Vertx vertx, VertxTestContext tc) {
        vertx.close().onComplete(tc.succeedingThenComplete());
    }

    @Test
    void shouldReturnOrder(Vertx vertx, VertxTestContext tc) {
        WebClient.create(vertx)
            .get(8080, "localhost", "/api/v1/orders/123")
            .send()
            .onSuccess(res -> tc.verify(() -> {
                assertThat(res.statusCode()).isEqualTo(200);
                tc.completeNow();
            }))
            .onFailure(tc::failNow);
    }
}
```

---

## Gotchas

- **Event loop blocking** — `vertx.setTimer()` and `vertx.setPeriodic()` callbacks run on the event loop; never block inside them
- **Double response** — `HttpServerResponse` can only be ended once; guard all error handlers against double-end with `ctx.response().ended()` check
- **Route order** — `router.route()` matches in registration order; more specific routes must be registered before wildcards
- **Silent hanging requests** — forgetting `ctx.next()` in a middleware that doesn't end the response causes the request to hang with no error
- **JsonObject mutability** — `JsonObject` is mutable and not thread-safe; never share instances across verticles without copying (`.copy()`)
- **Future failure swallowing** — composed Future chains swallow intermediate errors if `.onFailure()` is not attached at the end; always terminate chains with an explicit failure handler
- **JsonObject.mapTo() silent drops** — unknown fields are silently ignored; always validate the input shape explicitly before deserialisation
- **WebClient missing timeout** — omitting `.timeout()` on a WebClient request means it can hang indefinitely; always set it from typed config
- **DHP header missing** — forgetting `x-efx-component` on DHP service calls causes requests to be rejected or untraced; make it a mandatory step in any DHP call helper
- **SQLTemplate named param mismatch** — a typo in `#{paramName}` vs the map key fails silently or throws at runtime; keep SQL template keys and map keys in sync and test both
- **SQLTemplate mapTo() silent drops** — `SQLTemplate.forQuery(...).mapTo(MyClass.class)` silently ignores unmatched columns; validate the mapped object shape in tests
- **withTransaction scope** — only operations using the `conn` passed into `withTransaction` are part of the transaction; using the outer `jdbcPool` directly inside the lambda bypasses the transaction
- **Undeploying in tests** — failing to undeploy verticles between tests causes port conflicts and shared state; always undeploy in `@AfterEach`
