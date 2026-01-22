curl -X POST http://localhost:3004/payments `
  -H "Content-Type: application/json" `
  -d '{"amount": 100, "trip_id": "trip123", "user_id": "user1"}'# ✅ Module D Observability — Test Checklist

**Ngày test:** [Nhập ngày]  
**Người test:** [Nhập tên]  
**Kết quả:** [ ] PASS  [ ] FAIL

---

## TEST 1: SLO/SLI Definitions ✓

**Mục tiêu:** Xác nhận SLO/SLI được define đúng cho 4 flows

**Steps:**
- [ ] Mở `docs/observability/SLOs.md`
- [ ] Kiểm tra Booking SLI: BookingSuccessRate ≥ 99.90%, window 30d
- [ ] Kiểm tra Payment SLI: PaymentSuccessRate ≥ 99.95%, window 30d
- [ ] Kiểm tra Auth SLI: LoginSuccessRate ≥ 99.9%, window 7d
- [ ] Kiểm tra Match SLI: MatchLatencyMs p95 < 200ms, window 7d

**Kết quả:**
```
Booking: [ ] OK / [ ] FAIL - Ghi chú:
Payment: [ ] OK / [ ] FAIL - Ghi chú:
Auth:    [ ] OK / [ ] FAIL - Ghi chú:
Match:   [ ] OK / [ ] FAIL - Ghi chú:
```

---

## TEST 2: Payment Service Instrumentation (Local)

**Mục tiêu:** Xác nhận payment-service emit metrics & logs đúng

**Steps:**
```powershell
cd services\payment-service
npm install
node src/index.js  # Mở terminal 1
```

**Từ terminal 2, gọi payment endpoint:**
```powershell
curl -X POST http://localhost:3004/payments `
  -H "Content-Type: application/json" `
  -d '{
    "amount": 100,
    "trip_id": "trip123",
    "user_id": "user1",
    "payment_method": "card"
  }'
```

**Kiểm tra (Terminal 1 logs):**
- [ ] Có JSON logs xuất hiện
- [ ] Log có chứa `"msg":"start_createPayment"`
- [ ] Log có chứa `"msg":"after_recordPaymentAttempt"`
- [ ] Log có chứa `"msg":"after_processPayment"`
- [ ] Response status: [ ] 200 / [ ] 400 / [ ] 500

**Kết quả:** [ ] PASS / [ ] FAIL

---

## TEST 3: Trip Service Instrumentation (Local)

**Mục tiêu:** Xác nhận trip-service emit booking metrics

**Steps:**
```powershell
# Terminal 1
cd services\trip-service
npm install
npm start  # hoặc node src/app.js
```

**Từ terminal 2, gọi booking endpoint:**
```powershell
curl -X POST http://localhost:3002/trips `
  -H "Content-Type: application/json" `
  -d '{
    "user_id": "user1",
    "pickup_location": "10.7769,106.6669",
    "dropoff_location": "10.8000,106.7000"
  }'
```

**Kiểm tra (Terminal 1 logs):**
- [ ] Có JSON logs xuất hiện
- [ ] Log có chứa `"msg":"start_createTrip"` hoặc `"msg":"start_booking"`
- [ ] Log có chứa metrics về trip state (PENDING, CONFIRMED, COMPLETED)

**Kết quả:** [ ] PASS / [ ] FAIL

---

## TEST 4: Synthetic Payment Test (Metrics Collection)

**Mục tiêu:** Chạy 50+ payment requests và thu thập SLI metrics

**Steps:**
```powershell
# Đảm bảo payment-service chạy ở port 3004

cd scripts
.\synthetic-payment-test.ps1 -Count 50 -IntervalSeconds 0.1
```

**Kiểm tra Output:**
- [ ] Có file `synthetic-payment-results-*.csv` được tạo
- [ ] CSV có columns: timestamp, status_code, duration_ms, success
- [ ] CSV có ít nhất 50 rows (50 requests)
- [ ] Summary hiển thị:
  - [ ] `Success Rate` (e.g., 95%, 99%, 100%)
  - [ ] `P50 Duration` (ms)
  - [ ] `P95 Duration` (ms)
  - [ ] `Avg Duration` (ms)

**Expected SLI Values:**
- Success Rate: >= 99%
- P95 Duration: < 1000ms (local)

**Ghi chú:**
```
Success Rate: ____%
P95 Duration: ____ms
Avg Duration: ____ms
```

**Kết quả:** [ ] PASS / [ ] FAIL

---

## TEST 5: Synthetic Booking Test (Metrics Collection)

**Mục tiêu:** Chạy 50+ booking requests và thu thập SLI metrics

**Steps:**
```powershell
# Đảm bảo trip-service chạy ở port 3002

cd scripts
.\synthetic-booking-test.ps1 -Count 50 -IntervalSeconds 0.1
```

**Kiểm tra Output:**
- [ ] Có file `synthetic-booking-results-*.csv` được tạo
- [ ] CSV có columns: timestamp, status_code, duration_ms, success
- [ ] Summary hiển thị success_rate, p50, p95, avg_duration_ms

**Expected SLI Values:**
- Success Rate: >= 99%
- P95 Duration: < 1000ms (local)

**Ghi chú:**
```
Success Rate: ____%
P95 Duration: ____ms
Avg Duration: ____ms
```

**Kết quả:** [ ] PASS / [ ] FAIL

---

## TEST 6: Terraform Infrastructure Validation

**Mục tiêu:** Xác nhận Terraform files syntax & logic đúng

**Steps:**
```powershell
cd infra\observability
terraform init
terraform plan  # (KHÔNG apply, chỉ xem plan)
```

**Kiểm tra file `main.tf`:**
- [ ] Có CloudWatch Log Group `/uitgo/payment-service`
- [ ] Có CloudWatch Log Group `/uitgo/trip-service`
- [ ] Có CloudWatch Log Group `/uitgo/user-service`
- [ ] Có CloudWatch Dashboard `UITGo-SLO-Dashboard`
- [ ] Dashboard có Payment Success Rate widget
- [ ] Dashboard có Match p95 Latency widget
- [ ] Có SNS topic `uitgo-alerts`
- [ ] Có IAM policy `xray-put-trace-segments`
- [ ] Có CloudWatch Alarm cho Payment SLO breach
- [ ] Có CloudWatch Alarm cho Match SLO breach

**Terraform Plan Output:**
- [ ] No errors
- [ ] Shows resources to be created (CloudWatch, SNS, IAM)
- [ ] No deprecation warnings

**Kết quả:** [ ] PASS / [ ] FAIL / [ ] SKIP (nếu không có AWS credentials)

---

## TEST 7: Runbooks Review

**Mục tiêu:** Xác nhận runbooks có content hợp lệ

**Steps:**
- [ ] Mở `runbooks/payment_slo_breach.md`
- [ ] Đọc từ đầu đến cuối

**Kiểm tra content:**
- [ ] Có mục "Symptoms"
- [ ] Có mục "Quick Checks"
- [ ] Có mục "Likely Causes"
- [ ] Có mục "Mitigations"
- [ ] Có mục "Escalation"
- [ ] Runbook có thể execute được

**Kết quả:** [ ] PASS / [ ] FAIL

---

## TEST 8: Trade-offs Analysis

**Mục tiêu:** Xác nhận trade-offs document giải thích lựa chọn design

**Steps:**
- [ ] Mở `docs/observability/tradeoffs.md`
- [ ] Đọc analysis

**Kiểm tra:**
- [ ] Giải thích tại sao chọn EMF (aws-embedded-metrics)
- [ ] Giải thích tại sao chọn OpenTelemetry vs khác
- [ ] Có pros/cons so sánh
- [ ] Có recommendation

**Kết quả:** [ ] PASS / [ ] FAIL

---

## 📊 SUMMARY

| Test | Status | Notes |
|------|--------|-------|
| TEST 1: SLO/SLI Definitions | [ ] | |
| TEST 2: Payment Instrumentation | [ ] | |
| TEST 3: Trip Instrumentation | [ ] | |
| TEST 4: Synthetic Payment Test | [ ] | |
| TEST 5: Synthetic Booking Test | [ ] | |
| TEST 6: Terraform Validation | [ ] | |
| TEST 7: Runbooks Review | [ ] | |
| TEST 8: Trade-offs Analysis | [ ] | |

**Overall Result:** [ ] ALL PASS ✅ / [ ] SOME FAIL ⚠️

---

## 📝 Ghi chú thêm

```
Các vấn đề gặp phải:


Các cải tiến cần làm:


```

---

**Ngày hoàn thành:** __________  
**Ký tên:** __________
