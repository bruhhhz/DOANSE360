# 🧪 Hướng dẫn Chi Tiết Test Module D - Observability

## 📌 Module D là gì?

**Module D** là yêu cầu xây dựng hệ thống **Observability** (theo dõi & chẩn đoán) cho UIT-Go microservices.

Nó bao gồm:
- 📊 **SLO/SLI**: Định nghĩa chất lượng dịch vụ (Service Level Objectives)
- 📈 **Metrics & Logs**: Thu thập dữ liệu từ services
- 🔔 **Alerts & Dashboards**: Cảnh báo khi có sự cố
- 📋 **Runbooks**: Hướng dẫn xử lý sự cố
- 🏗️ **Infrastructure as Code**: Terraform để provision CloudWatch, SNS, IAM

---

## 🎯 4 Flows cần Monitor

| Flow | Service | SLI | Tiêu chí |
|------|---------|-----|----------|
| **1. Đặt xe** | trip-service | BookingSuccessRate | ≥ 99.90% (30 ngày) |
| **2. Match driver** | driver-service | MatchLatencyP95 | < 200ms (7 ngày) |
| **3. Thanh toán** | payment-service | PaymentSuccessRate | ≥ 99.95% (30 ngày) |
| **4. Đăng nhập** | user-service | LoginSuccessRate | ≥ 99.9% (7 ngày) |

---

## ✅ CÁCH TEST TỪNG PHẦN

### **PHẦN 1️⃣: Kiểm tra SLO/SLI Definitions (5 phút)**

**Mục tiêu:** Đảm bảo các tiêu chí chất lượng được định nghĩa rõ ràng

**Các bước:**

1. **Mở file định nghĩa SLO:**
   ```powershell
   # Windows: Mở file bằng VS Code hoặc Notepad
   code docs\observability\SLOs.md
   ```

2. **Kiểm tra từng SLI:**

   **✓ Booking SLI:**
   - Tìm dòng: `SLI name: BookingSuccessRate`
   - Kiểm tra: `SLO: ≥ 99.90%`
   - Kiểm tra: `Window: Rolling 30 days`
   - Kiểm tra: `Error budget: 43.2 phút/tháng`

   **✓ Payment SLI:**
   - Tìm dòng: `SLI name: PaymentSuccessRate`
   - Kiểm tra: `SLO: ≥ 99.95%`
   - Kiểm tra: `Window: Rolling 30 days`

   **✓ Auth SLI:**
   - Tìm dòng: `SLI name: LoginSuccessRate`
   - Kiểm tra: `SLO: ≥ 99.9%`
   - Kiểm tra: `Window: Rolling 7 days`

   **✓ Match SLI:**
   - Tìm dòng: `SLI name: MatchLatencyP95`
   - Kiểm tra: `SLO: p95 < 200ms`
   - Kiểm tra: `Window: Rolling 7 days`

3. **Ghi nhận kết quả:**
   - [ ] Tất cả 4 SLIs được định nghĩa rõ ràng → **TEST PASS ✅**
   - [ ] Thiếu hoặc không rõ ràng → **TEST FAIL ❌**

---

### **PHẦN 2️⃣: Test Payment Service (Metrics & Logs) (15 phút)**

**Mục tiêu:** Xác nhận payment-service ghi log và emit metrics đúng cách

#### 📍 Step 1: Chuẩn bị môi trường

```powershell
# 1. Mở PowerShell Terminal (Run as Administrator)
# 2. Chuyển đến thư mục payment-service
cd e:\student\DIENTOANDAMMAY\DOAN\services\payment-service

# 3. Cài đặt dependencies
npm install

# 4. Kiểm tra file cần có
ls .\src\observability\
# Phải thấy: metrics.js, plugin.js, tracing.js
```

#### 📍 Step 2: Khởi động service

```powershell
# Chạy payment service (Terminal 1 - GIỮ NGUYÊN)
node src/index.js
```

**Kết quả kỳ vọng:**
```
PaymentService running on port 3004
```

#### 📍 Step 3: Test endpoint (Terminal 2 - MỞ TERMINAL MỚI)

```powershell
# Mở PowerShell Terminal mới
# Gửi request tạo payment
$response = Invoke-WebRequest `
  -Uri "http://localhost:3004/payments" `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -Body '{"amount": 100, "trip_id": "trip123", "user_id": "user1", "payment_method": "card"}' `
  -UseBasicParsing

# Kiểm tra response
Write-Host "Status Code: $($response.StatusCode)"
Write-Host "Response: $($response.Content)"
```

#### 📍 Step 4: Kiểm tra logs (Terminal 1)

**Bạn sẽ thấy dòng logs tương tự như sau:**

```json
{
  "level": 30,
  "time": 1674000000000,
  "pid": 12345,
  "hostname": "DESKTOP-ABC",
  "msg": "start_createPayment",
  "payment_id": "pay_xyz",
  "amount": 100,
  "trip_id": "trip123"
}

{
  "level": 30,
  "time": 1674000000100,
  "msg": "after_recordPaymentAttempt",
  "payment_id": "pay_xyz",
  "duration_ms": 45
}

{
  "level": 30,
  "time": 1674000000150,
  "msg": "after_processPayment",
  "payment_id": "pay_xyz",
  "status": "confirmed",
  "duration_ms": 150
}
```

**✓ Kiểm tra:**
- [ ] Có log chứa `"msg": "start_createPayment"` → ✅
- [ ] Có log chứa `"msg": "after_recordPaymentAttempt"` → ✅
- [ ] Có log chứa `"msg": "after_processPayment"` → ✅
- [ ] Mỗi log là JSON (có dấu `{}`) → ✅
- [ ] Response status 200 hoặc 201 → ✅

**Kết quả:**
- Tất cả ✅ → **TEST PASS**
- Có ❌ → **TEST FAIL**

---

### **PHẦN 3️⃣: Test Trip Service (Booking) (15 phút)**

**Mục tiêu:** Xác nhận trip-service ghi log booking events đúng cách

#### 📍 Step 1: Chuẩn bị

```powershell
cd e:\student\DIENTOANDAMMAY\DOAN\services\trip-service

npm install
```

#### 📍 Step 2: Khởi động service

```powershell
# Terminal 3 (GIỮ NGUYÊN)
node src/app.js
```

**Kết quả kỳ vọng:**
```
TripService listening on port 3002
```

#### 📍 Step 3: Test booking endpoint

```powershell
# Terminal mới (Terminal 4)
$response = Invoke-WebRequest `
  -Uri "http://localhost:3002/trips" `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -Body '{
    "user_id": "user1",
    "pickup_location": "10.7769,106.6669",
    "dropoff_location": "10.8000,106.7000",
    "payment_method": "card"
  }' `
  -UseBasicParsing

Write-Host "Status Code: $($response.StatusCode)"
```

#### 📍 Step 4: Kiểm tra logs (Terminal 3)

**Bạn sẽ thấy dòng logs tương tự:**

```json
{
  "msg": "start_createTrip",
  "trip_id": "trip_abc123",
  "user_id": "user1",
  "status": "PENDING"
}

{
  "msg": "after_confirmTrip",
  "trip_id": "trip_abc123",
  "status": "CONFIRMED",
  "duration_ms": 234
}
```

**✓ Kiểm tra:**
- [ ] Có logs trip creation → ✅
- [ ] Có logs trip confirmation → ✅
- [ ] Status là JSON → ✅
- [ ] Response 200/201 → ✅

---

### **PHẦN 4️⃣: Chạy Synthetic Tests (Load Testing) (10 phút)**

**Mục tiêu:** Mô phỏng 50+ requests và đo performance (success rate, latency)

#### 📍 Test Payment Service (50 requests)

```powershell
# Terminal 5 (MỚI)
cd e:\student\DIENTOANDAMMAY\DOAN\scripts

# Chạy synthetic test
.\synthetic-payment-test.ps1 -Count 50 -IntervalSeconds 0.1
```

**Quá trình chạy:**
- Sẽ gửi 50 requests đến payment service
- Mỗi request cách 0.1 giây
- Ghi lại: status code, duration, success/fail

**Kết quả kỳ vọng:**

Sau ~5 giây, bạn sẽ thấy output như sau:

```
Starting synthetic payment test...
Sent 50 requests

Summary:
- Success Rate: 98%
- P50 Duration: 145ms
- P95 Duration: 320ms
- Avg Duration: 158ms

Results saved to: synthetic-payment-results-20260121-143022.csv
```

**✓ Kiểm tra:**
- [ ] Success Rate ≥ 95% → ✅ (local có thể bé hơn)
- [ ] P95 Duration < 1000ms → ✅ (local có thể cao hơn)
- [ ] File CSV được tạo → ✅

#### 📍 Test Booking Service (50 requests)

```powershell
# Chạy synthetic booking test
.\synthetic-booking-test.ps1 -Count 50 -IntervalSeconds 0.1
```

**Kết quả kỳ vọng:**
```
Starting synthetic booking test...
Sent 50 requests

Summary:
- Success Rate: 96%
- P50 Duration: 234ms
- P95 Duration: 456ms
- Avg Duration: 267ms

Results saved to: synthetic-booking-results-20260121-143022.csv
```

---

### **PHẦN 5️⃣: Kiểm tra Terraform (IaC) (10 phút)**

**Mục tiêu:** Xác nhận hạ tầng CloudWatch/SNS/IAM được định nghĩa đúng

#### 📍 Step 1: Kiểm tra Terraform syntax

```powershell
cd e:\student\DIENTOANDAMMAY\DOAN\infra\observability

# Kiểm tra syntax (không thực thi)
terraform validate

# Xem những gì sẽ được tạo (không thực thi)
terraform plan
```

#### 📍 Step 2: Kiểm tra file main.tf

**Mở file và tìm những phần sau:**

```powershell
code main.tf
```

**✓ Kiểm tra có:**
- [ ] CloudWatch Log Group `/uitgo/payment-service` → ✅
- [ ] CloudWatch Log Group `/uitgo/trip-service` → ✅
- [ ] CloudWatch Dashboard `UITGo-SLO-Dashboard` → ✅
- [ ] SNS Topic `uitgo-alerts` → ✅
- [ ] IAM Policy cho X-Ray permissions → ✅
- [ ] CloudWatch Alarm cho Payment SLO → ✅
- [ ] CloudWatch Alarm cho Match SLO → ✅

**Kết quả:**
- Tất cả ✅ → **TEST PASS**
- Thiếu hoặc lỗi → **TEST FAIL**

---

### **PHẦN 6️⃣: Kiểm tra Runbooks (5 phút)**

**Mục tiêu:** Xác nhận có hướng dẫn xử lý sự cố

#### 📍 Mở Runbook Payment SLO Breach

```powershell
code e:\student\DIENTOANDAMMAY\DOAN\runbooks\payment_slo_breach.md
```

**✓ Kiểm tra:**
- [ ] Có mục "🔴 Symptoms" (dấu hiệu) → ✅
- [ ] Có mục "⚡ Quick Checks" (kiểm tra nhanh) → ✅
- [ ] Có mục "🔍 Root Causes" (nguyên nhân) → ✅
- [ ] Có mục "🛠️ Mitigations" (cách xử lý) → ✅
- [ ] Có mục "📞 Escalation" (escalate lên ai) → ✅

**Kết quả:** [ ] Có đầy đủ → **PASS** / [ ] Thiếu → **FAIL**

---

### **PHẦN 7️⃣: Kiểm tra Trade-offs Analysis (5 phút)**

**Mục tiêu:** Xác nhận có giải thích tại sao lựa chọn technologies này

```powershell
code e:\student\DIENTOANDAMMAY\DOAN\docs\observability\tradeoffs.md
```

**✓ Kiểm tra:**
- [ ] Giải thích tại sao chọn EMF (aws-embedded-metrics) → ✅
- [ ] So sánh EMF vs Prometheus vs DataDog → ✅
- [ ] Giải thích tại sao chọn OpenTelemetry → ✅
- [ ] Có pros/cons → ✅
- [ ] Có recommendations → ✅

---

## 🎯 BẢNG TÓM TẮT KẾT QUẢ

| Test | Kết quả | Ghi chú |
|------|---------|---------|
| 1. SLO/SLI Definitions | [ ] PASS / [ ] FAIL | |
| 2. Payment Service Logs & Metrics | [ ] PASS / [ ] FAIL | |
| 3. Trip Service Logs & Metrics | [ ] PASS / [ ] FAIL | |
| 4. Synthetic Payment Test (50 requests) | [ ] PASS / [ ] FAIL | Success Rate: ___% |
| 5. Synthetic Booking Test (50 requests) | [ ] PASS / [ ] FAIL | Success Rate: ___% |
| 6. Terraform Infrastructure Validation | [ ] PASS / [ ] FAIL | |
| 7. Runbooks Review | [ ] PASS / [ ] FAIL | |
| 8. Trade-offs Analysis | [ ] PASS / [ ] FAIL | |

**TỔNG KẾT:**
- [ ] **TẤT CẢ PASS ✅** → Module D hoàn thành
- [ ] **CÓ 1-2 FAIL ⚠️** → Cần fix nhỏ
- [ ] **CÓ > 2 FAIL ❌** → Cần review lại design

---

## 🔧 TROUBLESHOOTING

**Vấn đề: Service không khởi động**
```powershell
# Kiểm tra port đã được dùng chưa
netstat -ano | findstr ":3004"
# Nếu có, kill process
taskkill /PID <PID> /F
```

**Vấn đề: npm install lỗi**
```powershell
# Xóa node_modules và package-lock.json
rm -r node_modules
rm package-lock.json
npm install
```

**Vấn đề: Synthetic test không chạy**
```powershell
# Kiểm tra PowerShell execution policy
Get-ExecutionPolicy
# Nếu là "Restricted", chạy:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 📝 NOTES & OBSERVATIONS

```
Ghi chú các vấn đề gặp phải:
_________________________________
_________________________________
_________________________________

Các cải tiến cần làm:
_________________________________
_________________________________
_________________________________
```

---

**Hoàn thành vào lúc:** __________  
**Người test:** __________  
**Tổng thời gian:** ≈ 70 phút (1 giờ 10 phút)
