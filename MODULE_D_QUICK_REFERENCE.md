# Module D - Quick Reference Guide

> Tóm tắt nhanh các khái niệm, quyết định, và hướng dẫn thực tế

---

## 🎯 CÁC KHÁI NIỆM QUAN TRỌNG

### SLI vs SLO vs Error Budget

```
SLI (Service Level Indicator)
├─ Chỉ số đo được (metric)
├─ Ví dụ: PaymentSuccessRate = 99.95%
└─ Dùng để: Đo lường hiệu suất thực tế

SLO (Service Level Objective)
├─ Mục tiêu chất lượng (target)
├─ Ví dụ: PaymentSuccessRate ≥ 99.95%
└─ Dùng để: Định nghĩa "good" vs "bad"

Error Budget
├─ Phần lỗi được phép
├─ Ví dụ: 0.05% = 21.6 phút/tháng
├─ Nếu vượt → vi phạm SLO
└─ Dùng để: Ưu tiên hóa deployments
```

### 3 Pillars of Observability

```
LOGS (Chi tiết)
├─ "Payment process failed due to DB timeout"
├─ Size: 2GB/day (plain text) hay 400MB/day (JSON)
├─ Speed: 5 min to find (grep)
└─ Cost: High

METRICS (Tập hợp)
├─ PaymentSuccessRate = 99.5%
├─ Size: 1MB/day
├─ Speed: Instant (realtime)
└─ Cost: Low ← Dùng cái này!

TRACES (Flow)
├─ Request: Service A → Service B → Service C
├─ Size: 100MB/day
├─ Speed: 1-2 seconds
└─ Cost: Medium (start simple with request ID)
```

---

## 🏗️ ARCHITECTURE DECISIONS

### Services Monitored

| Service | Monitoring | Why |
|---------|-----------|-----|
| PaymentService | ✅ Full | Revenue critical (50%) |
| TripService | ✅ Full | Revenue critical (40%) |
| UserService | ⚠️ Basic | Nice to have (5%) |
| DriverService | ⚠️ Basic | Nice to have (5%) |

### 4 SLIs at a Glance

```
BookingSuccessRate
├─ SLO: ≥ 99.90%
├─ Window: 30 days
├─ Error Budget: 43.2 min/month
└─ Importance: #2 (high)

PaymentSuccessRate
├─ SLO: ≥ 99.95%  ← STRICTEST (WHY? Money!)
├─ Window: 30 days
├─ Error Budget: 21.6 min/month
└─ Importance: #1 (critical)

MatchLatencyP95
├─ SLO: < 200ms
├─ Window: 7 days
├─ Why P95? Because 95% of users should feel responsive
└─ Importance: #3 (medium)

LoginSuccessRate
├─ SLO: ≥ 99.90%
├─ Window: 7 days (shorter than others)
├─ Why shorter? Users can just retry
└─ Importance: #4 (low)
```

---

## 🏪 TECH STACK

```
Structured Logging
├─ Tool: Pino (Node.js logger)
├─ Format: JSON
├─ Cost: Free
└─ Setup: 1 hour per service

Metrics
├─ Tool: CloudWatch EMF (Embedded Metrics Format)
├─ Collection: Automatic from logs
├─ Cost: ~$50/month
└─ Setup: 1 hour

Tracing
├─ Tool: Request ID propagation
├─ Implementation: Add x-request-id header
├─ Cost: Free
└─ Setup: 30 minutes

Dashboard
├─ Tool: CloudWatch Dashboard
├─ Visualization: SLI + error budget + trends
├─ Cost: Free
└─ Setup: 2 hours

Alerting
├─ Tool: CloudWatch Alarms
├─ Notification: SNS → Slack/Email/PagerDuty
├─ Cost: Free (first 10)
└─ Setup: 1 hour

Total Monthly Cost: ~$150
Total Setup Time: 2 weeks
```

---

## 🔔 3-TIER ALERTING STRATEGY

### P1 - CRITICAL (Page immediately)
```
Alert: PaymentSuccessRate < 99.95%
Action: Page SRE on-call
Runbook: payment_slo_breach.md
MTTR Target: < 5 minutes
```

### P2 - HIGH (Email team)
```
Alert: Payment Error Budget < 25%
Action: Send Slack message to team
Runbook: error_budget_low.md
MTTR Target: < 1 hour
```

### P3 - MEDIUM (Create ticket)
```
Alert: MatchLatencyP95 trending up
Action: Create Jira ticket
Runbook: latency_trend.md
MTTR Target: < 1 sprint
```

**Why not more alerts?** 
→ Alert fatigue kills response time. Only alert on what matters!

---

## 🛠️ KEY TRADE-OFFS MADE

### 1. SLO Strictness
```
❌ 99.90% → Too loose (43 min downtime/month allowed)
✅ 99.95% → Chosen (21.6 min downtime/month, balanced)
❌ 99.99% → Too strict (4.3 min, costs 15x more)
```

### 2. Metrics Freshness
```
❌ All real-time → Cost $500/month
✅ Hybrid (real-time + 1min batch) → Cost $150/month
❌ Batch only → Dashboard updates every minute (bad UX)
```

### 3. Log Format
```
❌ Plain text → $200/month storage, 5 min to search
✅ JSON structured → $40/month storage, 5 sec to search
```

### 4. Tracing
```
❌ No tracing → 2 hours to find root cause
✅ Request ID → 30 minutes to find root cause (free!)
❌ X-Ray → 5 minutes but $300/month (overkill now)
```

### 5. Service Coverage
```
❌ All 4 services → 4 weeks setup time
✅ 2/4 services → 2 weeks, covers 90% of revenue
❌ 1/4 services → Misses critical flows
```

---

## 📋 CHECKLIST: WHAT YOU NEED

### For Demonstration
- [ ] Dashboard showing 4 SLIs in realtime
- [ ] Sample logs from PaymentService and TripService
- [ ] Metrics graph (success rate over time)
- [ ] Simulated alert (show what happens when SLO breached)
- [ ] Runbook (show how to handle incident)

### For Documentation
- [ ] REPORT_MODULE_D.md (3-5 pages)
- [ ] SLOs.md (definitions clear)
- [ ] TRADE_OFFS_DETAILED.md (justify all decisions)
- [ ] RUNBOOKS_DETAILED.md (5+ runbooks)
- [ ] MODULE_D_QUESTIONS_AND_ANSWERS.md (15 Q&As)

### For Code
- [ ] PaymentService: Structured logging implemented
- [ ] TripService: Structured logging implemented
- [ ] synthetic test script: 100 requests to verify metrics
- [ ] docker-compose: All services run locally
- [ ] CloudWatch dashboard: Created and populated

---

## 🚀 HOW TO DEMO (5-7 minutes)

### Minute 1-2: Explain SLOs
```
"We defined 4 SLIs:
- PaymentSuccessRate ≥ 99.95% (because money!)
- BookingSuccessRate ≥ 99.90%
- MatchLatencyP95 < 200ms
- LoginSuccessRate ≥ 99.90%

Each has error budget. When we exceed it, we stop deployments."
```

### Minute 2-3: Show Dashboard
```
Open CloudWatch Dashboard
Point to: PaymentSuccessRate = 99.95% ✅
Point to: Error Budget remaining: 16.6/21.6 min
Point to: Active alerts (none right now, good!)
```

### Minute 3-4: Run Synthetic Test
```
Run: ./scripts/synthetic-payment-test.ps1 -Count 50

Show output:
- 50 requests sent
- Success rate: 100%
- p95 latency: 180ms (< 200ms SLO, pass!)
- CSV output with metrics
```

### Minute 4-5: Show Traces
```
Open Jaeger: http://localhost:16686
Click service: payment-service
Show trace: request flow through services
Highlight: Each service took how long
```

### Minute 5-6: Show Runbook
```
"Here's our runbook for when PaymentSuccessRate < SLO:

Step 1: Check current status
Step 2: Identify error pattern
Step 3: Apply fix
Step 4: Monitor recovery
Step 5: Escalate if needed

Each runbook takes < 5 min to execute"
```

### Minute 6-7: Trade-offs & Q&A
```
"We made these trade-off decisions:
- 99.95% SLO (not 99.99%) to balance cost vs reliability
- Structured JSON logs (not plain text) to reduce costs
- Request ID tracing (not X-Ray) for simplicity
- 2/4 services (not all 4) to focus on revenue drivers

Questions?"
```

---

## ⚡ QUICK WINS (High Impact, Low Effort)

### 1. Add Request ID Tracing (30 min)
```javascript
// In every service
app.use((req, res, next) => {
  req.requestId = req.headers['x-request-id'] || generateUUID()
  logger.info({ msg: 'start', requestId: req.requestId })
  next()
})

// Result: Can grep all logs for 1 request across services
```

### 2. Switch to Structured Logs (1 hour)
```javascript
// Instead of
console.log("Payment failed for " + userId)

// Do this
const pino = require('pino')
const logger = pino()
logger.error({ msg: 'payment_failed', user_id: userId })

// Result: 80% cost saving on logs!
```

### 3. Create 1 Alert (30 min)
```
Alert: PaymentSuccessRate < 99.95%
Notification: SNS → Slack
Action: Auto-page on-call engineer

Result: Can respond to outages in 5 min (vs 2 hours)
```

---

## 🎓 FINAL WORDS

> "Observability is not a feature. It's a prerequisite for reliability."

Module D teaches you to:
1. **Define quality** (SLOs/SLIs)
2. **Measure performance** (Logs/Metrics/Traces)
3. **Alert early** (Before customers notice)
4. **Respond fast** (Runbooks, organized alerts)
5. **Learn always** (Post-mortems, trending)

This is the skill that separates startups that scale from those that crash.

Master this → You can handle 1M users.
Ignore this → You'll be debugging at 3 AM for months.

Choose wisely! 🚀

---

**Ready to demo? Go to REPORT_MODULE_D.md for the full story. 📖**
