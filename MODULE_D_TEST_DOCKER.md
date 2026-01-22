# 🐳 Hướng dẫn Test Module D với Docker

## 📌 Tại sao dùng Docker?

**Docker Compose** cho phép bạn:
- ✅ Chạy tất cả 4 services + 4 databases + Redis + Jaeger **cùng lúc**
- ✅ Mô phỏng production environment (các services giao tiếp qua network)
- ✅ Dễ dàng reset lại trạng thái (xóa containers, volumes)
- ✅ Xem logs từ tất cả services cùng một chỗ
- ✅ Test OpenTelemetry tracing với Jaeger

---

## 🚀 BƯỚC 1: Chuẩn bị Docker

### 1.1 Kiểm tra Docker đã cài chưa

```powershell
docker --version
docker-compose --version
```

**Kết quả kỳ vọng:**
```
Docker version 24.0.0+
Docker Compose version 2.20.0+
```

Nếu chưa có, tải từ: https://www.docker.com/products/docker-desktop

### 1.2 Khởi động Docker Desktop

- Mở **Docker Desktop** (tìm trong Windows Start Menu)
- Chờ cho đến khi thấy dòng chữ "Docker is running" ✅

---

## 🎯 BƯỚC 2: Khởi động toàn bộ Infrastructure

### 2.1 Mở PowerShell ở thư mục project

```powershell
cd e:\student\DIENTOANDAMMAY\DOAN
```

### 2.2 Build & khởi động tất cả services

```powershell
docker-compose up --build
```

**Quá trình:**
- Docker sẽ build images cho 4 services
- Khởi động 4 databases PostgreSQL
- Khởi động Redis
- Khởi động Jaeger
- Khởi động 4 services (payment, trip, user, driver)

⏱️ **Thời gian:** ~2-3 phút lần đầu (tùy vào internet)

### 2.3 Xác nhận tất cả services đã chạy

**Output cuối cùng sẽ hiển thị:**

```
uit-go-payment | PaymentService running on port 3000
uit-go-trip | TripService listening on port 8082
uit-go-user | Server running on port 3000
uit-go-driver | DriverService running on port 8000
```

✅ Tất cả services đã ready!

---

## 🧪 BƯỚC 3: Test Module D với Docker

### TEST 1️⃣: SLO/SLI Definitions (5 phút)

**Không cần Docker đặc biệt - chỉ review file:**

```powershell
# Mở file trong VS Code (terminal mới, đừng tắt docker-compose terminal)
code docs\observability\SLOs.md
```

**Kiểm tra:**
- [ ] Booking SLI: `BookingSuccessRate ≥ 99.90%` ✅
- [ ] Payment SLI: `PaymentSuccessRate ≥ 99.95%` ✅
- [ ] Auth SLI: `LoginSuccessRate ≥ 99.9%` ✅
- [ ] Match SLI: `MatchLatencyP95 < 200ms` ✅

---

### TEST 2️⃣: Payment Service Metrics & Logs (Docker) (10 phút)

#### 📍 Kiểm tra logs Payment Service

**Terminal 2 (mở terminal PowerShell mới):**

```powershell
# Xem logs real-time từ payment service container
docker logs -f uit-go-payment
```

**Kết quả:**
```
PaymentService running on port 3000
[Fastify logs tại đây...]
```

#### 📍 Gửi request tạo payment

**Terminal 3 (mở terminal mới):**

```powershell
$response = Invoke-WebRequest `
  -Uri "http://localhost:3004/payments" `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -Body '{
    "amount": 100,
    "trip_id": "trip_docker_123",
    "user_id": "user_docker_1",
    "payment_method": "card"
  }' `
  -UseBasicParsing

Write-Host "Status: $($response.StatusCode)"
Write-Host "Response: $($response.Content)"
```

#### 📍 Kiểm tra logs (Terminal 2)

**Bạn sẽ thấy:**

```json
{
  "msg": "start_createPayment",
  "payment_id": "pay_abc",
  "amount": 100,
  "trip_id": "trip_docker_123"
}

{
  "msg": "after_recordPaymentAttempt",
  "payment_id": "pay_abc",
  "duration_ms": 45
}

{
  "msg": "after_processPayment",
  "payment_id": "pay_abc",
  "status": "confirmed",
  "duration_ms": 150
}
```

**✓ Kiểm tra:**
- [ ] Có 3 logs trên (start, record, process) ✅
- [ ] Status code từ request là 200/201 ✅
- [ ] Duration logs có giá trị ms ✅

---

### TEST 3️⃣: Trip Service Metrics & Logs (Docker) (10 phút)

#### 📍 Xem logs Trip Service

**Terminal 4:**

```powershell
docker logs -f uit-go-trip
```

#### 📍 Gửi request tạo booking

**Terminal 3 (dùng lại từ trước):**

```powershell
# Trước tiên, cần đăng ký user
$userResponse = Invoke-WebRequest `
  -Uri "http://localhost:3000/auth/register" `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -Body '{
    "username": "testuser_docker",
    "password": "password123"
  }' `
  -UseBasicParsing

Write-Host "User creation: $($userResponse.StatusCode)"

# Sau đó tạo trip/booking
$tripResponse = Invoke-WebRequest `
  -Uri "http://localhost:8082/trips" `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -Body '{
    "user_id": "testuser_docker",
    "pickup_location": "10.7769,106.6669",
    "dropoff_location": "10.8000,106.7000"
  }' `
  -UseBasicParsing

Write-Host "Trip creation: $($tripResponse.StatusCode)"
```

#### 📍 Kiểm tra logs (Terminal 4)

**Bạn sẽ thấy:**

```json
{
  "msg": "start_createTrip",
  "trip_id": "trip_xyz",
  "user_id": "testuser_docker",
  "status": "PENDING"
}

{
  "msg": "after_confirmTrip",
  "trip_id": "trip_xyz",
  "status": "CONFIRMED",
  "duration_ms": 234
}
```

**✓ Kiểm tra:**
- [ ] Có logs trip creation ✅
- [ ] Status là JSON ✅
- [ ] Status code 200 ✅

---

### TEST 4️⃣: Synthetic Tests (Docker) (15 phút)

#### 📍 Test Payment Service (50 requests)

```powershell
cd e:\student\DIENTOANDAMMAY\DOAN\scripts

# Chạy synthetic test (docker services vẫn chạy ở ports 3004, 8082)
.\synthetic-payment-test.ps1 -Count 50 -IntervalSeconds 0.1
```

**Kết quả kỳ vọng:**

```
Starting synthetic payment test...
Sending 50 requests to http://localhost:3004/payments

Summary:
- Success Rate: 98%
- P50 Duration: 145ms
- P95 Duration: 320ms
- Avg Duration: 158ms

Results saved to: synthetic-payment-results-20260121-143022.csv
```

**✓ Kiểm tra:**
- [ ] Success Rate ≥ 95% ✅
- [ ] P95 Duration < 1000ms ✅
- [ ] File CSV được tạo ✅

#### 📍 Test Trip Service (50 requests)

```powershell
.\synthetic-booking-test.ps1 -Count 50 -IntervalSeconds 0.1
```

**Kết quả kỳ vọng:**

```
Starting synthetic booking test...
Sending 50 requests to http://localhost:8082/trips

Summary:
- Success Rate: 96%
- P50 Duration: 234ms
- P95 Duration: 456ms
- Avg Duration: 267ms

Results saved to: synthetic-booking-results-20260121-143022.csv
```

---

### TEST 5️⃣: Xem Docker Container Status (5 phút)

**Terminal mới:**

```powershell
# Liệt kê tất cả containers đang chạy
docker ps

# Hoặc xem chi tiết hơn
docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
```

**Kết quả kỳ vọng:**

```
NAMES                 PORTS                     STATUS
uit-go-payment       0.0.0.0:3004->3000/tcp   Up 5 minutes
uit-go-trip          0.0.0.0:8082->8082/tcp   Up 5 minutes
uit-go-user          0.0.0.0:3000->3000/tcp   Up 5 minutes
uit-go-driver        0.0.0.0:8000->8000/tcp   Up 5 minutes
uit-go-redis         0.0.0.0:6379->6379/tcp   Up 5 minutes
uit-go-jaeger        0.0.0.0:16686->16686/tcp Up 5 minutes
uit-go-payment-db    0.0.0.0:5432->5432/tcp   Up 5 minutes
uit-go-trip-db       0.0.0.0:5433->5432/tcp   Up 5 minutes
uit-go-user-db       0.0.0.0:5434->5432/tcp   Up 5 minutes
uit-go-driver-db     0.0.0.0:5435->5432/tcp   Up 5 minutes
```

✅ Tất cả 10 containers đang chạy!

---

### TEST 6️⃣: Xem Jaeger Dashboard (Distributed Tracing) (5 phút)

#### 📍 Mở Jaeger UI

```powershell
# Browser sẽ mở tự động, hoặc vào:
http://localhost:16686
```

#### 📍 Kiểm tra traces

1. Chọn Service dropdown → chọn `payment-service`
2. Click "Find Traces" button
3. Bạn sẽ thấy danh sách traces từ các requests vừa gửi

**✓ Kiểm tra:**
- [ ] Thấy payment-service traces ✅
- [ ] Thấy trip-service traces ✅
- [ ] Mỗi trace có multiple spans (request → database → response) ✅

---

### TEST 7️⃣: Kiểm tra Database (Docker) (5 phút)

#### 📍 Kết nối đến Payment Database

```powershell
# Cách 1: Dùng Docker exec
docker exec -it uit-go-payment-db psql -U postgres -d payments -c "SELECT * FROM payments LIMIT 5;"
```

**Kết quả:**
```
payment_id | amount | status | created_at
-----------+--------+--------+-------------------
pay_123    | 100    | CONFIRMED | 2026-01-21 14:30:00
...
```

**✓ Kiểm tra:**
- [ ] Có dữ liệu payment trong database ✅
- [ ] Status là CONFIRMED hoặc PENDING ✅

#### 📍 Kiểm tra Trip Database

```powershell
docker exec -it uit-go-trip-db psql -U postgres -d tripdb -c "SELECT * FROM trips LIMIT 5;"
```

---

### TEST 8️⃣: Xem Logs từ Docker Compose (10 phút)

#### 📍 Xem logs tất cả services cùng lúc

```powershell
# Từ terminal chạy docker-compose (Terminal 1)
# Bạn sẽ thấy logs từ tất cả services
```

**Ví dụ output:**

```
uit-go-payment   | {"msg":"start_createPayment","payment_id":"pay_456",...}
uit-go-trip      | {"msg":"start_createTrip","trip_id":"trip_456",...}
uit-go-user      | POST /auth/register 200
uit-go-driver    | Driver location updated
```

#### 📍 Xem logs từ service cụ thể

```powershell
# Chỉ xem payment service
docker-compose logs payment-service

# Chỉ xem trip service
docker-compose logs trip-service

# Xem logs real-time (theo dõi)
docker-compose logs -f payment-service
```

---

### TEST 9️⃣: Kiểm tra Network Communication (5 phút)

**Verify rằng services giao tiếp với nhau qua Docker network:**

```powershell
# Kiểm tra network
docker network inspect uit-go_uit-network

# Hoặc test ping giữa containers
docker exec uit-go-payment ping -c 2 trip-service

# Kết quả kỳ vọng:
# PING trip-service (172.20.0.5) 56(84) bytes of data.
# 64 bytes from trip-service (172.20.0.5): icmp_seq=1 time=0.5 ms
```

✅ Services có thể giao tiếp với nhau!

---

### TEST 🔟: Terraform Validation (10 phút)

**Vẫn sử dụng từ hướng dẫn cũ:**

```powershell
cd e:\student\DIENTOANDAMMAY\DOAN\infra\observability

terraform validate
terraform plan
```

---

## 🛑 BƯỚC 4: Dừng Docker Compose

**Khi xong test, tắt tất cả services:**

```powershell
# Ở Terminal chạy docker-compose, nhấn Ctrl+C
# Hoặc từ terminal mới:

docker-compose down

# Nếu muốn xóa volumes (reset dữ liệu):
docker-compose down -v
```

---

## 📊 BẢNG TÓM TẮT KẾT QUẢ DOCKER TEST

| Test | Kết quả | Ghi chú |
|------|---------|---------|
| 1. Docker Compose up --build | [ ] PASS / [ ] FAIL | Tất cả 10 containers chạy |
| 2. Payment Service Logs & Metrics | [ ] PASS / [ ] FAIL | JSON logs xuất hiện |
| 3. Trip Service Logs & Metrics | [ ] PASS / [ ] FAIL | Booking logs xuất hiện |
| 4. Synthetic Payment Test (50 req) | [ ] PASS / [ ] FAIL | Success Rate: ___% |
| 5. Synthetic Booking Test (50 req) | [ ] PASS / [ ] FAIL | Success Rate: ___% |
| 6. Jaeger Dashboard Traces | [ ] PASS / [ ] FAIL | Traces visible |
| 7. Database Queries | [ ] PASS / [ ] FAIL | Có dữ liệu |
| 8. Docker Network Communication | [ ] PASS / [ ] FAIL | Services giao tiếp được |
| 9. Terraform Validation | [ ] PASS / [ ] FAIL | No syntax errors |
| 10. Runbooks & Trade-offs Review | [ ] PASS / [ ] FAIL | Đầy đủ content |

**Tổng kết:**
- [ ] **TẤT CẢ PASS ✅** → Module D hoàn thành với Docker
- [ ] **CÓ FAIL ⚠️** → Debug từng service

---

## 🔧 DOCKER TROUBLESHOOTING

### ❌ **Port conflict (Port already in use)**

```powershell
# Tìm process sử dụng port
netstat -ano | findstr ":3004"

# Kill process
taskkill /PID <PID> /F

# Hoặc thay đổi ports trong docker-compose.yml
# "3004:3000" thành "3005:3000"
```

### ❌ **Container không start**

```powershell
# Xem lỗi chi tiết
docker logs uit-go-payment

# Hoặc
docker-compose logs payment-service

# Rebuild
docker-compose down -v
docker-compose up --build
```

### ❌ **Out of memory**

```powershell
# Restart Docker Desktop hoặc
# Tăng memory allocation trong Docker Desktop Settings
# (Settings → Resources → Memory: 4GB+)
```

### ❌ **Database connection failed**

```powershell
# Kiểm tra health
docker ps

# Nếu database status là "unhealthy", chờ 30 giây
# Hoặc restart:
docker-compose restart payment-db
```

### ❌ **Jaeger không thấy traces**

```powershell
# Kiểm tra Jaeger logs
docker logs uit-go-jaeger

# Kiểm tra environment variables
docker inspect uit-go-payment | grep -i "OTEL"
```

---

## 📝 ADVANTAGES: Docker vs Local

| Aspect | Docker | Local |
|--------|--------|-------|
| Setup | 1 command | Cấu hình phức tạp |
| Databases | Tự động | Cài PostgreSQL thủ công |
| Network testing | ✅ Dễ test | ❌ Khó test giao tiếp |
| Jaeger tracing | ✅ Có | ❌ Phải cài riêng |
| Reset trạng thái | 1 command | Xóa files thủ công |
| Production-like | ✅ Gần giống | ❌ Khác nhiều |
| **Khuyên dùng** | **✅ TEST MODULE D** | Local dev |

---

## ✅ QUICK REFERENCE: Docker Commands

```powershell
# Start all services
docker-compose up --build

# Stop all services
docker-compose down

# View logs
docker-compose logs
docker-compose logs -f payment-service

# Execute command in container
docker exec -it uit-go-payment sh

# Check container status
docker ps
docker ps -a

# Remove everything (reset)
docker-compose down -v

# Rebuild images
docker-compose build --no-cache
```

---

**Hoàn thành vào lúc:** __________  
**Người test:** __________  
**Tổng thời gian:** ≈ 90 phút (từ start docker đến kết thúc test)
