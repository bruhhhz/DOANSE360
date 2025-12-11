# Presentation Script — Module D (Observability) & Module E (Automation & FinOps)

Phiên bản: 1.0
Cập nhật: 11/12/2025

---

Mục đích file: tài liệu kịch bản đọc hiểu và thuyết trình dành cho người mới bắt đầu. Nội dung có thể đọc trực tiếp khi thuyết trình hoặc dùng làm tham chiếu.

Cách dùng:
- Mỗi phần tương ứng 1 slide.
- Đọc phần "Script (dành cho người thuyết trình)" khi thuyết trình.
- Các mục "Giải thích thuật ngữ" giúp giải thích nhanh các từ tiếng Anh.

---

## Slide 1 — Tiêu đề

Script (dành cho người thuyết trình):
"Kính chào thầy/các bạn, hôm nay em sẽ trình bày hai module: Module D — Observability và Module E — Automation & Cost Optimization (FinOps). Mục tiêu là trình bày thiết kế để hệ thống có thể tự chẩn đoán và đồng thời tối ưu chi phí vận hành."

Giải thích thuật ngữ:
- Observability: khả năng quan sát trạng thái hệ thống từ bên ngoài thông qua logs, metrics, traces.
- FinOps: kết hợp Finance + DevOps; quản lý chi phí đám mây bằng quy trình và công cụ.

---

## Slide 2 — Mục tiêu tổng quát

Script:
"Module D tập trung vào việc cung cấp thông tin đủ sâu để 'tự chẩn đoán' sự cố — tức là không chỉ thu thập logs/metrics mà còn liên kết được tới trải nghiệm người dùng và mục tiêu kinh doanh. Module E tập trung xây dựng nền tảng tự phục vụ cho developer và cơ chế quản lý chi phí (FinOps)."

Key points:
- Observability giúp giảm thời gian tìm nguyên nhân (MTTR).
- FinOps giúp kiểm soát ngân sách và đưa ra quyết định trade-off rõ ràng giữa chi phí và hiệu năng.

---

# MODULE D — Observability

## Slide 3 — Vì sao observability quan trọng

Script:
"Observability giúp ta trả lời 3 câu hỏi: (1) Hệ thống đang làm gì? (2) Tại sao nó làm vậy? (3) Điều đó ảnh hưởng thế nào tới người dùng. Mục tiêu cuối cùng là liên kết SLO/SLI với trải nghiệm người dùng."

Giải thích:
- SLO (Service Level Objective): mục tiêu chất lượng dịch vụ (ví dụ: 99.9%).
- SLI (Service Level Indicator): chỉ số đo thực tế để đánh giá SLO (ví dụ: tỷ lệ booking thành công).
- Error Budget: khoảng chấp nhận lỗi = 1 - SLO (thời gian được phép hệ thống “không đạt” mục tiêu).

---

## Slide 4 — Định nghĩa SLOs & SLIs (thực tế cho UIT-Go)

Script (nói chậm, dùng ví dụ):
"Ví dụ quan trọng: Booking Success Rate — SLI là tỷ lệ booking thành công (state = CONFIRMED trong ≤ 30s) với SLO ≥ 99.90%. Error budget tương ứng khoảng 43.2 phút/tháng. Match Latency P95 (p95 là phân vị 95) cho API tìm tài xế đặt SLO < 200 ms."

Giải thích thuật ngữ:
- p95 (95th percentile): 95% các yêu cầu có độ trễ <= giá trị này — dùng để đánh giá độ trễ thực tế, không phải trung bình.
- Window: khoảng thời gian đánh giá (ví dụ rolling 30 days).

---

## Slide 5 — Nền tảng quan sát (stack)

Script:
"Kiến trúc instrumentation gồm: Metrics (số liệu) xuất ra CloudWatch qua aws-embedded-metrics; Logs theo dạng JSON có `requestId` để truy vết; Traces theo OpenTelemetry và tích hợp AWS X-Ray để thấy hành trình request; HTTP logger ở tầng-framework để đo latency."

Giải thích thuật ngữ:
- Metric: số liệu định lượng (counts, durations).
- Log: dòng sự kiện mô tả chi tiết tình huống.
- Trace: chuỗi sự kiện (spans) thể hiện đường đi của request qua nhiều service.
- OpenTelemetry: bộ tiêu chuẩn/SDK cho instrumentation (metrics, traces, logs).
- AWS X-Ray: dịch vụ trace của AWS.

---

## Slide 6 — Dashboard & Alarms thông minh

Script:
"Tạo một dashboard `UITGo-SLO-Dashboard` hiển thị các SLO chính: Payment Success Rate, Booking Success Rate, Match p95, Auth rate, và Error Budget. Cấu hình Alarms (cảnh báo) dựa trên metric math (ví dụ tỷ lệ success = successCount/attemptCount). Khi cảnh báo bật, gửi đến SNS và kích hoạt runbook."

Giải thích:
- Dashboard: giao diện trực quan show metrics.
- Alarm: cảnh báo khi metric vượt ngưỡng.
- SNS (Simple Notification Service): hệ thống gửi thông báo (email/SMS/webhook).

---

## Slide 7 — Runbook: xử lý Payment SLO breach

Script (đọc các bước nhanh):
"Runbook là tài liệu có từng bước xử lý. Ví dụ Payment SLO breach: quick checks (xem dashboard, log group `/uitgo/payment-service`, traces X-Ray), chạy synthetic test, kiểm tra gateway bên ngoài, rollback nếu deployment mới, scale up hoặc tăng retry tạm thời."

Ghi chú người thuyết trình:
- Làm nổi bật luồng quyết định: detect → triage → mitigate → escalate.

Giải thích:
- Runbook: hướng dẫn thao tác cụ thể khi cảnh báo xuất hiện (checklist).

---

## Slide 8 — Synthetic tests & validation

Script:
"Synthetic tests là các kịch bản test tự động (script) mô phỏng hành vi user để kiểm tra SLOs trước sau deploy. Ví dụ `scripts/synthetic-payment-test.ps1` có thể gửi 100 request và report success rate, p95."

Demo quick commands (PowerShell):
```powershell
cd scripts
.\synthetic-payment-test.ps1 -Count 100 -IntervalSeconds 0.1
.\synthetic-booking-test.ps1 -Count 50 -IntervalSeconds 0.2
```

Giải thích:
- Synthetic test: test giả lập người dùng, khác với unit/integration tests.

---

## Slide 9 — Trade-offs giữa Logs / Metrics / Traces

Script:
"Metrics cheap và tốt cho alerting; Traces tốn hơn nhưng cung cấp causal path để triage; Logs cung cấp context đầy đủ nhưng volume lớn. Recommendation: metrics → traces → logs."

Giải thích:
- Sampling: chỉ thu một phần traces để giảm chi phí, vẫn giữ đủ mẫu cho triage.

---

# MODULE E — Automation & Cost Optimization (FinOps)

## Slide 10 — Mục tiêu Module E

Script:
"Mục tiêu là xây dựng nền tảng tự phục vụ (self-service) cho dev và quy trình FinOps để tối ưu chi phí chủ động: gắn thẻ tài nguyên, báo cáo chi phí, cảnh báo ngân sách, và thực thi phương án tối ưu (ví dụ đổi sang Spot, Graviton)."

Giải thích:
- Self-service platform: dev có thể tự deploy/rollback resources an toàn mà không cần thao tác thủ công nhiều.
- Graviton: gia đình CPU của AWS (ARM) tiết kiệm chi phí/hiệu năng tốt cho một số workloads.

---

## Slide 11 — CI/CD & Terraform modules (self-service)

Script:
"Thiết kế pipeline GitHub Actions: build → test → build image → push ACR/registry → terraform plan/apply (được kiểm duyệt). Terraform được chia thành modules (ví dụ `service_container`) để dev chỉ cần cung cấp `service_name`, `image`, `port` và chạy deploy."

Demo commands (PowerShell & Terraform):
```powershell
# Build & push (ví dụ Azure ACR)
docker build -t uitgoacrdev.azurecr.io/trip-service:latest services/trip-service
az acr login --name uitgoacrdev
docker push uitgoacrdev.azurecr.io/trip-service:latest

# Terraform
cd terraform/envs/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Giải thích:
- CI/CD: Continuous Integration / Continuous Deployment — tự động build, test, deploy.
- Module hóa Terraform: tái sử dụng, versioning, dễ maintain.

---

## Slide 12 — Quản lý chi phí: tagging, reporting, budgets

Script:
"Để phân bổ chi phí, bắt buộc 'tag' tài nguyên theo service/project/env/owner. Sử dụng AWS Cost Explorer (hoặc Azure Cost Management) để phân tích, và cấu hình AWS Budgets để gửi cảnh báo khi chi phí vượt ngưỡng."

Giải thích:
- Tagging: gắn metadata key/value (ví dụ `Project=UIT-Go`, `Service=trip-service`, `Env=dev`).
- Cost Explorer: công cụ báo cáo chi phí theo tag, service, thời gian.
- Budget: thiết lập ngưỡng chi tiêu để cảnh báo stakeholders.

---

## Slide 13 — Phương án tối ưu & phân tích trade-off

Script:
"Các phương án: (1) Spot Instances (rẻ nhưng có thể bị terminate), (2) Serverless (chi phí theo usage, không cần quản lý servers), (3) Graviton/ARM instances (chi phí/hiệu năng tốt cho workloads tương thích). Chọn phương án cần cân bằng availability, latency, operational complexity."

Ví dụ đo lường (mẫu):
"Áp dụng Graviton cho service A giảm 20% chi phí CPU; chuyển job batch sang Spot giảm 60% chi phí compute."

Giải thích:
- Spot Instances: instance giá rẻ nhưng không đảm bảo uptime; phù hợp cho batch/worker.
- Serverless: Lambda/FaaS — không phải giữ server; tốt cho traffic theo sự kiện.

---

## Slide 14 — Sản phẩm đầu ra (thực tế)

Script:
"Kết quả kỳ vọng: pipeline CI/CD sẵn sàng cho dev, Terraform moduleized để deploy service nhanh, báo cáo phân tích chi phí với đề xuất tối ưu có số liệu cụ thể."

Checklist ngắn:
- CI/CD: build, test, image, push, terraform plan/apply
- Terraform modules: reusable, versioned
- FinOps: tags, Cost Explorer reports, Budgets, optimisation report

---

## Slide 15 — Kịch bản demo ngắn (5 phút)

Script (bước từng bước):
"1) Chạy synthetic test kiểm tra SLO; 2) Kiểm tra dashboard SLO/Alarms; 3) Show terraform plan/apply (dev); 4) Mở báo cáo chi phí (Cost Explorer) và show tag allocation."

Lệnh mẫu (PowerShell):
```powershell
# 1) Synthetic payment test
cd scripts
.\synthetic-payment-test.ps1 -Count 100 -IntervalSeconds 0.1

# 2) Terraform plan/apply
cd terraform/envs/dev
terraform init
terraform plan -out=tfplan
# Nếu đã review
terraform apply tfplan

# 3) (AWS) show cost explorer: thao tác trên console (CLI có thể dùng aws ce)
# aws ce get-cost-and-usage --time-period Start=2025-11-01,End=2025-11-30 --granularity MONTHLY --metrics "BlendedCost"
```

---

## Slide 16 — Script nói (từng câu) — dành cho người mới

Mẹo đọc:
- Mở đầu 30s: nêu mục tiêu và kết luận mong muốn.
- Phần Observability: giải thích SLO/SLI bằng ví dụ cụ thể (booking/payment).
- Phần FinOps: trình bày pipeline và tối ưu chi phí với số liệu thực tế hoặc giả lập.

Kịch bản câu nói mẫu:
"Mục tiêu Module D là đảm bảo chúng ta biết ngay khi user trải nghiệm xấu và có khả năng theo dõi nguyên nhân nhanh nhất. Module E giúp dev tự deploy an toàn và giảm chi phí qua quy trình có kiểm soát." 

---

## Slide 17 — Câu hỏi Q&A mẫu & câu trả lời gợi ý

Q: "Tại sao cần cả metrics và traces?"
A: "Metrics nhanh, cheap, dùng để alert. Khi alert, mở trace để thấy con đường request qua các service (causal path) — trace giúp triage, logs giúp root-cause."

Q: "Làm thế nào để đặt SLO hợp lý?"
A: "Bắt đầu từ trải nghiệm người dùng: khảo sát chấp nhận lỗi (tolerance), sau đó thiết lập SLO và giám sát error budget. Điều chỉnh theo dữ liệu vận hành."

Q: "Có nên dùng Spot cho production?"
A: "Spot phù hợp cho job không yêu cầu high availability. Với frontend/critical services, dùng Spot cần cân nhắc kết hợp với autoscaling/replicas để giảm rủi ro." 

Q: "Module E repo của tôi đang dùng Azure, còn tài liệu dùng AWS — tôi nên chọn gì?"
A: "Nguyên tắc thiết kế giữ nguyên: tagging, remote state, moduleization, CI/CD; chỉ khác API/console cụ thể giữa AWS/Azure." 

---

## Slide 18 — Cheat-sheet thuật ngữ (tóm tắt)

- SLO: mục tiêu dịch vụ (ví dụ 99.9%)
- SLI: chỉ số đo (tỷ lệ success, p95 latency)
- Error Budget: thời gian được phép lỗi
- Metrics / Logs / Traces: ba nguồn dữ liệu observability
- EMF: aws-embedded-metrics (ghi metric cho CloudWatch)
- X-Ray: distributed tracing service của AWS
- ACR / ACI: Azure Container Registry / Azure Container Instance
- CI/CD: pipeline tự động build & deploy
- FinOps: quản lý chi phí cloud bằng quy trình

---

## Slide 19 — Những điểm cần chuẩn bị trước khi thuyết trình

- Chuẩn demo: môi trường dev đã deploy, synthetic scripts sẵn, Terraform plan có output FQDN.
- Chuẩn slide backup: runbook `runbooks/payment_slo_breach.md`, sample CloudWatch dashboard image, Cost Explorer screenshot.
- Chuẩn câu trả lời: số liệu SLO/SLI (ví dụ SLO=99.95% thì error budget ~21.6 phút/tháng).

---

## Slide 20 — Kết luận & Next Steps

Script ngắn:
"Tóm lại: Observability và FinOps phải đi cùng nhau — biết nhanh, sửa nhanh, và tối ưu chi phí. Next steps: hoàn thiện runbooks, bật full tracing cho critical flows, module hóa Terraform và triển khai CI/CD."

Lời kêu gọi hành động:
"Nếu thầy/các bạn muốn, em có thể tạo slide PPTX từ kịch bản này hoặc viết script demo chi tiết." 

---

# End of file
