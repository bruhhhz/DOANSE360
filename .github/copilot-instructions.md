# AI Coding Agent Instructions for UIT-Go Microservices

## Project Overview
**UIT-Go** is a rideshare platform built as a **microservices architecture** with 4 independent Node.js services, each backed by PostgreSQL databases, coordinated via REST APIs, and instrumented for observability.

## Architecture & Service Boundaries

### Core Services
- **driver-service** (port 8000): Manages driver profiles, status, real-time locations, and geospatial queries
  - DB: PostgreSQL on port 5435
  - Express.js with pg-pool for connection pooling
  - Implements location throttling (rate limits location updates <3s)
  
- **trip-service** (port 3002): Manages booking lifecycle, trip state machine (PENDING→CONFIRMED→COMPLETED)
  - DB: PostgreSQL on port 5433
  - Uses Pino for structured logging + aws-embedded-metrics for SLI emission
  - Handles JSON parse errors with custom middleware
  
- **payment-service** (port 3004): Handles payment estimation and charging
  - DB: PostgreSQL on port 5432
  - Simple stub implementation; extend with provider integration
  
- **user-service** (port 3000): User registration, authentication, session management
  - DB: PostgreSQL on port 5434
  - Uses Sequelize ORM with JWT tokens
  - Observability instrumentation in `src/observability/`

### Supporting Infrastructure
- **Redis** (port 6379): Shared cache for all services
- **Jaeger** (port 16686 UI, 4317/4318 gRPC/HTTP): Distributed tracing (OpenTelemetry)
- **PostgreSQL** (4 instances): One database per service to enforce data isolation

## Critical Developer Workflows

### Local Development
```bash
# Start all services + databases + observability stack
docker compose up --build

# In another terminal, initialize databases
docker compose exec driver-svc npm run db:init

# View Jaeger traces (if instrumentation enabled)
# Open http://localhost:16686
```

### Database Initialization
- Each service has its own `init.sql` or `tripsdb.sql` under `services/{service-name}/`
- Automatically loaded via Docker volume on container startup
- SQL migrations are **not versioned**; if schema changes, manually update `.sql` files and rebuild containers

### Testing Services Locally
Use `.http` test files with REST client:
- `services/driver-service/test.http` — driver CRUD + geospatial queries
- `services/trip-service/test.http` — booking lifecycle
- `scripts/smoke.http` — cross-service smoke tests

Example driver creation:
```bash
curl -X POST http://localhost:8000/v1/drivers \
  -H "Content-Type: application/json" \
  -d '{"user_id":"u9","full_name":"Pham Van C","phone":"0909"}'
```

### Running Scripts
- `scripts/synthetic-payment-test.ps1` — PowerShell script for load testing payments
- `scripts/synthetic-booking-test.ps1` — Booking workflow simulation
- CSV output in `scripts/synthetic-payment-results-*.csv`

## Code Patterns & Conventions

### Environment Variables
All services use `.env` or Docker Compose `environment` block:
- `DB_URL` / `DATABASE_URL` — PostgreSQL connection string (e.g., `postgres://postgres:password@driver-db:5432/driverdb`)
- `PORT` — HTTP server port (default 3000 for services, 8000 for driver-service)
- `REDIS_URL` — Redis connection (e.g., `redis://redis:6379`)
- `OTEL_*` — OpenTelemetry exporter endpoints (Jaeger)

### Request Tracing
**RequestID propagation** is standardized:
- Generate if not present: `x-request-id` or `x_request_id` header → fallback to `randomUUID().slice(0, 8)`
- Log as JSON with `requestId` field
- Forward to downstream services via HTTP headers

Example (driver-service/server.js):
```javascript
app.use((req, res, next) => {
  req.requestId = req.headers['x-request-id'] || randomUUID().slice(0, 8)
  res.on('finish', () => {
    console.info(JSON.stringify({
      msg: 'http_request_complete',
      service: 'driver-service',
      requestId: req.requestId,
      duration: Date.now() - start
    }))
  })
  next()
})
```

### OpenTelemetry Instrumentation (Optional)
Services include optional tracing via `@opentelemetry/sdk-node` + auto-instrumentations:
- Located in `services/{service-name}/src/observability/tracing.js` or `tracing.js`
- Gracefully degrades if OTel packages are missing (logs warning, continues)
- Exports to Jaeger via `OTEL_EXPORTER_OTLP_*` env vars
- **Do not assume OTel is required** — services work without it

### Service-to-Service Communication
- Use `axios` for HTTP calls (see trip-service dependencies)
- Propagate `x-request-id` in headers for request tracing
- Handle retries and timeouts explicitly (no built-in circuit breaker yet)

### Database Patterns
**driver-service & trip-service:** Use `pg` Pool directly
```javascript
import pkg from 'pg'
const { Pool } = pkg
const pool = new Pool({ connectionString: process.env.DB_URL })
```

**user-service:** Uses Sequelize ORM
```javascript
import Sequelize from 'sequelize'
const sequelize = new Sequelize(process.env.DB_URL, { logging: false })
```

Mixed approach is acceptable; choose based on query complexity. Avoid N+1 queries by using connection pooling.

### JSON Error Handling
trip-service demonstrates proper error handling for malformed JSON requests:
```javascript
// Capture raw body for debugging
app.use(express.json({
  verify: (req, res, buf) => req.rawBody = buf.toString()
}))

// Catch SyntaxError on parse failure
app.use((err, req, res, next) => {
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({ error: 'invalid_body' })
  }
  next(err)
})
```

## Observability & SLIs

### SLI Definitions
Each critical flow has defined SLOs (Service Level Objectives) in `docs/observability/SLOs.md`:
- **BookingSuccessRate** (trip-service): ≥99.90% success in ≤30s
- **MatchLatencyP95** (driver-service): p95 < 200ms for `/match-driver` API
- **PaymentSuccessRate** (payment-service): ≥99.95% success
- **LoginSuccessRate** (user-service): ≥99.9% on 7-day window

### Metrics Emission
- Use `aws-embedded-metrics` (AWS CloudWatch EMF format) for structured metrics
- Namespace: `UITGo/SLI`, dimension `Service=<service-name>`
- Example: `services/payment-service/src/observability/metrics.js`
- Warmup metrics on startup to avoid cold-start penalties

### Alerting & Runbooks
- Alert thresholds defined in `infra/observability/main.tf` (Terraform)
- Runbooks for SLO breaches in `runbooks/`:
  - `auth_slo_breach.md`
  - `booking_slo_breach.md`
  - `payment_slo_breach.md`

## File Structure Conventions

```
services/{service-name}/
├── server.js (or src/app.js)         # Main entry point
├── package.json                       # Dependencies + scripts
├── Dockerfile                         # Container image
├── init.sql                           # Database schema
├── db.js (or src/config/db.js)       # Connection pool
├── routes/                            # Express routers
├── src/
│   ├── models/                        # Data models / Sequelize
│   ├── controllers/                   # Request handlers
│   ├── middleware/                    # Custom middleware
│   ├── services/                      # Business logic
│   └── observability/                 # Tracing, metrics, plugins
└── test.http                          # REST client tests
```

## Common Gotchas & Tips

1. **Database Isolation**: Each service has its own DB to prevent tight coupling. Do NOT query another service's database directly—use HTTP APIs instead.

2. **Port Conflicts**: Services use different ports (3000, 3002, 3004, 8000). Update docker-compose.yml if adding new services.

3. **Connection Pooling**: Always reuse connection pools; never create new Pool per query.

4. **Error Logs in JSON**: When adding error handling, use `JSON.stringify({ msg, error, stack })` for consistency with structured logging.

5. **Request ID Propagation**: Always forward `x-request-id` to downstream services; it's the golden thread for debugging distributed issues.

6. **OTel is Optional**: Tracing initialization gracefully handles missing packages. Wrap in try-catch; never assume @opentelemetry/* is available at runtime.

7. **Hot Reload**: trip-service uses nodemon in dev; driver-service does not. Start with `npm run dev` (if available) or `node server.js`.

## References

- **SLO Definitions**: [docs/observability/SLOs.md](../../docs/observability/SLOs.md)
- **Module D (Observability)**: [docs/observability/ModuleD_README.md](../../docs/observability/ModuleD_README.md)
- **Observability Setup**: [infra/observability/README.md](../../infra/observability/README.md)
- **Trade-offs**: [docs/observability/tradeoffs.md](../../docs/observability/tradeoffs.md)
