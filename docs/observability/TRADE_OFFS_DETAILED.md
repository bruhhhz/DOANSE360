# Module D: Trade-offs Analysis - Observability Design Decisions

> **Mục tiêu:** Phân tích chi tiết các đánh đổi (trade-offs) khi thiết kế Observability cho UIT-Go

---

## 📊 Trade-off #1: SLO Strictness vs Implementation Cost

### Vấn đề
Chọn SLO cho PaymentSuccessRate:
- **A) 99.90%** → Error Budget: 43.2 phút/tháng (dễ achieve)
- **B) 99.95%** → Error Budget: 21.6 phút/tháng (trung bình)
- **C) 99.99%** → Error Budget: 4.3 phút/tháng (rất khó)

### Análise Trade-offs

| Aspect | 99.90% | 99.95% | 99.99% |
|--------|--------|---------|---------|
| **Implementation Cost** | $100/mo | $300/mo | $5000/mo |
| **Developer Effort** | 1 week | 3 weeks | 3 months |
| **Downtime Allowed/month** | 43.2 min | 21.6 min | 4.3 min |
| **Feasibility** | Easy | Medium | Extreme |
| **Customer Impact** | Moderate | Low | Very Low |

### ✅ Quyết định cho UIT-Go: **99.95%**

**Lý do:**
- **Chi phí:** $300/month là xứng đáng cho payment service
- **Customer impact:** Đủ để tạo tín cậy (1.5% cao hơn legal requirement)
- **Feasibility:** Achievable trong 3 tuần với team nhỏ
- **Business value:** ROI tốt (không over-engineer)

**Alternative consideration:**
- Nếu để 99.90%: Rủi ro mất khách hàng do downtime thường xuyên
- Nếu để 99.99%: Cost tăng 15x, nhưng benefit chỉ 0.04% improvement

---

## 📊 Trade-off #2: Real-time Metrics vs Data Storage & Cost

### Vấn đề
Cần track PaymentSuccessRate. Có 2 cách:

**Option A: Real-time Emission (Every request)**
```
- Mỗi request → emit metric ngay
- Data: 1000 req/s → 86.4M metrics/day
- Storage: ~500 MB/day
- Latency: <100ms (realtime)
- Cost: $500/month
```

**Option B: Batch Aggregation (Every 1 minute)**
```
- Mỗi phút → tính toán tổng + emit 1 metric
- Data: 1440 metrics/day (1000x less!)
- Storage: ~1 MB/day
- Latency: 60 seconds (delayed)
- Cost: $50/month
```

### Análise Trade-offs

| Aspect | Real-time | Batch (1min) |
|--------|-----------|--------------|
| **Data Volume** | 86.4M/day | 1,440/day |
| **Storage Cost** | $500/mo | $50/mo |
| **Query Latency** | <100ms | 60-120s |
| **Alert Speed** | Instant | 1-2 min delay |
| **Dashboard Experience** | Smooth (updates every sec) | Chunky (every min) |
| **Troubleshooting Speed** | Very fast (fine granularity) | Slow (coarse granularity) |

### ✅ Quyết định cho UIT-Go: **Real-time + 1-min Aggregation (Hybrid)**

**Lý do:**
- Real-time for dashboard (smooth UX for team)
- But aggregate every 1 minute for long-term storage
- Cost: ~$150/month (balanced)
- Latency: 10 seconds average (acceptable)

**Implementation:**
```javascript
// Emit every request (for real-time dashboard)
logger.info({
  msg: 'payment_success',
  duration_ms: 150,
  // CloudWatch will show realtime
})

// Every 1 minute, emit aggregated metric
setInterval(() => {
  const successRate = calculateSuccessRate(last60seconds)
  emitMetric('PaymentSuccessRate', successRate)
}, 60000)
```

---

## 📊 Trade-off #3: Structured Logs vs Log Volume & Cost

### Vấn đề
Plain text logs vs Structured (JSON) logs

**Option A: Plain Text Logs**
```
[2026-01-22 10:00:00] Processing payment request from user u_123
[2026-01-22 10:00:01] Validation passed for payment p_456
[2026-01-22 10:00:02] DB connection error: timeout
[2026-01-22 10:00:03] Retry attempt 1
...

Size: ~2KB per payment
1000 req/s = 2GB logs/day
```

**Option B: Structured JSON Logs**
```json
{
  "timestamp": "2026-01-22T10:00:00Z",
  "level": "info",
  "msg": "start_createPayment",
  "user_id": "u_123",
  "payment_id": "p_456"
}

Size: ~400B per payment (5x smaller!)
1000 req/s = 400MB logs/day
```

### Análise Trade-offs

| Aspect | Plain Text | Structured JSON |
|--------|-----------|-----------------|
| **Log Size** | 2GB/day | 400MB/day |
| **Storage Cost** | $200/mo | $40/mo |
| **Search Speed** | Slow (grep, regex) | Fast (field filter) |
| **Parse Success Rate** | ~80% (errors in text) | 100% (valid JSON) |
| **Aggregation** | Manual scripting | CloudWatch query |
| **Developer Time** | Long debugging hours | Fast automated analysis |

### ✅ Quyết định cho UIT-Go: **Structured JSON Logs**

**Lý do:**
- **Cost saving:** 80% less storage ($160/month save)
- **Search speed:** 100x faster (2 sec vs 2 min)
- **Automation:** Can create metrics automatically (EMF)
- **Quality:** 100% parse success vs 80% for plain text

**Implementation:**
```javascript
// Use Pino logger (structured logging)
const logger = pino()

logger.info({
  msg: 'payment_created',
  payment_id: 'p_456',
  user_id: 'u_123',
  amount: 100,
  duration_ms: 150
})
// Output: {"level":30,"time":1234567890,"msg":"payment_created",...}
```

---

## 📊 Trade-off #4: Distributed Tracing vs Infrastructure Complexity

### Vấn đề
需要trace request qua 4 services: TripService → DriverService → UserService → AuthService

**Option A: No Tracing**
```
❌ When error occurs:
- Check TripService logs (might see nothing)
- Check DriverService logs (might see nothing)
- Check UserService logs (might see nothing)
- Check AuthService logs (❌ probably slow here!)
- Manual correlation needed
- Time to root cause: 2 hours!
```

**Option B: Basic Tracing (Pass request ID)**
```
✓ Add x-request-id header
✓ Log request ID in each service
✓ Can grep all logs for 1 request
✓ Time to root cause: 30 minutes

But still manual correlation needed
```

**Option C: Full Distributed Tracing (X-Ray)**
```
✓ Automatic span creation
✓ Visual timeline
✓ Service latency breakdown
✓ Error attribution
✓ Time to root cause: 5 minutes!

Cost: $300/month
Complexity: Medium
```

### Análise Trade-offs

| Aspect | No Tracing | Request ID | X-Ray |
|--------|-----------|-----------|-------|
| **Setup Time** | 0 | 2 hours | 1 day |
| **Cost** | $0 | $0 | $300/mo |
| **MTTR** | 2 hours | 30 min | 5 min |
| **Infrastructure Complexity** | Low | Low | High |
| **Developer Experience** | Bad | OK | Excellent |

### ✅ Quyết định cho UIT-Go: **Basic Tracing (Request ID) + Optional X-Ray**

**Lý do:**
- Request ID tracing is free and gives 80% value
- Can add X-Ray later when need more sophistication
- Start simple, optimize when business justifies cost

**Implementation:**
```javascript
// Add to all services
app.use((req, res, next) => {
  req.requestId = req.headers['x-request-id'] || generateUUID()
  
  // Log with requestId
  logger.info({
    msg: 'payment_start',
    requestId: req.requestId,
    payment_id: 'p_456'
  })
  
  // Forward to downstream services
  res.locals.requestId = req.requestId
  next()
})

// When calling other services
axios.get('/driver/match', {
  headers: {
    'x-request-id': requestId
  }
})
```

---

## 📊 Trade-off #5: Alert Sensitivity vs Alert Fatigue

### Vấn đề
How strict should alerts be?

**Option A: Very Strict Alerts**
```
- Alert when success rate < 99.99% (vs SLO 99.95%)
- Alert when latency p95 > 150ms (vs SLO 200ms)
- Alert when error rate > 1%
- Alert when CPU > 50%

Result: 50+ alerts/day
Ops team: Ignore all (alert fatigue)
Critical alert when it comes: NO ONE NOTICES! ❌
```

**Option B: Loose Alerts**
```
- Alert only when SLO actually breached
- Only critical path failures
- 5-10 alerts/month

Result: Every alert is real issue
Ops team: Pay attention to all ✅
Critical alert: Everyone jumps on it! ✅
```

**Option C: Intelligent Alerts (Hybrid)**
```
- Tier 1 (P1): SLO breach → page on-call immediately
- Tier 2 (P2): Error budget low (< 10%) → email team
- Tier 3 (P3): Trend alerts (latency increasing) → log ticket

Result: Graduated response based on severity
```

### Análise Trade-offs

| Aspect | Strict | Loose | Intelligent |
|--------|--------|--------|------------|
| **Alerts/month** | 1000+ | 5-10 | 50-100 |
| **P1 Alerts** | 50+ | 5-10 | 5-10 |
| **Alert Fatigue** | Extreme | None | Minimal |
| **MTTR for real issues** | Slow (noise ignored) | Fast | Very Fast |
| **False Alarm Rate** | 95% | 0% | 5% |

### ✅ Quyết định cho UIT-Go: **Intelligent (3-tier Alerting)**

**Lý do:**
- Prevents alert fatigue (kills reliability culture)
- Every P1 alert is real + actionable
- Ops team can respond effectively

**Alert Tiers:**
```
P1 (Critical):
- PaymentSuccessRate < 99.95% ← Page immediately
- All Payment instances down ← Page immediately
- Error budget < 5 min ← Page

P2 (High):
- Error budget < 25% ← Email team
- BookingSuccessRate < 99.90% ← Email team

P3 (Medium):
- MatchLatencyP95 trending up ← Ticket
- LoginSuccessRate trending down ← Ticket
```

---

## 📊 Trade-off #6: Observability Coverage vs Setup Time

### Vấn đề
Implement observability for how many services?

**Option A: Full Coverage (4/4 services)**
```
- UserService: SLI + alerts + dashboard
- TripService: SLI + alerts + dashboard
- DriverService: SLI + alerts + dashboard
- PaymentService: SLI + alerts + dashboard

Time: 4 weeks
Cost: $300/month
Coverage: 100%
```

**Option B: Critical Only (2/4 services)**
```
- PaymentService: Full observability
- TripService: Full observability
- Other services: Basic logging only

Time: 2 weeks
Cost: $150/month
Coverage: 80% (covers 80% of revenue)
```

**Option C: Minimal (1/4 services)**
```
- PaymentService: Full observability
- Other services: Basic logging

Time: 1 week
Cost: $100/month
Coverage: 50% (critical service only)
```

### Análise Trade-offs

| Aspect | Full (4/4) | Critical (2/4) | Minimal (1/4) |
|--------|-----------|----------------|--------------|
| **Setup Time** | 4 weeks | 2 weeks | 1 week |
| **Cost** | $300/mo | $150/mo | $100/mo |
| **SLI Coverage** | 100% | 80% | 50% |
| **Blind Spots** | None | Minor services | Non-payment |
| **MTTR** | 5-10 min | 10-20 min | 30+ min |

### ✅ Quyết định cho UIT-Go: **Critical Only (2/4)**

**Lý do:**
- **Business priority:** Payment + Booking = 90% of revenue
- **Time constraint:** 2 weeks is feasible for course project
- **Scalability:** Can expand coverage incrementally
- **ROI:** Best bang for buck

**Phase 1 (Done):** PaymentService + TripService
**Phase 2 (Future):** Add UserService + DriverService

---

## 📊 Trade-off #7: Custom Metrics vs Off-the-shelf Monitoring Tools

### Vấn đề
Build custom metrics or use managed service?

**Option A: Custom Implementation**
```
- Write code to emit metrics to CloudWatch
- Write code to create dashboard
- Write code to setup alarms
- Write code to manage runbooks

Cost: $50/month (CloudWatch only)
Time: 3 weeks (lots of custom code)
Flexibility: Very high
Maintenance: High (own all code)
```

**Option B: Managed Service (Datadog)**
```
- Datadog agent auto-collects everything
- Pre-built dashboards
- Auto-generated alerts
- Built-in runbooks

Cost: $500/month
Time: 2 days (setup only)
Flexibility: Medium (UI-based)
Maintenance: Low (Datadog maintains)
```

**Option C: Hybrid (CloudWatch + Simple Custom)**
```
- Use CloudWatch for metrics
- Use Pino for structured logs
- Simple custom dashboard
- Runbooks in markdown

Cost: $150/month
Time: 2 weeks
Flexibility: High
Maintenance: Medium (mostly config, not code)
```

### Análise Trade-offs

| Aspect | Custom | Datadog | Hybrid |
|--------|--------|---------|--------|
| **Cost** | $50/mo | $500/mo | $150/mo |
| **Setup Time** | 3 weeks | 2 days | 2 weeks |
| **Flexibility** | Very high | Medium | High |
| **Learning Curve** | Steep | Gentle | Medium |
| **Maintenance** | High | Low | Medium |
| **Scalability** | Good | Excellent | Good |

### ✅ Quyết định cho UIT-Go: **Hybrid (CloudWatch + Custom)**

**Lý do:**
- **Cost:** 70% cheaper than Datadog
- **Learning:** More valuable for students (understand full stack)
- **Scalability:** Good enough for startup
- **Flexibility:** Can customize for specific needs

**Implementation:**
- AWS CloudWatch (free tier includes 1000 metrics)
- Pino for structured logging
- Custom dashboard using CloudWatch API
- Markdown runbooks

---

## 📋 Trade-offs Summary Table

| Trade-off | Option A | Option B | ✅ Choice | Reason |
|-----------|----------|----------|----------|--------|
| SLO Strictness | 99.90% | 99.99% | **99.95%** | Best balance |
| Metrics Freshness | Real-time | Batch (1min) | **Hybrid** | Cost + UX |
| Log Format | Plain text | JSON | **JSON** | 80% cost save |
| Tracing | No traces | X-Ray | **Request ID** | Good enough |
| Alert Sensitivity | Strict | Loose | **3-tier** | No fatigue |
| SLI Coverage | All 4 services | 2 critical | **2 critical** | ROI best |
| Tools | Custom | Datadog | **Hybrid** | Affordable |

---

## 🎯 Final Architecture Decision

**UIT-Go Observability Stack (Chosen):**

```
Services Monitored:
├─ PaymentService (full SLI + alerts + dashboard)
├─ TripService (full SLI + alerts + dashboard)
├─ UserService (basic logging only)
└─ DriverService (basic logging only)

Metrics:
├─ PaymentSuccessRate (99.95% SLO)
├─ BookingSuccessRate (99.90% SLO)
├─ MatchLatencyP95 (<200ms SLO)
└─ LoginSuccessRate (99.90% SLO)

Technology Stack:
├─ Logs: Pino (structured JSON)
├─ Metrics: CloudWatch + EMF
├─ Tracing: Request ID propagation
├─ Dashboard: CloudWatch Dashboard
├─ Alerts: CloudWatch Alarms (3-tier)
└─ Runbooks: Markdown in /runbooks

Cost: ~$150/month
Setup Time: 2 weeks
Coverage: 80% of revenue paths
MTTR: 10-20 minutes average
```

---

## 🔄 Future Evolution (When Scaling)

**If UIT-Go becomes real startup:**

- Add Phase 2: Full coverage (4/4 services)
- Add Phase 3: Distributed tracing (X-Ray)
- Add Phase 4: Intelligent alerts (ML-based)
- Add Phase 5: Multi-region observability

Each phase triggered by specific business metrics:
- Phase 2: When revenue > $50K/month
- Phase 3: When services > 5 (complex flows)
- Phase 4: When P1 incidents > 5/month
- Phase 5: When users in multiple regions

---

**All trade-offs documented and justified! Ready to present to instructors. 🚀**
