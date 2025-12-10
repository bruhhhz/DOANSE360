# UIT-Go Microservices - Phân Tích Chi Tiết & Hướng Dẫn

**Ngày tạo**: 10 Tháng 12, 2025  
**Phiên bản**: 1.0  
**Ngôn ngữ**: Tiếng Việt  
**Mục đích**: Tài liệu toàn diện về cấu trúc, chức năng, Module D & E của đồ án UIT-Go

---

## 📑 MỤC LỤC

1. [Tổng Quan Đồ Án](#tổng-quan-đồ-án)
2. [Trip Service - Phân Tích Chi Tiết](#trip-service---phân-tích-chi-tiết)
3. [Module D - Observability](#module-d---observability)
4. [Module E - Deployment & IaC](#module-e---deployment--iac)
5. [Hướng Dẫn Test](#hướng-dẫn-test)
6. [Kết Luận & Đề Xuất](#kết-luận--đề-xuất)

---

## 🎯 Tổng Quan Đồ Án

### Mô Tả
**UIT-Go** là một nền tảng dịch vụ đặt xe được xây dựng dựa trên kiến trúc **Microservices**. Hệ thống bao gồm:

- **4 Microservices chính**:
  - `user-service`: Quản lý người dùng & xác thực
  - `trip-service`: Quản lý chuyến đi (booking)
  - `driver-service`: Quản lý tài xế & vị trí địa lý
  - `payment-service`: Xử lý thanh toán

- **3 Module (Bài Tập Lớn)**:
  - **Module D**: Observability (Logs, Metrics, Traces)
  - **Module E**: Deployment & Infrastructure as Code (Terraform)
  - (Các module khác)

### Kiến Trúc Tổng Quát

```
┌─────────────────────────────────────────────────────────────┐
│                     Client (Web/Mobile)                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
    ┌─────────────┐  ┌─────────────┐  ┌──────────────┐
    │ User Service│  │ Trip Service│  │Driver Service│
    │  (Port 3000)│  │  (Port 3003)│  │ (Port 8000)  │
    └─────────────┘  └─────────────┘  └──────────────┘
         │                 │                 │
         └─────────────────┼─────────────────┘
                           │
                    ┌──────▼──────┐
                    │Payment Service
                    │  (Port 3004)
                    └──────────────┘
```

---

## 🚗 Trip Service - Phân Tích Chi Tiết

### Vị Trí
`services/trip-service/`

### Mục Tiêu Chính
Quản lý toàn vòng đời của một chuyến đi:
- Tạo booking mới
- Tìm driver gần nhất
- Ước tính giá cước
- Xử lý thanh toán
- Cập nhật trạng thái chuyến

### Cấu Trúc File

```
trip-service/
├── src/
│   ├── app.js                      # Express app entry point
│   ├── db.js                       # PostgreSQL connection
│   ├── controllers/
│   │   └── trip.controller.js      # Business logic
│   ├── models/
│   │   └── trip.model.js           # Database queries
│   ├── routes/
│   │   └── trips.js                # REST endpoints
│   ├── middleware/
│   │   └── auth.js                 # JWT verification
│   ├── services/
│   │   ├── userService.js          # Call user-service
│   │   ├── driverService.js        # Call driver-service
│   │   └── paymentService.js       # Call payment-service
│   └── observability/
│       ├── plugin.js               # Request logging middleware
│       ├── metrics.js              # EMF metrics recording
│       └── tracing.js              # OpenTelemetry init
├── tripsdb.sql                     # Database schema
├── package.json                    # Dependencies
└── Dockerfile                      # Container image
```

### REST Endpoints

| Method | Path | Mô Tả | Auth |
|--------|------|-------|------|
| `POST` | `/trips` | Tạo chuyến mới | ✅ Required |
| `GET` | `/trips/:id` | Lấy chi tiết chuyến | ✅ Required |
| `POST` | `/trips/:id/complete` | Hoàn tất chuyến | ✅ Required |
| `POST` | `/trips/:id/cancel` | Huỷ chuyến | ✅ Required |

### Luồng Tạo Chuyến (POST /trips)

```
1. Middleware verifyToken
   └─> Nếu không có token → tạo fake user (dùng cho dev)

2. Controller createTripHandler
   ├─> Resolve passenger_id
   ├─> Parse tọa độ origin/destination
   ├─> Gọi verifyUser (user-service) → xác thực người dùng
   ├─> Gọi findNearbyDriver (driver-service) → tìm driver
   ├─> Gọi estimatePrice (payment-service) → ước tính giá
   ├─> Gọi createTrip (DB) → lưu chuyến
   ├─> Ghi metrics (EMF)
   └─> Trả kết quả: { trip, driver, price }

3. Error Handling
   ├─> verifyUser lỗi? → WARN, tiếp tục (fallback)
   ├─> findNearbyDriver lỗi? → Dùng fallback driver
   ├─> estimatePrice lỗi? → Dùng fallback price (10000)
   ├─> createTrip lỗi? → Tạo trip in-memory (RỦI RO!)
   └─> chargeTrip lỗi (khi complete)? → WARN, tiếp tục
```

### Database Schema (PostgreSQL)

```sql
CREATE TABLE trips (
  id SERIAL PRIMARY KEY,
  passenger_id INT NOT NULL,
  driver_id INT,
  status VARCHAR(20) DEFAULT 'searching',
  pickup_lat FLOAT,
  pickup_lng FLOAT,
  dropoff_lat FLOAT,
  dropoff_lng FLOAT,
  price_estimate FLOAT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Những Vấn Đề Hiện Tại

| Vấn Đề | Mức Độ | Mô Tả |
|--------|--------|-------|
| Endpoint gọi driver-service sai | 🔴 Cấp 1 | Gọi `/drivers/search` nhưng driver-service có `/drivers?near=...` |
| Status mặc định sai | 🔴 Cấp 1 | Code insert `'accepted'` nhưng nên là `'created'` hoặc `'searching'` |
| Thiếu validation input | 🔴 Cấp 1 | Không validate latitude, longitude, userId |
| Fake user không bảo mật | 🟠 Cấp 2 | Tạo user giả mà không check NODE_ENV |
| HTTP calls chưa có timeout | 🟠 Cấp 2 | axios gọi tới services khác mà chưa set timeout |
| In-memory fallback nguy hiểm | 🟠 Cấp 2 | Khi DB lỗi, tạo trip in-memory (không persist) |
| Thiếu DELETE endpoint | 🟡 Cấp 3 | Chỉ có complete/cancel, không có hard delete |
| Chưa kiểm tra status transition | 🟡 Cấp 3 | Có thể complete trip đã cancelled |

### Kết Luận Trip Service
- **Status**: Đã hoàn thành 60% chức năng cốt lõi
- **Recommendation**: Fix 4 vấn đề cấp 1 trước khi deploy production

---

## 📊 Module D - Observability

### Mục Tiêu
Xây dựng khả năng **giám sát, cảnh báo và tự chẩn đoán** hệ thống UIT-Go bằng:
- Định nghĩa SLO/SLI (mục tiêu dịch vụ)
- Ghi logs, metrics, traces
- Dashboard & Alarms
- Runbooks xử lý sự cố
- Synthetic tests

### SLOs & SLIs Định Nghĩa

#### 1. Booking Success Rate (Trip Service)
- **SLI Name**: BookingSuccessRate
- **Description**: Tỷ lệ booking thành công (state = CONFIRMED trong ≤ 30s)
- **Window**: Rolling 30 days
- **SLO**: ≥ 99.90%
- **Error Budget**: 43.2 phút/tháng
- **Metric**: BookingSuccessCount / BookingAttemptCount

#### 2. Match Latency P95 (Driver Service)
- **SLI Name**: MatchLatencyP95
- **Description**: P95 latency của API tìm driver
- **Window**: Rolling 7 days
- **SLO**: < 200 ms
- **Metric**: p95(MatchLatencyMs)

#### 3. Payment Success Rate (Payment Service)
- **SLI Name**: PaymentSuccessRate
- **Description**: Tỷ lệ payment confirmation thành công
- **Window**: Rolling 30 days
- **SLO**: ≥ 99.95%
- **Error Budget**: 21.6 phút/tháng
- **Metric**: PaymentSuccessCount / PaymentAttemptCount

#### 4. Login Success Rate (User Service)
- **SLI Name**: LoginSuccessRate
- **Description**: Tỷ lệ đăng nhập thành công
- **Window**: Rolling 7 days
- **SLO**: ≥ 99.9%
- **Metric**: LoginSuccessCount / LoginAttemptCount

### Metrics Namespace: `UITGo/SLI`

```
Payment Service:
├─ PaymentAttemptCount (Count)
├─ PaymentSuccessCount (Count)
└─ PaymentDurationMs (Milliseconds)

Trip Service:
├─ BookingAttemptCount (Count)
├─ BookingSuccessCount (Count)
├─ BookingDurationMs (Milliseconds)
├─ MatchLatencyMs (Milliseconds)
├─ MatchAttemptCount (Count)
└─ MatchSuccessCount (Count)

User Service:
├─ LoginAttemptCount (Count)
├─ LoginSuccessCount (Count)
└─ LoginDurationMs (Milliseconds)
```

### Instrumentation Stack

| Layer | Công Nghệ | Mục Đích |
|-------|-----------|---------|
| **Metrics** | aws-embedded-metrics (EMF) | CloudWatch custom metrics |
| **Logs** | Structured JSON + requestId | Correlation & debugging |
| **Traces** | OpenTelemetry SDK (stub) | X-Ray integration (optional) |
| **HTTP Logger** | Express middleware | Request/response timing |

### CloudWatch Dashboard

**Dashboard Name**: `UITGo-SLO-Dashboard`

**Widgets**:
1. **Payment Success Rate** - Biểu đồ tỷ lệ % (mục tiêu 99.95%)
2. **Match API p95 Latency** - Biểu đồ độ trễ (mục tiêu < 200ms)
3. **Booking Success Rate** - Biểu đồ tỷ lệ % (mục tiêu 99.90%)
4. **Auth Success Rate** - Biểu đồ tỷ lệ % (mục tiêu 99.9%)
5. **Error Budget Widget** - Ghi chú về ngân sách lỗi

### CloudWatch Alarms

#### Payment Success Rate Alarm
- **Threshold**: 0.9995 (99.95%)
- **Evaluation**: 1 minute (rolling)
- **Action**: Gửi SNS alert
- **Trigger Condition**: `PaymentSuccessCount / PaymentAttemptCount < 0.9995`

#### Match p95 Latency Alarm
- **Threshold**: 200 ms
- **Evaluation**: 1 minute (rolling)
- **Metric**: p95 của MatchLatencyMs
- **Action**: Gửi SNS alert

### Runbook: Payment SLO Breach

**File**: `runbooks/payment_slo_breach.md`

**Triệu Chứng**:
- CloudWatch alarm PaymentSuccessRate firing
- Dashboard báo tỷ lệ < 99.95%

**Quick Checks (5 phút đầu)**:
1. Mở Dashboard xem thời gian lỗi bắt đầu
2. Kiểm tra CloudWatch Logs `/uitgo/payment-service` tìm `on_error` messages
3. Kiểm tra X-Ray traces tìm request error/slow
4. Chạy synthetic test kiểm tra reproducible
5. Kiểm tra dependencies (payment gateway, DB)

**Likely Causes**:
- External gateway (Stripe, Momo) partial outage
- Recent deployment có bug
- Resource exhaustion (DB connections)
- Network latency increase

**Mitigations** (Priority):
1. Nếu gateway lỗi: check status; nếu widespread → open ticket
2. Nếu deployment mới: rollback ngay
3. Tăng retry/backoff temporary
4. Scale up replicas
5. Kiểm tra DB: slow queries, connection pool

**Escalation**:
- Nếu không fix được trong 15 phút: escalate tới Platform Lead

### Trade-offs Analysis

| Pillar | Ưu Điểm | Nhược Điểm | Sử Dụng Khi |
|--------|---------|-----------|-----------|
| **Metrics** | Lightweight, low-cost, nhanh | Thiếu context | Alerting, SLO |
| **Traces** | Causal path, per-span timing | Chi phí cao, sampling phức tạp | Triage, debugging |
| **Logs** | Full context, forensic | High volume, cost cao | Deep debugging |

**Recommendation**: Metrics (alerting) → Traces (triage) → Logs (root-cause)

### Synthetic Tests

**Payment Test Script** (`scripts/synthetic-payment-test.ps1`)

```powershell
# Chạy 100 requests, interval 0.1s
.\synthetic-payment-test.ps1 -Count 100 -IntervalSeconds 0.1
```

**Kỳ Vọng Output**:
```
=== Synthetic Test Summary ===
Total requests: 100
Success: 100, Fail: 0, SuccessRate: 100%
Avg Duration (ms): 150.5
p50 Duration (ms): 1
p95 Duration (ms): 250
```

**Booking Test Script** (`scripts/synthetic-booking-test.ps1`)

```powershell
# Chạy 50 requests, interval 0.2s
.\synthetic-booking-test.ps1 -Count 50 -IntervalSeconds 0.2
```

### Module D Checklist

- ✅ SLO/SLI Định Nghĩa (4 flows)
- ✅ Instrumentation (EMF metrics, structured logs)
- ✅ CloudWatch Log Groups (3)
- ✅ CloudWatch Dashboard (5 widgets)
- ✅ CloudWatch Alarms (2)
- ✅ SNS Topic (alert notification)
- ✅ Runbooks (payment SLO breach)
- ✅ Synthetic Tests (payment, booking)
- ✅ Trade-offs Documentation

---

## 🚀 Module E - Deployment & IaC

### Mục Tiêu
Xây dựng **Infrastructure as Code** (IaC) để tự động hóa deployment hệ thống UIT-Go lên cloud.

### Công Nghệ Sử Dụng
- **IaC Tool**: Terraform
- **Cloud Platform**: Microsoft Azure (Azure Container Instances, ACR)
- **Container**: Docker

### Cấu Trúc Terraform

```
terraform/
├── envs/
│   └── dev/
│       ├── main.tf                 # Main configuration
│       ├── variables.tf            # Input variables
│       └── terraform.tfvars        # Variable values (optional)
└── modules/
    └── service_container/
        ├── main.tf                 # Container Group definition
        ├── outputs.tf              # Output values
        └── variables.tf            # Input variables
```

### Azure Resources Được Tạo

#### 1. Container Registry (ACR)
- **Name**: `uitgoacrdev.azurecr.io`
- **Purpose**: Lưu trữ Docker images của các services

#### 2. Container Groups (ACI)
Mỗi service được deploy như một Azure Container Instance:

- **user-service-cg**
  - Image: `uitgoacrdev.azurecr.io/user-service:latest`
  - Port: 3000
  - CPU: 0.5 cores
  - Memory: 1.0 GB

- **trip-service-cg**
  - Image: `uitgoacrdev.azurecr.io/trip-service:latest`
  - Port: 3000
  - CPU: 0.5 cores
  - Memory: 1.0 GB

- **driver-service-cg**
  - Image: `uitgoacrdev.azurecr.io/driver-service:latest`
  - Port: 8000
  - CPU: 0.5 cores
  - Memory: 1.0 GB

- **payment-service-cg**
  - Image: `uitgoacrdev.azurecr.io/payment-service:latest`
  - Port: 3004
  - CPU: 0.5 cores
  - Memory: 1.0 GB

#### 3. Resource Group
- **Name**: `uit-go-dev-rg` (configurable)
- **Location**: `eastus` (configurable)
- **Purpose**: Container cho tất cả resources

#### 4. Virtual Network (optional)
- **Name**: `uit-go-vnet`
- **Subnet**: `uit-go-subnet`
- **Purpose**: Network communication giữa services

### Terraform Variables (variables.tf)

```hcl
variable "resource_group_name" {
  default = "uit-go-dev-rg"
}

variable "location" {
  default = "eastus"
}

variable "subscription_id" {
  # Azure subscription ID
}

variable "acr_admin_username" {
  # ACR admin username for authentication
}

variable "acr_admin_password" {
  sensitive = true
  # ACR admin password
}

variable "environment" {
  default = "dev"
}
```

### Module: service_container

**Input Variables**:
```hcl
variable "service_name" {}        # e.g., "user-service"
variable "image" {}               # e.g., "ausgoacrdev.azurecr.io/user-service:latest"
variable "port" {}                # e.g., 3000
variable "resource_group_name" {} # Azure RG
variable "location" {}            # Azure location
variable "tags" {}                # Terraform tags
```

**Tạo Azure Container Group**:
```hcl
resource "azurerm_container_group" "this" {
  name                = "${var.service_name}-cg"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "${var.service_name}-dev-..."
  restart_policy      = "Always"

  container {
    name   = var.service_name
    image  = var.image
    cpu    = 0.5
    memory = 1.0
    ports {
      port     = var.port
      protocol = "TCP"
    }
  }
  
  tags = var.tags
}
```

**Output**:
```hcl
output "fqdn" {
  value = azurerm_container_group.this.fqdn
}

output "ip_address" {
  value = azurerm_container_group.this.ip_address
}
```

### Docker Images & Registry

#### Dockerfile (Mỗi Service)
```dockerfile
# Ví dụ: services/trip-service/Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY src ./src
EXPOSE 3000
CMD ["npm", "start"]
```

#### Build & Push tới ACR
```bash
# Build image
docker build -t uitgoacrdev.azurecr.io/trip-service:latest .

# Login tới ACR
az acr login --name uitgoacrdev

# Push image
docker push uitgoacrdev.azurecr.io/trip-service:latest
```

### Environment Tiers

#### Dev Environment (`envs/dev/`)
```hcl
locals {
  common_tags = {
    Project = "UIT-Go"
    Env     = "dev"
    Owner   = "Group"
  }
}
```

Resources:
- Container Group cho mỗi service (public IP, DNS label)
- Low resources: 0.5 CPU, 1GB memory (cost-optimized)
- Log Analytics (optional, cho CloudWatch integration)

#### Staging/Prod (có thể thêm)
- `envs/staging/` hoặc `envs/prod/`
- Với tài nguyên cao hơn, auto-scaling, private networking

### Deployment Workflow

```
1. Push code tới GitHub
   └─> Trigger CI/CD pipeline

2. Build Docker images
   ├─> user-service:latest
   ├─> trip-service:latest
   ├─> driver-service:latest
   └─> payment-service:latest

3. Push images tới ACR
   └─> ausgoacrdev.azurecr.io/...

4. Run Terraform
   ├─> terraform init
   ├─> terraform plan
   ├─> terraform apply
   └─> Provision Azure Container Instances

5. Services Running
   ├─> user-service.dev-....eastus.azurecontainers.io:3000
   ├─> trip-service.dev-....eastus.azurecontainers.io:3000
   ├─> driver-service.dev-....eastus.azurecontainers.io:8000
   └─> payment-service.dev-....eastus.azurecontainers.io:3004

6. CloudWatch Integration (Module D)
   ├─> EMF metrics → CloudWatch custom metrics
   ├─> Logs → CloudWatch Logs
   └─> Dashboard + Alarms active
```

### Security Best Practices

| Thực Hành | Mô Tả |
|-----------|-------|
| **ACR Authentication** | Sử dụng managed identity hoặc service principal |
| **Environment Variables** | Lưu secrets (DB password, API keys) trong Azure Key Vault |
| **Network Security** | Giới hạn ACR/ACI access qua firewall rules |
| **RBAC** | Phân quyền IAM cho developers & CI/CD pipelines |
| **Image Scanning** | Quét vulnerabilities trong ACR images |
| **Container Policy** | Enforce pod security policies (nếu dùng Kubernetes) |

### Terraform Best Practices

```hcl
# 1. Use remote state (Azure Storage Account)
terraform {
  backend "azurerm" {
    resource_group_name  = "tf-state-rg"
    storage_account_name = "tfstatesa"
    container_name       = "tfstate"
    key                  = "dev.tfstate"
  }
}

# 2. Use variables.tfvars (gitignore this file)
# terraform.tfvars
resource_group_name = "uit-go-prod-rg"
location            = "eastus2"
subscription_id     = "xxxx-xxxx-xxxx"

# 3. Use semantic versioning for modules
module "user_service" {
  source = "../../modules/service_container?ref=v1.0.0"
  ...
}

# 4. Validate & format
terraform fmt -recursive  # Format all .tf files
terraform validate       # Check syntax
```

### Module E Checklist

- ✅ Terraform configuration (dev environment)
- ✅ Service container module (reusable)
- ✅ Azure Container Registry setup
- ✅ Azure Container Instances for each service
- ✅ Docker images & Dockerfiles
- ✅ Resource tagging & organization
- ✅ Environment-specific configs
- ✅ Security considerations
- ✅ Cost optimization (0.5 CPU, 1GB RAM)
- ⚠️ Remote state management (terraform.tfstate tracking)
- ⚠️ CI/CD pipeline integration (GitHub Actions/Azure DevOps)

---

## 🧪 Hướng Dẫn Test

### Test Trip Service Locally

#### 1. Chuẩn Bị
```bash
cd services/trip-service
npm install
```

#### 2. Chạy Service
```bash
npm run start
# Output: "TripService running on port 3003"
```

#### 3. Test Endpoint POST /trips
```bash
curl -X POST http://localhost:3003/trips \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"lat": 10.762622, "lng": 106.660172},
    "destination": {"lat": 10.775, "lng": 106.700},
    "userId": 1
  }'
```

**Kỳ Vọng Response**:
```json
{
  "trip": {
    "id": 1,
    "passenger_id": 1,
    "driver_id": null,
    "pickup_lat": 10.762622,
    "pickup_lng": 106.660172,
    "dropoff_lat": 10.775,
    "dropoff_lng": 106.700,
    "price_estimate": 10000,
    "status": "accepted"
  },
  "driver": {"id": null, "distance": 5},
  "price": 10000
}
```

### Test Module D - Synthetic Tests

#### 1. Payment Service Test
```powershell
cd scripts
.\synthetic-payment-test.ps1 -Count 100 -IntervalSeconds 0.1
```

**Kỳ Vọng**:
- Success Rate: ≥ 99% (để pass SLO 99.95%)
- p95 Duration: < 200ms (Match SLO)
- CSV output: `synthetic-payment-results-<timestamp>.csv`

#### 2. Check EMF Logs
```bash
# Kiểm tra stdout từ payment-service
# Bạn sẽ thấy EMF JSON lines:
{
  "_aws": {...},
  "Service": "payment-service",
  "success": true,
  "PaymentSuccessCount": 1,
  "PaymentDurationMs": 150
}
```

### Test Module E - Terraform Deployment

#### 1. Chuẩn Bị Azure
```bash
az login
az account show  # Kiểm tra subscription
az group list    # Danh sách resource groups
```

#### 2. Terraform Plan
```bash
cd terraform/envs/dev
terraform init
terraform plan -out=tfplan
```

**Kỳ Vọng**: Thấy 4 Container Groups sẽ được tạo

#### 3. Terraform Apply
```bash
terraform apply tfplan
```

**Kỳ Vọng**: Tất cả 4 services chạy trên ACI

#### 4. Verify Deployment
```bash
# Lấy FQDNs
terraform output

# Test service via FQDN
curl http://user-service-dev-....eastus.azurecontainers.io:3000/healthz
```

---

## 🎯 Kết Luận & Đề Xuất

### Trip Service - Đánh Giá
| Tiêu Chí | Điểm | Nhận Xét |
|----------|------|---------|
| CRUD cơ bản | 7/10 | Có tạo/lấy/cập nhật, thiếu delete |
| Tương tác services | 5/10 | Endpoint sai (driver-service), HTTP chưa robust |
| Persist dữ liệu | 6/10 | Có DB nhưng fallback in-memory không tốt |
| Xác thực & bảo mật | 4/10 | Fake user nguy hiểm, thiếu validation |
| Error handling | 7/10 | Fallback tốt nhưng dữ liệu inconsistent |
| Observability | 8/10 | Metrics & logging tốt |
| **Tổng** | **6.2/10** | Làm được nửa chừng, cần fix vấn đề cấp 1 |

### Cần Fix (Priority)

**Cấp 1 - Bắt Buộc**:
- [ ] Sửa endpoint driver-service từ `/drivers/search` → `/drivers?near=...`
- [ ] Sửa status mặc định từ `accepted` → `created`
- [ ] Thêm validation input (latitude, longitude, userId)
- [ ] Disable fake user khi production (NODE_ENV check)

**Cấp 2 - Nên Làm**:
- [ ] Thêm timeout & retry cho HTTP calls
- [ ] Thêm `GET /trips?userId=...` để list trips
- [ ] Kiểm tra status transition
- [ ] Thay in-memory fallback bằng error 503

**Cấp 3 - Tối Ưu**:
- [ ] Thêm DELETE endpoint
- [ ] Saga pattern cho distributed transactions
- [ ] Unit tests
- [ ] Structured logger (pino)

### Module D - Đánh Giá
✅ **Hoàn thành**: SLO/SLI, instrumentation, dashboard, alarms, runbooks, synthetic tests  
✅ **Sẵn sàng production**: Terraform starter + EMF metrics + structured logs  
⚠️ **Cần cải tiến**: Bật full OpenTelemetry → X-Ray, thêm runbooks cho Booking/Auth

### Module E - Đánh Giá
✅ **Hoàn thành**: Terraform config, Azure Container Instances, module reusable  
✅ **Sẵn sàng production**: Docker images, ACR, environment tagging  
⚠️ **Cần cải tiến**: Remote state, CI/CD pipeline, auto-scaling, networking

### Các Bước Tiếp Theo
1. **Fix vấn đề cấp 1 của trip-service**
2. **Chạy synthetic tests để validate Module D**
3. **Deploy lên Azure dùng Terraform (Module E)**
4. **Monitor CloudWatch dashboard & alarms**
5. **Expand runbooks cho các flows khác**
6. **Implement full OpenTelemetry tracing**

---

**Tài liệu này có thể chia sẻ, in, hoặc chuyển đổi sang PDF/ePub**

**Phiên bản**: 1.0 | **Cập nhật**: 10/12/2025
