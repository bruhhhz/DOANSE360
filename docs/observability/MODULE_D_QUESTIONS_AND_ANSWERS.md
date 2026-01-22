# Module D: 15 Câu Hỏi & Vấn Đề Lõi - Observability

> **Mục tiêu:** Tài liệu này giải thích 15 câu hỏi quan trọng về Module D (Observability) cho UIT-Go, giúp hiểu sâu các khái niệm và trade-offs.

---

## 📚 PHẦN 1: ĐỊNH NGHĨA SLOs/SLIs (5 Câu Hỏi)

### ❓ Câu Hỏi 1: "Tại sao phải định nghĩa SLO/SLI? Sao không chỉ theo dõi tất cả mọi thứ?"

#### **🔴 Vấn đề thực tế:**

Hình tưởng: Bạn chạy UIT-Go với 1000 requests/giây.
- UserService có 100 error/giây
- PaymentService có 2 error/giây  
- DriverService có 150 error/giây
- Trip Service có 5 error/giây

❓ **Cái nào quan trọng hơn?**
❓ **Khi nào nên cảnh báo?**
❓ **Khi nào nên bỏ qua?**

#### **✅ Giải thích:**

**SLO/SLI là "công cụ ưu tiên hóa":**

| Kỹ thuật | Ý nghĩa | Ứng dụng |
|---------|---------|---------|
| **SLI (Service Level Indicator)** | Chỉ số đo được | `PaymentSuccessRate = (Successful / Total) × 100%` |
| **SLO (Service Level Objective)** | Mục tiêu chất lượng | `PaymentSuccessRate ≥ 99.95%` |
| **Error Budget** | Phần lỗi được phép | `0.05% = 21.6 phút lỗi/tháng` |

**Trong ví dụ trên:**

```
UserService errors (100/s):
- SLO: ≥ 99% → Error Budget = 1% = 14.4 giờ/tháng
- Hiện tại vi phạm SLO → 🔴 CRITICAL

PaymentService errors (2/s):
- SLO: ≥ 99.95% → Error Budget = 0.05% = 21.6 phút/tháng  
- Hiện tại vi phạm SLO → 🔴 CRITICAL (nguy hiểm hơn!)

DriverService errors (150/s):
- SLO: không định nghĩa → ❓ Không biết có vấn đề không
- Kỹ sư sẽ bỏ qua → ⚠️ Nhưng nếu ảnh hưởng tìm xe, sẽ fail!
```

**🎯 Kết luận:**
- **Không có SLO** = không biết ưu tiên hóa
- **Có SLO rõ ràng** = có thể tập trung vào những gì thực sự quan trọng
- **Error Budget** = cho phép developers phát triển nhanh mà vẫn an toàn

---

### ❓ Câu Hỏi 2: "Làm sao chọn SLO phù hợp? 99.90% hay 99.99%?"

#### **🔴 Vấn đề thực tế:**

PaymentService có 2 lựa chọn:
- **A) SLO = 99.90%** → Error Budget = 0.10% = 43.2 phút/tháng
- **B) SLO = 99.95%** → Error Budget = 0.05% = 21.6 phút/tháng
- **C) SLO = 99.99%** → Error Budget = 0.01% = 4.3 phút/tháng

❓ **Nên chọn cái nào?**

#### **✅ Giải thích - Các yếu tố quyết định:**

**1️⃣ Tác động kinh doanh (Business Impact):**

```
╔════════════════════════════════════════════════╗
║  Loại Service → SLO phù hợp                   ║
╠════════════════════════════════════════════════╣
║ ❌ Payment (mất tiền)      → 99.95% - 99.99%  ║
║    Vì: 1 lỗi = mất $$$                        ║
║                                                ║
║ ⚠️  Booking (chờ lâu)      → 99.90% - 99.95%  ║
║    Vì: Lỗi tạm thời có thể retry              ║
║                                                ║
║ ℹ️  Auth (đăng nhập)       → 99.90%           ║
║    Vì: Người dùng có thể thử lại              ║
║                                                ║
║ 📍 Location (vị trí)       → 99.50% (thấp)    ║
║    Vì: Có retry, không ảnh hưởng revenue      ║
╚════════════════════════════════════════════════╝
```

**2️⃣ Chi phí hạ tầng (Infrastructure Cost):**

```
Quy luật: 9 càng nhiều → chi phí ↑ exponentially

99.90% (1 chín):  
- Downtime cho phép: 43.2 phút/tháng
- Giá: $100/tháng (cấu hình đơn giản)

99.99% (4 chín):
- Downtime cho phép: 4.3 phút/tháng  
- Giá: $10,000+/tháng (multi-AZ, replicas, caching...)

99.999% (5 chín):
- Downtime cho phép: 25.9 giây/tháng
- Giá: $100,000+/tháng
```

**3️⃣ Thực tế của công ty:**

```
Startup (< 100K users):
- Booking SLO: 99.50%
- Payment SLO: 99.90%
- Auth SLO: 99.00%

Công ty vừa (100K-1M users):
- Booking SLO: 99.90%
- Payment SLO: 99.95%
- Auth SLO: 99.50%

Enterprise (> 1M users):
- Booking SLO: 99.99%
- Payment SLO: 99.99%  
- Auth SLO: 99.95%
```

**🎯 Quyết định cho UIT-Go:**

```
UIT-Go là startup → chọn:
✅ BookingSuccessRate: 99.90%
✅ PaymentSuccessRate: 99.95% (cần cao hơn vì tiền)
✅ LoginSuccessRate: 99.90%
✅ MatchLatencyP95: < 200ms
```

---

### ❓ Câu Hỏi 3: "Error Budget là gì? Tại sao gọi là 'ngân sách lỗi'?"

#### **🔴 Vấn đề thực tế:**

```
Situação: 
- SLO Payment = 99.95%
- Hôm nay (24h) hệ thống chạy OK
- Nhóm dev muốn deploy feature mới - chưa test kỹ

❓ Có nên deploy không?
❓ Risk là gì?
❓ Làm sao biết "tối đa bao nhiêu lỗi là được phép"?
```

#### **✅ Giải thích - Khái niệm Error Budget:**

**Error Budget = Allowance for Errors = Phần lỗi được phép**

```
Công thức:
Error Budget (%) = 100% - SLO (%)
Error Budget (thời gian) = Error Budget (%) × Time Window

Ví dụ PaymentSuccessRate:
SLO = 99.95%
Error Budget = 1 - 0.9995 = 0.0005 = 0.05%

Cửa sổ = 30 ngày
Error Budget (thời gian) = 0.05% × 30 × 24 × 60 phút = 21.6 phút/tháng

═══════════════════════════════════════════════════════════

Ý nghĩa:
- Hệ thống được phép "fail" tối đa 21.6 phút/tháng
- Ngoài ra → vi phạm SLO
- Sử dụng hết error budget → STOP tất cả non-essential deployments
```

**🎯 Cách dùng Error Budget trong thực tế:**

**Kịch bản 1: Error Budget dồi dào**
```
Thống kê tháng này:
- Downtime thực tế: 5 phút
- Error Budget còn lại: 21.6 - 5 = 16.6 phút

Quyết định deploy:
✅ OK để deploy (còn error budget)
   Có thể để risk 1-2 phút downtime trong deploy

💡 Strategy: Aggressive deployments (dev nhanh)
```

**Kịch bản 2: Error Budget sắp hết**
```
Thống kê (còn 5 ngày trong tháng):
- Downtime thực tế: 19 phút
- Error Budget còn lại: 21.6 - 19 = 2.6 phút

Quyết định deploy:
🔴 STOP! Không deploy
   Nếu deploy có lỗi → sẽ vi phạm SLO
   
💡 Strategy: Conservation mode
   - Chỉ deploy bug fixes quan trọng
   - Tránh deploy features mới
   - Focus vào stabilization
```

**Kịch bản 3: Error Budget vượt quá**
```
Tình huống xảy ra:
- Downtime thực tế: 30 phút (vượt 21.6)
- Error Budget: -8.4 phút (ĐỎ!)

Kết quả:
🚨 VI PHẠM SLO!

Hành động cần làm:
1. Post-mortem: Tại sao xảy ra?
2. Implement fixes
3. Cập nhật runbook
4. Tính Error Budget lại cho tháng tiếp
```

---

### ❓ Câu Hỏi 4: "Tại sao MatchLatencyP95 < 200ms? Tại sao là P95 chứ không phải Average?"

#### **🔴 Vấn đề thực tế:**

```
API tìm xe (/match-driver) có 3 kịch bản:
A) Average latency = 100ms
   Nhưng có 5% requests lâu hơn 500ms
   
B) Average latency = 150ms
   Tất cả requests < 300ms
   
C) Average latency = 120ms
   Nhưng 10% requests > 1s (timeout)

❓ Cái nào "tốt" hơn? 
❓ Tại sao không dùng average?
```

#### **✅ Giải thích - Percentiles vs Average:**

**Tại sao Average không tốt:**

```
Kịch bản vô lý:
- 99 requests: 10ms (rất nhanh)
- 1 request: 1000ms (rất lâu - timeout)
- Average: (99×10 + 1×1000) / 100 = 109.9ms
- Kết luận: "Trung bình 109.9ms, rất tốt!"

❌ Sai! Người dùng thứ 100 chờ 1 giây → rage quit!

Tại sao Percentile tốt hơn:
- P50 (median): 10ms
- P95: 500ms  
- P99: 1000ms
- Kết luận: "95% users < 500ms, nhưng 5% phải chờ lâu"

✅ Đúng! Này ta biết có 5% users bị slow, cần fix!
```

**Các Percentile phổ biến:**

```
╔════════════╦════════════════════════════════════╗
║ Percentile ║ Ý nghĩa & Khi dùng                 ║
╠════════════╬════════════════════════════════════╣
║ P50        ║ "Median" - 50% requests            ║
║            ║ Dùng: Để hiểu "typical" user       ║
║            ║                                    ║
║ P95        ║ 95% requests < value               ║
║            ║ Dùng: SLO thường dùng              ║
║            ║ Vì: balance UX + feasible          ║
║            ║                                    ║
║ P99        ║ 99% requests < value               ║
║            ║ Dùng: Monitoring outliers          ║
║            ║ Nhạy: quá strict, khó achieve      ║
║            ║                                    ║
║ P99.9      ║ 99.9% requests < value             ║
║            ║ Dùng: Critical service (Banking)   ║
╚════════════╩════════════════════════════════════╝
```

**🎯 Quyết định cho UIT-Go:**

```
Vì sao chọn P95 < 200ms cho MatchLatencyP95?

✅ 200ms là "magic number" trong UX:
   - Người dùng thấy được realtime (~100-200ms)
   - Nếu > 200ms → người dùng thấy có delay

✅ P95 là tiêu chuẩn ngành:
   - Google: P95 < 100ms
   - Amazon: P95 < 200ms
   - Netflix: P95 < 500ms

✅ Cho phép 5% outliers:
   - Load spike, network issue → acceptable
   - Không quá strict

❌ Nếu chọn P99 < 100ms:
   - Quá khó achieve
   - Công sức infra tăng 10x
```

---

### ❓ Câu Hỏi 5: "Trong UIT-Go, cái SLI nào quan trọng nhất?"

#### **✅ Giải thích - Xếp hạng Importance:**

```
╔═══════════════════════════════════════════════════╗
║  Xếp hạng Importance cho UIT-Go                  ║
╠═══════════════════════════════════════════════════╣
║                                                  ║
║  🥇 #1: PaymentSuccessRate (99.95%)              ║
║  ────────────────────────────────────────        ║
║  Tại sao?                                        ║
║  • Mất tiền → lawsuit, churn customer            ║
║  • 1 lỗi payment = -$$$                          ║
║  • Customer chuyển sang Grab ngay                ║
║  • Impact: Revenue ↓↓↓                           ║
║                                                  ║
║  🥈 #2: BookingSuccessRate (99.90%)              ║
║  ────────────────────────────────────────        ║
║  Tại sao?                                        ║
║  • Nếu down → 0 bookings, 0 revenue              ║
║  • Nhưng có retry → user có thể đặt lại          ║
║  • Impact: Revenue ↓ (temporary)                 ║
║                                                  ║
║  🥉 #3: MatchLatencyP95 (< 200ms)                ║
║  ────────────────────────────────────────        ║
║  Tại sao?                                        ║
║  • Nếu lâu → UX xấu                              ║
║  • Nhưng vẫn có revenue (chỉ UX xấu)             ║
║  • Impact: UX xấu, churn (chậm)                  ║
║                                                  ║
║  4️⃣  #4: LoginSuccessRate (99.90%)               ║
║  ────────────────────────────────────────        ║
║  Tại sao?                                        ║
║  • User có thể login lại sau                     ║
║  • Impact: UX xấu (1 lần)                        ║
║                                                  ║
╚═══════════════════════════════════════════════════╝
```

---

## 📊 PHẦN 2: NỀN TẢNG QUAN SÁT (5 Câu Hỏi)

### ❓ Câu Hỏi 6: "Logs vs Metrics vs Traces - Cái nào cần?"

#### **✅ Giải thích - 3 Pillars of Observability:**

```
╔════════════╦═════════════════╦════════════════╦═══════════════╗
║            ║      LOGS       ║     METRICS    ║     TRACES    ║
╠════════════╬═════════════════╬════════════════╬═══════════════╣
║ Định nghĩa ║ Chi tiết mọi    ║ Dữ liệu số    ║ Flow của      ║
║            ║ sự kiện         ║ tập hợp       ║ request      ║
║            ║                 ║                ║               ║
║ Ví dụ      ║ "Payment        ║ PaymentSuccess║ Request →    ║
║            ║ process failed  ║ Rate = 99.5%  ║ Service A →  ║
║            ║ due to DB       ║ p95=150ms     ║ Service B    ║
║            ║ timeout"        ║                ║ → Response   ║
║            ║                 ║                ║               ║
║ Kích thước ║ ⚠️ Rất lớn      ║ ✅ Nhỏ         ║ ⚠️ Trung bình║
║ dữ liệu    ║ (GB/day)        ║ (MB/day)       ║ (100MB/day)  ║
║            ║                 ║                ║               ║
║ Chi phí    ║ $$$ (Cao)       ║ $ (Thấp)       ║ $$ (Trung)   ║
║            ║                 ║                ║               ║
║ Tốc độ     ║ Chậm (grep)     ║ Nhanh (real)   ║ Trung (1-2s) ║
║ truy vấn   ║                 ║                ║               ║
║            ║                 ║                ║               ║
║ Dùng khi   ║ Debug lỗi       ║ Monitor        ║ Trace complex║
║            ║ cụ thể          ║ realtime       ║ requests     ║
╚════════════╩═════════════════╩════════════════╩═══════════════╝
```

**Ví dụ thực tế - Kịch bản 30 phút downtime:**

```
🔴 Cách 1: Chỉ dùng LOGS
- Timeline: 10:00-11:35 (95 phút tìm vấn đề)
- Loss: ~$10,000

✅ Cách 2: LOGS + METRICS + TRACES  
- Timeline: 10:00-10:12 (12 phút)
- Loss: ~$120

💡 Sự khác: Tự động phát hiện vs phải grep thủ công
```

---

### ❓ Câu Hỏi 7: "Structured Logging là gì?"

#### **✅ Giải thích:**

**Structured Logging = Logs dạng JSON (không phải plain text)**

```javascript
// ❌ KHÔNG tốt - Plain text
console.log("Creating payment for user " + user_id + " with amount " + amount)

// ✅ TỐT - Structured JSON
console.log(JSON.stringify({
  timestamp: new Date().toISOString(),
  level: "info",
  msg: "start_createPayment",
  payment_id: generateUUID(),
  user_id: user_id,
  amount: amount,
  requestId: req.headers['x-request-id']
}))
```

**Lợi ích:**
- Dễ search: `filter: level="error" AND payment_id="pay_123"`
- Tự động aggregate: `count(level="error") / count(*)`
- Parse metrics tự động

---

### ❓ Câu Hỏi 8: "EMF (Embedded Metrics Format) là gì?"

#### **✅ Giải thích:**

**EMF = AWS format cho logs chứa metrics**

```json
{
  "timestamp": "2026-01-22T10:00:00Z",
  "level": "info",
  "msg": "payment_processed",
  "status": "confirmed",
  "duration_ms": 150,
  "_aws": {
    "CloudWatch": [
      {
        "namespace": "UITGo/SLI",
        "dimensions": {
          "Service": "payment-service"
        },
        "metrics": [
          {
            "name": "PaymentSuccessCount",
            "value": 1,
            "unit": "Count"
          },
          {
            "name": "PaymentDuration",
            "value": 150,
            "unit": "Milliseconds"
          }
        ]
      }
    ]
  }
}
```

**CloudWatch tự động:**
- ✓ Tăng PaymentSuccessCount += 1
- ✓ Record duration → tính p50, p95, p99
- ✓ Tạo dashboard tự động
- ✓ Setup alarms tự động

---

### ❓ Câu Hỏi 9: "Distributed Tracing là gì?"

#### **✅ Giải thích:**

**Distributed Tracing = Theo dõi 1 request qua nhiều services**

```
Timeline visualization:
├─ TripService Start [0ms]
│ ├─ DriverService Start [0ms]
│ │ ├─ Redis [0-10ms]
│ │ ├─ UserService Start [10ms]
│ │ │ └─ AuthService [10-90ms] ◄─ 80ms (BOTTLENECK!)
│ │ │ └─ Validate [90-92ms]
│ │ ├─ Return [92ms]
│ ├─ TripService End [100ms]

🎯 Tìm được: AuthService làm chậm hệ thống!
```

---

### ❓ Câu Hỏi 10: "Centralized Logging là gì?"

#### **✅ Giải thích:**

**Centralized Logging = Logs từ tất cả servers → 1 chỗ**

```
Trước (Logs trên server):
┌─────────────────┐
│ Instance 1      │ ← Phải SSH
└─────────────────┘
┌─────────────────┐
│ Instance 2      │ ← Phải SSH
└─────────────────┘

Sau (Centralized):
┌──────────────────────┐
│ CloudWatch Logs      │ ← 1 chỗ search tất cả!
│ (centralized)        │
└──────────────────────┘
```

**Lợi ích:**
- Unified search từ tất cả instances
- Auto correlation, alerting
- Chi phí storage giảm 50%

---

## 🔔 PHẦN 3: DASHBOARD & ALERTS (5 Câu Hỏi)

### ❓ Câu Hỏi 11: "Dashboard cần show cái gì?"

#### **✅ Giải thích - Dashboard must-haves:**

```
╔═══════════════════════════════════════════════════════════╗
║  UIT-Go Observability Dashboard                          ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  🎯 SLI Metrics (Mục đích chính)                          ║
║  ┌─────────────────────────────────────────────────────┐ ║
║  │ PaymentSuccessRate: 99.95% ✅  (SLO: 99.95%)        │ ║
║  │ BookingSuccessRate: 99.90% ✅  (SLO: 99.90%)        │ ║
║  │ MatchLatencyP95: 180ms ✅       (SLO: <200ms)       │ ║
║  │ LoginSuccessRate: 99.89% ✅    (SLO: 99.90%)        │ ║
║  └─────────────────────────────────────────────────────┘ ║
║                                                           ║
║  ⏰ Error Budget Tracking                                 ║
║  ┌─────────────────────────────────────────────────────┐ ║
║  │ Payment: ▓▓▓▓▓▓░░░ 16.6/21.6 min                    │ ║
║  │ Booking: ▓▓░░░░░░░░ 38.0/43.2 min                   │ ║
║  │ Auth:    ▓░░░░░░░░░░ 42.0/43.2 min                  │ ║
║  └─────────────────────────────────────────────────────┘ ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

---

### ❓ Câu Hỏi 12: "Alert cần bao nhiêu? Loại nào?"

#### **✅ Giải thích - Alert Strategy:**

```
╔════════════════════════════════════════════════════════╗
║  UIT-Go Critical Alerts (5-10 alerts chỉ)             ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  🔴 CRITICAL (P1)                                      ║
║  1. PaymentSuccessRate < 99.95%                        ║
║  2. All Payment Instances Down                         ║
║                                                        ║
║  🟠 HIGH (P2)                                           ║
║  3. Error Budget Payment < 10%                         ║
║  4. BookingSuccessRate < 99.90%                        ║
║                                                        ║
║  🟡 MEDIUM (P3)                                         ║
║  5. MatchLatencyP95 > 200ms                            ║
║  6. LoginSuccessRate < 99.90%                          ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
```

**Nguyên tắc:**
- Alert khi SLO BỊ VI PHẠM (không preventive)
- Alert dựa trên BUSINESS IMPACT, không metrics ngẫu nhiên
- Mỗi alert phải có RUNBOOK

---

### ❓ Câu Hỏi 13: "Runbook là gì?"

#### **✅ Giải thích:**

**Runbook = Instruction Manual = Hướng dẫn từng bước fix**

Ví dụ:
```
Alert: "Payment Error Budget Low"

Step 1: Assess severity (2 min)
→ Check current success rate

Step 2: Check service status (3 min)
→ SSH, check logs, restart if needed

Step 3: Monitor recovery (5 min)
→ Watch metrics go back to normal

Step 4: If not recovered
→ Page on-call engineer, escalate
```

---

### ❓ Câu Hỏi 14: "Trade-offs của Observability?"

#### **✅ Giải thích - 3 Options:**

```
╔═════════════════════════════════════════════════════════╗
║  Option A: Full Stack (Logs+Metrics+Traces)            ║
║  Cost: $500/month | MTTR: 5-10 min | Best coverage    ║
╚═════════════════════════════════════════════════════════╝

╔═════════════════════════════════════════════════════════╗
║  Option B: Balanced (Logs+Metrics)  ✅ UIT-Go này      ║
║  Cost: $150/month | MTTR: 20-30 min | 85% coverage    ║
╚═════════════════════════════════════════════════════════╝

╔═════════════════════════════════════════════════════════╗
║  Option C: Minimal (Metrics only)                       ║
║  Cost: $50/month | MTTR: 2-3 hours | 30% coverage     ║
╚═════════════════════════════════════════════════════════╝
```

---

### ❓ Câu Hỏi 15: "Làm sao đánh giá observability system 'tốt'?"

#### **✅ Giải thích - Maturity Levels:**

```
LEVEL 0: Blind (No observability)
- MTTR: 2-8 hours
- Cost: $0 but lose $10K/hour when down ❌

LEVEL 1: Basic Logging
- MTTR: 30-60 min
- Cost: $50/month ⚠️

LEVEL 2: Metrics + Basic Alerts
- MTTR: 10-20 min
- Cost: $100-150/month ✅ UIT-Go target

LEVEL 3: Structured Logs + Metrics + Dashboard
- MTTR: 5-10 min
- Cost: $200-300/month ✅✅

LEVEL 4: Full Stack + Tracing
- MTTR: 2-5 min
- Cost: $400-500/month ✅✅✅

LEVEL 5: Intelligent (ML-powered)
- MTTR: < 1 min (automated)
- Cost: $1000+/month
```

---

## 📋 SUMMARY

**15 Câu Hỏi được phân loại:**

- **Phần 1 (SLOs/SLIs):** Q1-Q5 - Định nghĩa, chọn SLO, Error Budget, Percentiles, Ưu tiên
- **Phần 2 (Observability):** Q6-Q10 - 3 Pillars, Structured Logs, EMF, Tracing, Centralized Logging  
- **Phần 3 (Dashboard/Alerts):** Q11-Q15 - Dashboard design, Alerts, Runbooks, Trade-offs, Maturity Levels

**Tất cả đã được giải thích chi tiết với ví dụ cụ thể từ UIT-Go! 🚀**
