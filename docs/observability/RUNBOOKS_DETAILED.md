# Module D: Runbooks - Incident Response Guide

> **Mục tiêu:** Hướng dẫn chi tiết từng bước để xử lý các alert và incident

---

## 🔴 RUNBOOK 1: Payment Error Budget Low

### Alert Trigger
- **Alert:** "PaymentService Error Budget < 10%"
- **Severity:** P2 (High)
- **Notification:** Email to team + #incidents Slack channel
- **SLO Affected:** PaymentSuccessRate ≥ 99.95%

### Understanding the Problem

**What is this SLO?**
```
PaymentSuccessRate = (Successful Payments / Total Payments) × 100%
SLO: ≥ 99.95%
Error Budget: 0.05% per month = 21.6 minutes
Current Remaining: < 2.16 minutes (10% of 21.6)
```

**Why did alert trigger?**
```
- Hệ thống đã có ~19 phút downtime/errors trong tháng
- Chỉ còn ~2 phút error budget
- Nếu có thêm lỗi → sẽ vi phạm SLO
- Action: STOP tất cả non-essential deployments
```

### Investigation Steps (Do These First!)

#### **Step 1: Assess Current Situation (2 min)**

```powershell
# Check current success rate
curl http://monitoring.internal/api/metrics/payment-success-rate

# Expected output: 99.93% - 99.96%
# If < 99.95%: Go to Step 2 (Emergency)
# If >= 99.95%: False alarm, continue monitoring
```

#### **Step 2: Analyze Recent Changes (3 min)**

```powershell
# Check if recent deployment caused issues
git log --oneline -5 -- services/payment-service/

# Ask team:
# - Was there a deployment in last 1 hour?
# - Any infrastructure changes?
# - Any third-party service changes?
```

#### **Step 3: Check Service Health (3 min)**

```powershell
# SSH to payment service
ssh ec2-user@payment-prod-1

# Check service running
systemctl status payment-service
# Expected: active (running)

# Check recent errors in logs
tail -200 /var/log/payment-service/app.log | grep ERROR

# Common patterns:
# - "DB connection timeout" → Database issue
# - "Queue full" → Message queue issue
# - "Third-party timeout" → External API issue
```

#### **Step 4: Check Database Performance (3 min)**

```powershell
# SSH to payment DB
ssh ec2-user@payment-db-prod

# Check connection count
psql -c "SELECT count(*) as connections FROM pg_stat_activity;"

# If > 80 connections (of max 100):
# → Database is overwhelmed

# Check slow queries
psql -c "SELECT query, calls, mean_time FROM pg_stat_statements 
WHERE mean_time > 100 ORDER BY mean_time DESC LIMIT 5;"

# If any query > 500ms:
# → That query needs optimization
```

#### **Step 5: Check Third-party Services (2 min)**

```powershell
# If using external payment provider (Stripe, etc):
curl -s https://status.stripe.com/api/v2/status.json | grep status
# Expected: all_systems_operational

# If any service is "degraded" or "down":
# → External provider is the problem
# → Nothing we can do, wait for them to recover
```

### Resolution Actions

#### **If cause is identified: Payment Service**

```powershell
# Restart payment service
sudo systemctl restart payment-service

# Wait 10 seconds for startup
sleep 10

# Check health
curl http://localhost:3004/health
# Expected: 200 OK with {"status":"healthy"}

# Monitor success rate for 5 minutes
watch -n 5 'curl http://monitoring.internal/api/metrics/payment-success-rate'

# If back to >= 99.95%:
# → Go to "Resolution Complete"

# If still < 99.95%:
# → Go to "Escalate"
```

#### **If cause is identified: Database**

```powershell
# Check for connection leak
psql -c "SELECT * FROM pg_stat_activity WHERE state = 'idle in transaction';"

# If > 10 idle transactions:
# Kill them
psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
WHERE state = 'idle in transaction';"

# Wait 30 seconds
sleep 30

# Check connection count again
psql -c "SELECT count(*) FROM pg_stat_activity;"

# If still high:
# Increase max_connections temporarily
# (But this is temp fix, need permanent solution)
```

#### **If cause is identified: Third-party**

```powershell
# Nothing to do on our side
# Alert business: "Payment provider is degraded"
# Send message to #business Slack channel:
# "⚠️ Payment provider XXX is having issues.
#  Impact: Some payments may take longer.
#  ETA: Waiting for provider status update."

# Monitor provider status page
# Check every 5 minutes

# When provider recovers:
# → Success rate should recover automatically
```

### ⚠️ Escalation Path

**If problem NOT resolved after 10 minutes:**

```
1. Page Payment Service Owner (on-call engineer)
   - Command: `pagerduty trigger --service payment-service`
   
2. Alert VP Engineering
   - Message: "Payment service degradation ongoing for >10min"
   
3. Prepare customer communication
   - Draft: "We are investigating payment issues"
   - Review with leadership before sending
   
4. Set up war room
   - Start video call: #war-room Slack channel
   - Gather: DevOps, Backend lead, DBA
```

### ✅ Resolution Complete Checklist

- [ ] Success rate back to >= 99.95%
- [ ] No more errors in logs for 5 minutes
- [ ] All payment requests succeeding
- [ ] Error budget starting to recover
- [ ] No customer complaints in support channel

### 📋 Post-Incident Actions (Within 24 hours)

```
1. Document what happened:
   - What failed?
   - When did it start?
   - How was it detected?
   - What was the fix?
   - How long was it down?
   
2. Root cause analysis:
   - Why did this happen?
   - Was it preventable?
   - What monitoring gap exists?
   
3. Update monitoring:
   - Can we detect this faster next time?
   - Do we need additional metrics?
   
4. Schedule post-mortem:
   - Invite: All on-call responders + team lead
   - Duration: 1 hour
   - Goal: Learn, not blame
```

---

## 🔴 RUNBOOK 2: Payment Success Rate < SLO (99.95%)

### Alert Trigger
- **Alert:** "PaymentSuccessRate < 99.95%"
- **Severity:** P1 (Critical)
- **Notification:** Page SRE on-call immediately
- **SLO Affected:** PaymentSuccessRate ≥ 99.95%

### 🚨 CRITICAL - Page on-call immediately

```powershell
# Notify on-call engineer
pagerduty trigger --service payment-service --urgency high

# Also notify in Slack
@on-call Payment SRE: Payment success rate below SLO! 
Dashboard: http://monitoring.internal/dashboard/payment
```

### Immediate Investigation (< 5 minutes)

#### **Step 1: Get Metrics (1 min)**

```powershell
# Check current status
curl http://monitoring.internal/api/metrics/payment-detailed

# Expected output:
# {
#   "success_rate": 99.20%,
#   "total_requests": 10000,
#   "failed_requests": 80,
#   "avg_latency": 250ms,
#   "p95_latency": 350ms
# }
```

#### **Step 2: Identify Failure Pattern (2 min)**

```powershell
# Check logs for errors
docker logs -f payment-service | grep ERROR

# Common error patterns:
tail -50 /var/log/payment-service/app.log | grep -i "failed"

# Group by error type:
# ERROR: "DB connection refused" → 45 errors
# ERROR: "Queue timeout" → 25 errors
# ERROR: "Validation failed" → 10 errors

# This tells you root cause!
```

#### **Step 3: Quick Fix Based on Error Type (2 min)**

**If "DB connection refused":**
```powershell
# DB is down, restart it
sudo systemctl restart payment-db

# Wait for startup (30-60 seconds)
sleep 30

# Check connectivity
psql -c "SELECT 1" 
# Should return: 1
```

**If "Queue timeout":**
```powershell
# Check message queue status
aws sqs get-queue-attributes --queue-url payment-queue

# If queue has 10000+ messages:
# → Purge old messages
aws sqs purge-queue --queue-url payment-queue
```

**If "Validation failed":**
```powershell
# Check what validation is failing
tail -100 /var/log/payment-service/app.log | grep -A2 "Validation failed"

# Read the actual error message
# If it's data validation, manually fix bad data in DB
```

### Real-time Monitoring (While Investigating)

```powershell
# Open monitoring dashboard (keep open)
open http://monitoring.internal/dashboard/payment

# Watch these metrics:
# - Success rate: should trend back up after fix
# - Latency: should remain stable
# - Error count: should go to 0

# If not improving after 5 minutes:
# → Escalate to Incident Commander
```

### Escalation (If Not Resolved in 5 min)

```
IMMEDIATE:
1. Declare P1 Incident
2. Page all on-call: SRE + Backend Lead + DBA
3. Start incident bridge: Zoom call
4. Update status page

COMMUNICATION:
5. Send customer alert: "We are investigating"
6. Notify: CEO, CFO, COO (revenue down)

INVESTIGATION:
7. Full system diagnostics
8. Check all 4 services dependencies
9. Consider: rollback last deployment?
```

### ✅ Resolution Verification

```powershell
# Wait until success rate >= 99.95% for 5 consecutive minutes
watch -n 30 'curl http://monitoring.internal/api/metrics/payment-success-rate'

# Then verify:
# 1. No error logs in last 10 minutes
# 2. All instances healthy
# 3. Database responding normally
# 4. Queue empty
# 5. Downstream services happy (no 500 errors to them)

# Get all-clear before closing incident
```

---

## 🟠 RUNBOOK 3: Booking Success Rate < SLO (99.90%)

### Alert Trigger
- **Alert:** "BookingSuccessRate < 99.90%"
- **Severity:** P1 (Critical)
- **Notification:** Page SRE on-call

### Quick Diagnosis

```powershell
# Check all steps in booking flow
# 1. POST /trips
curl -X POST http://trip-service:3002/trips -d '{...}'

# 2. Call DriverService
curl http://driver-service:8000/drivers/search?lat=...

# 3. Return response
# Check which step is failing

# Usually:
# If step 1 fails → TripService issue
# If step 2 fails → DriverService issue
# If step 3 fails → Network/integration issue
```

### Fix

```powershell
# Based on failing step:
sudo systemctl restart trip-service  # if step 1 failing
sudo systemctl restart driver-service  # if step 2 failing

# Monitor for recovery
watch -n 10 'curl http://monitoring.internal/api/metrics/booking-success-rate'
```

---

## 🟡 RUNBOOK 4: MatchLatencyP95 > 200ms

### Alert Trigger
- **Alert:** "MatchLatencyP95 > 200ms"
- **Severity:** P2 (Medium)
- **Notification:** Email to team

### Investigation

```powershell
# Check latency breakdown by component
curl http://monitoring.internal/api/metrics/match-latency-breakdown

# Expected output (should add up to < 200ms):
# {
#   "redis_geosearch": 10ms,     # OK
#   "db_query": 80ms,            # OK (but slow)
#   "driver_validation": 50ms,   # OK
#   "serialization": 20ms        # OK
# }

# If redis_geosearch > 50ms:
# → Redis is slow, check connection pool
# → Might need to increase cache

# If db_query > 100ms:
# → Database query is slow
# → Check if index is missing
# → OR too many drivers in DB
```

### Quick Fix

```powershell
# Option 1: Clear cache and rebuild
redis-cli FLUSHDB
# Then reindex drivers

# Option 2: Optimize query
# Add index on latitude/longitude
psql -c "CREATE INDEX idx_driver_location ON drivers(latitude, longitude);"

# Option 3: Increase caching TTL
# Changes in driver-service config
```

---

## 🟡 RUNBOOK 5: Error Rate Trending Up (Preventive Alert)

### Alert Trigger
- **Alert:** "Error rate increasing trend (p-value < 0.05)"
- **Severity:** P3 (Medium)
- **Notification:** Ticket in project backlog

### Investigation

```powershell
# This is trend detection, not immediate crisis
# Just trend warning

# Check error rate history (last 7 days)
curl http://monitoring.internal/api/metrics/error-rate-history?days=7

# If trending up, ask:
# 1. Was there a deployment 12-24 hours ago?
# 2. Have data volumes increased?
# 3. Any external changes (OS patch, etc)?

# If you find cause:
# → Schedule fix in next sprint
# → No immediate action needed (it's trending, not broken yet)
```

---

## 📋 Runbook Format for New Incidents

**Template to create new runbooks:**

```markdown
# RUNBOOK: [Alert Name]

## Alert Details
- Alert: [exact alert name]
- Severity: [P1/P2/P3]
- Notification: [who gets alerted]
- SLO: [which SLO is affected]

## Quick Diagnosis (2-5 min)
[Step by step to figure out what's wrong]

## Common Causes & Fixes
[List each cause with corresponding fix]

## Monitoring During Fix
[What to watch while fixing]

## Escalation Path
[When and who to page if not fixed in X minutes]

## Verification
[How to verify fix worked]

## Post-Incident
[What to do after incident is resolved]
```

---

## 🔄 Runbook Version Control

All runbooks are stored in version control:
```
runbooks/
├── payment_slo_breach.md
├── booking_slo_breach.md
├── match_latency_slo_breach.md
├── auth_slo_breach.md
└── generic_error_budget_low.md
```

**Update runbooks when:**
- Incident response took too long → update runbook
- Root cause different than expected → update assumptions
- New failure mode discovered → add to "Common Causes"

**Review runbooks every quarter:**
- Are they still accurate?
- Did we discover new failure modes?
- Can we automate any steps?

---

**All runbooks ready for incidents! 🚀**
