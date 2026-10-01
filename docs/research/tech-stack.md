# Tech stack — dựng Reado bằng gì, và vì sao

| Field | Value |
|---|---|
| Status | Draft, mục 11 đã chốt 2026-09-17; Q-03 hybrid vá cùng ngày (v2.1). **Toàn bộ nội dung proxy (mục 6, 9, 10.1, …) là bia mộ từ 2026-10-01 — ADR-049 bỏ proxy, Q-03 đảo thành BYOK-only. Không viết lại, chỉ ghi chú này** |
| Created | 2026-09-08 |
| Last updated | 2026-10-01 (ghi chú ADR-049 — nội dung proxy phía dưới không còn hiệu lực) |
| Revision | v2.1 — Q-03 hybrid BYOK (proxy mặc định + agent OpenAI-compat trên máy). v2 = native iOS + local-first + proxy-only. v1 (PWA + BE đầy) nằm dưới dạng bia mộ ở mục 2.1. **v2.2 (ADR-049): proxy bỏ, BYOK-only — xem [decisions-log.md](docs/decisions-log.md)** |
| Related | [prd.md](docs/specs/prd.md), [CLAUDE.md](CLAUDE.md), [prompt-spec.md](docs/agent/prompt-spec.md), [vocabulary.md](docs/research/vocabulary.md), [review.md](docs/research/review.md) |
| Phạm vi | Trả lời câu hỏi: R1 dựng bằng ngôn ngữ nào, DB nào, chạy ở đâu — và những ràng buộc nào **buộc** ra lựa chọn đó thay vì để nó thành sở thích |

**Tài liệu này tự chứa.** Nó được viết để một session mới, không có bối cảnh gì về cuộc
thảo luận sinh ra nó, vẫn đọc và tiếp tục được.

> **Ranh giới.** Doc này dừng ở *chọn công nghệ và vì sao*. Nó **không** phải solution
> design doc: không có module boundary, không có thiết kế API, không có DDL đã dịch
> hết từng cột, không có ranh giới transaction. [PRD mục 13](docs/specs/prd.md#13-out-of-scope)
> xếp những thứ đó vào một doc riêng. Q-01 đến Q-03 **đã chốt** (mục 2); solution
> design viết được sau sync docs lần này.

## Điều hướng

- [1. Vì sao doc này tồn tại](#1-vì-sao-doc-này-tồn-tại)
- [2. Bốn quyết định đã chốt, và cái chúng kéo theo](#2-bốn-quyết-định-đã-chốt-và-cái-chúng-kéo-theo)
- [2.3 Bia mộ — Q-03 proxy-only](#23-bia-mộ--q-03-proxy-only-buổi-sáng-2026-09-17)
- [3. Ràng buộc 1 — FSRS binding lọc ngôn ngữ trước mọi sở thích](#3-ràng-buộc-1--fsrs-binding-lọc-ngôn-ngữ-trước-mọi-sở-thích)
- [4. Ràng buộc 2 — NFR-03 với local-first](#4-ràng-buộc-2--nfr-03-với-local-first)
- [5. Ràng buộc 3 — Gemini structured output không phải trục phân biệt](#5-ràng-buộc-3--gemini-structured-output-không-phải-trục-phân-biệt)
- [6. Chọn proxy](#6-chọn-proxy)
- [7. Chọn DB](#7-chọn-db)
- [8. Chọn client](#8-chọn-client)
- [9. Hosting](#9-hosting)
- [10. Bốn chỗ hở ánh xạ vào stack](#10-bốn-chỗ-hở-ánh-xạ-vào-stack)
- [11. Đã chốt và chưa chốt](#11-đã-chốt-và-chưa-chốt)
- [12. Cần áp dụng vào tài liệu nào](#12-cần-áp-dụng-vào-tài-liệu-nào)
- [13. Nguồn](#13-nguồn)

---

## 1. Vì sao doc này tồn tại

`AGENTS.md` mục 3 (nay gộp vào [CLAUDE.md](CLAUDE.md) §5, ADR-035) từng liệt Q-01, Q-02 và Q-03 là ba câu **chặn mọi
dòng code**. Chúng được trả lời lần đầu ngày 2026-09-08 (PWA + BE đầy + key sau BE),
rồi **đảo** ngày 2026-09-17 khi fen chọn native iOS.

Doc này tồn tại để stack là quyết định có ý thức: NG-09 vẫn cấm tự viết SRS, NFR-03
và NFR-07 vẫn ràng buộc kiến trúc, và mỗi lần đảo Q-01/Q-02/Q-03 làm sụp tiền đề của
các mục dưới — không được để session sau “phát hiện” điều đó ở tuần thứ ba của code.

---

## 2. Bốn quyết định đã chốt, và cái chúng kéo theo

| ID | Câu hỏi | Fen chốt | Ngày |
|---|---|---|---|
| **Q-01** | Platform | **Native iOS** (Swift / SwiftUI). R1 không ship Android, không ship PWA sản phẩm | 2026-09-17 |
| **Q-02** | Local hay cloud | **Local-first** — vocab, `cards`, `review_logs` trên máy (SQLite). Dashboard sản phẩm (kho từ, stats học) = **Later**; lúc đó mới sync | 2026-09-17 |
| **Q-03** | API key ở đâu | **Hybrid:** proxy Reado (key `.env` server) = mặc định; user thêm agent OpenAI-compat + key Keychain, chọn một cái active cho FR-02. ~~App không gọi provider thẳng~~ — bia mộ mục 2.3 | 2026-09-17 |
| **Q-12** | Learning steps trong ngày | **Tắt** | 2026-09-08 (giữ) |

Lý do Q-02 lần này: R1 cần NFR-03 gần như miễn phí và một FSRS duy nhất trên máy.
Dashboard / auth / author vẫn là hướng Later — cửa mở bằng `uuid` do client sinh, không
bằng cách dựng BE đầy ở tuần đầu.

### 2.1 Bia mộ — chốt 2026-09-08 đã đảo

| Quyết định chết | Thay bằng |
|---|---|
| ~~Q-01 = PWA mobile-first~~ | Native iOS |
| ~~Q-02 = BE đầy, dữ liệu server-side~~ | Local-first; BE đầy lùi lúc có dashboard |
| ~~FE sản phẩm = Vite + React + `vite-plugin-pwa`~~ | SwiftUI; `web/` chỉ còn prototype |
| ~~Đề xuất NFR-03 đường C (hoãn offline sang R2)~~ | Offline review **ở R1**, vì FSRS chạy trên máy |
| ~~BE TypeScript / Hono vì FE cũng là TS~~ | Client là Swift; proxy đề xuất Python |

Giữ nguyên chỗ này, đừng xoá: session đọc v1 hoặc lucy R-001 sẽ truy được chuỗi lý do.

### 2.2 Cái được giải ngay

**NFR-07 thoả theo nghĩa hybrid (v0.9).** Key sản phẩm Reado nằm `.env` proxy, không
đi vào app bundle. Key user (FR-21) nằm Keychain, không SQLite, không export, không
lên server Reado. Khi active là BYOK, network trace máy **có** lần gọi tới `base_url`
user khai — chấp nhận, không phải lộ key Reado.

**NFR-03 thoả bằng thiết kế ở R1.** Hàng đợi và FSRS sống trên SQLite; chỉ FR-02
(analysis) bắt buộc online.

**FR-11 có đường tới push thật.** APNs — không Web Push, không Add to Home Screen.

**Một implementation FSRS.** Chỉ `swift-fsrs` trên máy. Proxy **không** chạy scheduler.
Hai lịch lệch nhau là rủi ro **Later** (khi sync), không phải rủi ro R1.

**PRD mục 11 (cô lập AI provider).** Lớp đó là **adapter trên iOS**: `reado_proxy`
vs `openai_compat`. Đổi Gemini phía Reado = sửa proxy. Đổi provider phía user =
thêm hàng `analysis_agents`. SwiftUI không biết schema wire của Google hay OpenAI.

### 2.3 Bia mộ — Q-03 proxy-only (buổi sáng 2026-09-17)

| Quyết định chết | Thay bằng |
|---|---|
| ~~Q-03 = app không gọi Gemini thẳng; key chỉ `.env` proxy~~ | Hybrid: proxy mặc định + BYOK OpenAI-compat (FR-21) |
| ~~NFR-07 = không có API key nào trên máy người dùng~~ | Key **sản phẩm** không trên máy; key **user** ở Keychain |
| ~~PRD mục 11: proxy là lớp cô lập AI duy nhất~~ | Protocol adapter trên iOS; proxy là một implementation |

Giữ nguyên chỗ này: lucy R-010 và ADR native-local-proxy (máy có `.lucy/`) nói
proxy-only. Q-01 và Q-02 **không** đảo.

---

## 3. Ràng buộc 1 — FSRS binding lọc ngôn ngữ trước mọi sở thích

NG-09 cấm tự viết SRS algorithm. A-05 giả định dùng được thư viện có sẵn. Cộng lại:
**nơi chạy FSRS phải có library được maintain.** Ở R1 nơi đó là iPhone.

| Ngôn ngữ | Thư viện | Phiên bản thuật toán | Optimizer | Ghi chú |
|---|---|---|---|---|
| **Swift** | `swift-fsrs` (`open-spaced-repetition/swift-fsrs`) | **FSRS-6** (opt-in) | **Không** | Binding R1. Xem 3.1 |
| TypeScript | `ts-fsrs` | **FSRS-6** | Qua `@open-spaced-repetition/binding` | Tham chiếu field trong [review.md](docs/research/review.md); **không** chạy trên client R1 |
| Python | `py-fsrs` (`fsrs` trên PyPI) | **FSRS-6** | **Có, built-in** | Job optimizer R2 / Later — không nằm trên request |
| Rust | `fsrs-rs` | **FSRS-6** | Có | Bản Anki dùng |
| Java | `java-fsrs` | FSRS-6, 21 tham số | Không | Không còn ứng viên BE R1 |
| Go | `go-fsrs` | **FSRS-5** | Không | Vẫn loại (mục 3.3) |
| Kotlin | `FSRS-Kotlin` | FSRS-6 | Không | Android Later; chưa khảo sát kỹ |

### 3.1 Gotcha — `swift-fsrs` mặc định là FSRS-5

README: *A Swift implementation of FSRS-6.0 (FSRS-5.0 supported via 19-length `w`)*.
`FSRS(parameters: .init())` **không** phải FSRS-6. v5 dùng 19 trọng số; v6 dùng 21.
[review.md mục 9](docs/research/review.md#9-đã-chốt-và-chưa-chốt) đã chốt
`fsrs_params` đi kèm `fsrs_version` vì nâng thư viện mà không đổi mảng là silent
breakage.

R1 **phải** opt-in:

```swift
let fsrs = FSRS(parameters: .init(w: FSRSDefaults.defaultWv6))
```

Không có optimizer trên Swift. R1 dùng tham số mặc định (PRD mục 10) nên không chặn.
Optimizer R2 chạy lô bằng `py-fsrs` trên `review_logs` đã export — cùng quy tắc mục 6.3
v1: optimizer không ràng buộc ngôn ngữ request path.

### 3.2 Vì sao cột phiên bản vẫn quan trọng

FSRS-5 = 19 tham số, FSRS-6 = 21. `ts-fsrs` tự nhận 17/19/21 và migrate lên 21.
`swift-fsrs` phân phiên bản theo độ dài `w`; 17-length được treat như v5. Reado lưu
`fsrs_version` và **không** gọi constructor không tham số.

### 3.3 Go bị loại

`go-fsrs` là FSRS-5. Chọn nó khoá R1 vào 19 tham số. Không còn ứng viên client hay
proxy, nên hàng này chỉ để khỏi ai "phát hiện" Go ở session sau.

---

## 4. Ràng buộc 2 — NFR-03 với local-first

**NFR-03** đòi *"việc ôn tập phải dùng được khi không có mạng. Chỉ bước analysis mới
bắt buộc online."* Nó nằm trong R1 theo [PRD mục 10](docs/specs/prd.md#10-release-scope).

Với Q-02 = local-first, tiền đề cũ của v1 (mỗi lần chấm thẻ là một request) **không
còn**. [review.md mục 2.1](docs/research/review.md#21-fsrs-là-một-pure-function)
lại đúng nguyên văn: FSRS là pure function, client tự tính lịch, không hỏi ai.

### 4.1 R1 không cần ba đường A/B/C của v1

| Đường v1 | Còn việc không |
|---|---|
| A — nới NFR-03 (ôn cần mạng) | **Không chọn.** Trải nghiệm ôn trên tàu/máy bay đúng chỗ NFR-03 ra đời |
| B — cache + outbox + FSRS hai phía | **Không ở R1.** Không có replica server của `cards` |
| C — hoãn offline sang R2 | **Không chọn.** Hoãn là đề xuất khi data nằm trên server |

R1: ôn offline thật. Analysis fail rõ khi mất mạng — không giả offline.

### 4.2 Dual-FSRS là cảnh báo Later, không chặn R1

Khi dashboard web đọc cùng kho từ, sẽ có bản sao `cards` trên server. Lúc đó **không**
được chạy một FSRS thứ hai bằng ngôn ngữ BE rồi tin hai lịch trùng. Đường an toàn:
scheduler **chỉ** trên máy (hoặc chỉ một service, không cả hai), server lưu snapshot
đã tính. Chi tiết thuộc solution design lúc mở sync — ghi ở đây để khỏi chọn Java/TS
FSRS "cho tiện" ở R2.

Quy tắc:

> **R1: FSRS chỉ tồn tại trên iOS (`swift-fsrs` v6 opt-in).**
> **Later sync: không thêm implementation thứ hai trên đường request.**

---

## 5. Ràng buộc 3 — Gemini structured output không phải trục phân biệt

Gemini API hỗ trợ structured output với input ảnh trên SDK Python (`google-genai` +
Pydantic), TypeScript (Zod), và Java. [prompt-spec mục 4](docs/agent/prompt-spec.md#4-output-schema)
đòi `additionalProperties: false` ở mọi cấp — JSON Schema đầy đủ cover được.

Mọi ứng viên proxy đều làm được FR-02. Khác biệt là ergonomics. Swift gọi Gemini
thẳng bằng key **sản phẩm** nhúng app — **cấm bởi NFR-07**. Swift gọi
OpenAI-compat bằng **key user** (FR-21) thì **được**: đó là nhánh `openai_compat`
của adapter, không phải lộ key Reado.

Hợp đồng schema Zod dùng chung FE+BE **hết lý do**: FE là Swift. Schema sống ở
prompt-spec. Implement một lần trên **mỗi** adapter: Pydantic trên proxy (Gemini
native); JSON Schema / `json_object` + validate trên iOS cho nhánh OpenAI-compat.

---

## 6. Chọn proxy

Đây không phải "BE đầy". Proxy **không** giữ hàng đợi ôn, **không** chạy FSRS,
**không** là source of truth của vocab.

### 6.1 Trách nhiệm R1

| Có | Không |
|---|---|
| Nhận ảnh từ app, gọi Gemini structured output | Lưu `cards` / `review_logs` / kho từ |
| Xác minh `example` trong cùng request khi active = `reado_proxy` ([prompt-spec mục 6](docs/agent/prompt-spec.md#6-xác-minh-example); nhánh BYOK verify trên máy — mục 10.4) | Hàng đợi FR-11 |
| Ghi `analysis_events` (mục 10.1), kể cả `image_hash` làm idempotency key FR-02 | Auth / dashboard / multi-user |
| Trả item đã gắn `verified` / `suspect` / `unverified` | Key hay model id lộ về client |

### 6.2 Đề xuất — Python + `google-genai`

Ba lý do:

1. **Script A-01/A-02** nên là Python ngay cả khi chưa có app. Cùng SDK với proxy thì
   một lần gọi multimodal không phải viết hai lần.
2. **Optimizer R2** đã là `py-fsrs` chạy lô. Không bắt proxy phải là TypeScript để
   "một ngôn ngữ với FE" — FE là Swift.
3. Pydantic gần với output schema hơn `Map<String, Object>` của Java.

Framework cụ thể (FastAPI / Flask / …) **không load-bearing** ở mức này; chốt lúc
solution design. Phần yếu: fen nhanh hơn ở Java — một proxy vài endpoint thì khác
biệt tốc độ nhỏ hơn v1 khi BE phải mang cả FSRS.

### 6.3 Optimizer ở R2 không ràng buộc lựa chọn này

Giữ nguyên luận v1: optimizer không nằm trên đường request. Export `review_logs` từ
máy (FR-16 đã có JSON FSRS), chạy `py-fsrs`, ghi `fsrs_params` vào `settings` trên
máy.

---

## 7. Chọn DB

### 7.1 Tiền đề

Q-02 = local-first → engine R1 là **SQLite trên device**. DDL ở
[vocabulary.md mục 6.1](docs/research/vocabulary.md#61-năm-bảng) vẫn viết kiểu
Postgres như **hình dạng logic** (tên cột, nullability, ý nghĩa). Dialect thật nằm
ở đây và ở mục dialect của doc structure — **không** coi file Postgres là thứ sẽ
`CREATE` trên iPhone.

Postgres trở lại khi Later cần dashboard/sync. Lý do fen từng chọn BE đầy (dashboard,
auth) vẫn đúng ở chân trời đó; nó không biện minh cho một server DB ở R1.

### 7.2 Mapping đã chốt (2026-09-17)

| Câu AGENTS mục 5 | Trả lời |
|---|---|
| `uuid` lưu dạng gì | `TEXT`, chữ thường, có gạch nối. Không `BLOB` — FR-16 export phải đọc được bằng mắt |
| Timestamp lưu dạng gì, có giữ timezone không | `TEXT` ISO-8601 **luôn UTC, luôn hậu tố `Z`**. Không lưu giờ địa phương |
| `fsrs_params` lưu dạng gì | `TEXT` chứa JSON array, đi kèm `fsrs_version` đã có trong schema |

Partial index SQLite hỗ trợ. `jsonb` Postgres → `TEXT` JSON. Cột `timezone` IANA trên
`settings` vẫn bắt buộc — xem 7.4 / 10.2.

### 7.3 Timezone — không engine nào cứu

`timestamptz` hay `TEXT` ISO đều lưu **một thời điểm**, không lưu **múi giờ IANA**.
FR-11 và FR-14 cần *"hôm nay bắt đầu lúc 4 giờ sáng — theo giờ của ai?"*. Bảng
`settings` thiếu `timezone` bất kể SQLite hay Postgres.

---

## 8. Chọn client

### 8.1 SwiftUI trên iOS

R1 = một app iOS. `web/` (Vite + React) là **clickable prototype** theo
[journeys.md](docs/specs/journeys.md), không phải bề mặt sản phẩm, không
port sang SwiftUI từng component.

~~Vite + React + `vite-plugin-pwa` làm FE R1~~ — chết 2026-09-17. Lý do cũ (hệ sinh
thái crop/camera web) không còn thắng native `UIImagePicker` / `PhotosUI`.

### 8.2 Chụp ảnh — NFR-08

| Cách | Thao tác | Đánh đổi |
|---|---|---|
| Camera / picker hệ thống | Mở app → chạm → chụp hoặc chọn ảnh | Ít code, quen tay |
| Viewfinder custom trong app | Như trên, thêm xin quyền và khung ngắm riêng | Kiểm soát căn trang; nhiều fail path |

**Đề xuất R1: picker / camera hệ thống.** Nếu A-03 sai thì mới đáng dựng viewfinder.

Crop/xoay trên máy trước khi upload lên proxy: ảnh nhỏ hơn thì NFR-01 và NFR-02 tốt
hơn.

### 8.3 Push — APNs

FR-11 nhắc ôn hàng ngày đi qua **Apple Push Notification service**, kèm badge số đến
hạn (FR-14) nếu dùng được. Không thiết kế Web Push, không màn "Add to Home Screen".

Điều kiện: app có capability Push, proxy **không** bắt buộc gửi push — lịch ôn nằm
trên máy, nên reminder có thể là local notification. APNs hữu ích khi muốn nhắc lúc
app không mở; local notification đủ cho một người dùng nếu background delivery ổn.
Chốt cơ chế gửi lúc solution design; điều đã chốt ở đây: **không phải Web Push**.

### 8.4 Không service worker

Cache app shell là chuyện PWA. Native: binary trên máy; ôn không cần mạng; analysis
báo lỗi mạng rõ ràng.

---

## 9. Hosting

Yêu cầu, theo thứ tự cứng dần:

1. **Proxy phải hosted, không chạy local trên laptop.** Persona đọc sách giấy, chụp
   bằng điện thoại. Mỗi lần đọc phải bật laptop thì ma sát đủ giết M-07.
2. **HTTPS** — ATS trên iOS; không gửi ảnh tới HTTP thường.
3. Telemetry `analysis_events` trên proxy phải **không mất im lặng** — NFR-02/M-03/M-04
   đo từ đó. Backup DB app là file SQLite trên máy (NFR-06 + FR-16 export).
4. Chi phí một người dùng.

Hình dạng R1: một process nhỏ (Python) + storage tối thiểu cho `analysis_events`.
Không Postgres managed cho kho từ.

**Chưa chốt nhà cung cấp.** Hai tiêu chí lúc deploy: proxy **không cold start 30s**
(NFR-01), HTTPS mặc định.

---

## 10. Bốn chỗ hở ánh xạ vào stack

Bốn chỗ tìm ra 2026-09-08. Chúng không phải quyết định platform, nhưng chỉ giải khi
biết stack. Giữ; đổi chỗ chạy.

### 10.1 Telemetry — `analysis_events` trên proxy

Không lưu trang (v0.3) giết bảng `pages`. Sáu phép đo R1 vẫn cần chỗ:

| Cần đo | Nguồn |
|---|---|
| Latency mỗi trang | NFR-01 |
| Chi phí mỗi trang | NFR-02 |
| Số trang capture mỗi tuần | M-01 |
| Tỷ lệ item bị sửa tay | M-03 |
| Tỷ lệ analysis thất bại | M-04 |
| Tỷ lệ `example` không xác minh được | [prompt-spec mục 6](docs/agent/prompt-spec.md#6-xác-minh-example), quy tắc 3 |

**Đề xuất: bảng `analysis_events` trên proxy**, không chứa nội dung trang:

```
analysis_events (
  id, requested_at, image_hash, model, prompt_version,
  latency_ms, input_tokens, output_tokens, cost_estimate,
  item_count, verified_count, suspect_count, unverified_count,
  edited_count,           -- cap nhat sau khi owner duyet xong o FR-03 neu proxy nhan duoc
  failure_reason          -- null neu thanh cong
)
```

`image_hash` là idempotency key cho criterion FR-02 *"cùng một ảnh submit hai lần thì
không lưu hai bộ vocabulary trùng"* — phía proxy (không lưu vocab) dùng để trả lại
kết quả analysis đã tính; phía máy vẫn quyết định có insert `vocab_items` hay không.

`edited_count` sau FR-03 có thể chỉ nằm trên máy nếu không muốn vòng callback. Chốt
lúc solution design; cột tồn tại vì M-03 là yêu cầu R1.

### 10.2 `settings` trên máy — thiếu bốn núm

| Cột thiếu | FR nào hứa | Ghi chú |
|---|---|---|
| Ngưỡng `stability` coi là "đã thuộc" | FR-10, Q-08 | *"vượt một ngưỡng cấu hình được"* |
| Ngưỡng `lapses` coi là leech | FR-19 | *"vượt một ngưỡng cấu hình được"* |
| `enable_short_term` | Q-12 | Fen chốt **tắt**. `swift-fsrs`: `enableShortTerm` / learning steps rỗng |
| `timezone` (IANA) | FR-11, FR-14 | Mục 7.3 — `day_cutoff_hour` vô nghĩa nếu không biết giờ của ai |

### 10.3 Injectable clock trên iOS

FR-11, FR-12, FR-14 và streak phụ thuộc thời gian. Domain code **không** gọi
`Date()` rải rác. Một `Clock` protocol; mọi phép "hôm nay" đi qua một hàm
`(instant, timezone, day_cutoff_hour)`.

### 10.4 Xác minh `example` thuộc về adapter đang chạy

Thuật toán [prompt-spec mục 6](docs/agent/prompt-spec.md#6-xác-minh-example) ghép
`segments[].source_en`. `segments[]` **không được lưu**, nên verify **trong cùng
lần gọi FR-02**, trên tiến trình nào đã nhận JSON:

- active = `reado_proxy` → verify trên **proxy**, cùng request Gemini
- active = `openai_compat` → verify trên **máy** (adapter iOS), vì request không
  đi proxy

App luôn nhận item đã gắn nhãn. Ba con số (verified / suspect / unverified) chảy
vào `analysis_events` khi đi proxy; nhánh BYOK ghi local hoặc bỏ telemetry R1 —
chốt lúc solution design. Không verify hai lần.

---

## 11. Đã chốt và chưa chốt

### Đã chốt — session sau không cần tranh luận lại

| Quyết định | Cơ sở |
|---|---|
| Q-01 = native iOS (SwiftUI); R1 không Android, không PWA sản phẩm | Fen, 2026-09-17 |
| Q-02 = local-first, SQLite trên máy; dashboard sản phẩm = Later | Fen, 2026-09-17 |
| Q-03 = **hybrid** — proxy mặc định + BYOK OpenAI-compat (FR-21); NFR-07 viết lại | Fen, 2026-09-17 chiều; bia mộ proxy-only ở mục 2.3 |
| Q-12 = **tắt** learning steps trong ngày | Fen, 2026-09-08 |
| NFR-03 thoả ở R1 vì FSRS + queue trên máy | Mục 4 |
| FSRS R1 = `swift-fsrs` với `defaultWv6`; không `FSRS()` không tham số | Mục 3.1 |
| Proxy không chạy FSRS | Mục 4.2, 6.1 |
| Dialect SQLite: uuid `TEXT`, timestamp ISO-8601 UTC `Z`, `fsrs_params` `TEXT` JSON | Mục 7.2 |
| Go bị loại vì `go-fsrs` chỉ FSRS-5 | Mục 3.3 |
| Optimizer **không** ràng buộc ngôn ngữ proxy | Mục 6.3 |
| Gemini structured output **không** phải trục phân biệt ngôn ngữ proxy | Mục 5 |
| Chụp ảnh R1 = camera/picker hệ thống, không viewfinder custom | Mục 8.2 |
| FR-11 không dùng Web Push | Mục 8.3 |
| Verify `example` trên adapter đang chạy (proxy hoặc máy) | Mục 10.4 |
| Proxy phải hosted, không laptop-local | Mục 9 |
| `web/` = prototype, không phải app R1 | Mục 8.1 |
| Framework proxy = **Python + `google-genai`** (FastAPI/Flask/… chốt ở SD 0.6) | Fen duyệt 2026-09-18 (mục 6.2) |
| Reminder R1 = **local notification**; APNs cân nhắc sau | Fen chốt 2026-09-18 (mục 8.3) |

### Chờ ghi vào solution design (không phải hỏi lại Q-01–03)

| Câu hỏi | Đề xuất của doc này | Nếu chọn khác thì sao |
|---|---|---|
| **Framework cụ thể (FastAPI/Flask/…) của proxy** | Chốt trong SD 0.6 | Ngôn ngữ + SDK đã duyệt 2026-09-18: Python + `google-genai` |
| ~~**Local vs APNs cho reminder**~~ | **Chốt 2026-09-18: local notification cho R1**; APNs cân nhắc sau | Không được quay lại Web Push |

### Chưa chốt, và cố ý chưa

| Câu hỏi | Vì sao hoãn |
|---|---|
| Nhà cung cấp hosting cụ thể | Giá và free tier đổi nhanh; owner 2026-09-18: chốt lúc deploy (mục 9) |
| Model Gemini cụ thể | Thuộc bước kiểm chứng A-01/A-02 — owner 2026-09-18 xác nhận chốt ở 0.8 |
| Thư viện crop ảnh trên iOS | Chi tiết triển khai |
| Cơ chế sync dashboard Later | Không thiết kế đầy ở R1; giữ `uuid` client-side |

---

## 12. Cần áp dụng vào tài liệu nào

Bảng v1 (PWA) đã chạy một phần và **lệch**. Bảng v2 (2026-09-17 sáng) = native +
proxy-only. Bảng này là việc sync **v2.1** (Q-03 hybrid, cùng ngày).

| Đích | Thay đổi |
|---|---|
| `prd.md` mục 12 | Q-01, Q-02, Q-03, Q-12 → bảng **đã trả lời**, kèm ngày và lời giải |
| `prd.md` NFR-03 | Ghi *thoả vì FSRS + queue trên máy*; không hoãn R2 |
| `prd.md` NFR-07 | Viết lại: key sản phẩm trên proxy; key user Keychain (FR-21) |
| `prd.md` mục 10 | R1 = iOS app + proxy mặc định; FR-21 sau walking skeleton; NFR-03 giữ trong R1 |
| `prd.md` FR-21 | Analysis agents, Epic E5 |
| `db.md` | Bảng `analysis_agents`; `settings.active_agent_id`; không cột key |
| `journeys.md` | J-R1-S section agent; J1 lỗi BYOK; J8 không upload key |
| `prompt-spec.md` | Wire Gemini native **hoặc** OpenAI-compat, cùng JSON schema |
| `prd.md` mục 13 | Solution design viết được vì Q-01–03 đã chốt (nghĩa mới) |
| `prd.md` FR-11 | Nhắc ôn qua local notification / APNs, không Web Push |
| `vocabulary.md` | Mục dialect SQLite; uuid phục vụ local-first + cửa sync Later |
| `review.md` | Binding R1 = `swift-fsrs`; `ts-fsrs` vẫn tham chiếu field |
| `AGENTS.md` mục 3 (đã gộp `CLAUDE.md`) | Q-01–03 rời danh sách "phải hỏi / chặn code" |
| `AGENTS.md` mục 5 (đã gộp `CLAUDE.md`) | Dialect SQLite đã chốt |
| `AGENTS.md` mục 8 (đã gộp `CLAUDE.md`) | `swift-fsrs` v6 opt-in; solution design vẫn chưa có file |
| `PROJECT.md` (đã xoá), `README.md` | Stack R1; `web/` = prototype |
| `journeys.md` | Analysis cần mạng; ôn không; giờ nhắc không còn "tuỳ Q-01" |
| `vocabulary.md` | NG-09 = thư viện có sẵn; R1 = `swift-fsrs` |

---

## 13. Nguồn

### Đã đọc trực tiếp

| Nguồn | Đường dẫn |
|---|---|
| `swift-fsrs` README — FSRS-6 opt-in qua 21-length `w`; default v5 | https://github.com/open-spaced-repetition/swift-fsrs |
| `ts-fsrs` `default.ts` — `checkParameters` 17/19/21, `migrateParameters` | https://github.com/open-spaced-repetition/ts-fsrs/blob/main/packages/fsrs/src/default.ts |
| `java-fsrs` — 21 tham số, không optimizer | https://github.com/open-spaced-repetition/java-fsrs |
| `py-fsrs` — Optimizer | https://github.com/open-spaced-repetition/py-fsrs |
| awesome-fsrs — implementation theo ngôn ngữ | https://open-spaced-repetition.github.io/awesome-fsrs/ |
| awesome-fsrs wiki, *The Algorithm* — FSRS-6, 21 tham số | https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm |
| Google — JSON Schema structured output | https://blog.google/innovation-and-ai/technology/developers-tools/gemini-api-structured-outputs/ |
| Tài liệu nội bộ Reado | [prd.md](docs/specs/prd.md), [vision.md](docs/specs/vision.md), [prompt-spec.md](docs/agent/prompt-spec.md), [vocabulary.md](docs/research/vocabulary.md), [review.md](docs/research/review.md), [CLAUDE.md](CLAUDE.md) |

### Nhắc lại từ trí nhớ hoặc suy luận — CHƯA kiểm chứng

| Nội dung | Ở mục | Vì sao chưa chắc |
|---|---|---|
| `java-fsrs` chậm hơn `py-fsrs` một nhịp default | (v1 3.2, giữ) | Suy luận từ hai bộ default khác nhau |
| `go-fsrs` chỉ FSRS-5 | 3.3 | awesome-fsrs, chưa mở repo từng dòng |
| Local notification đủ cho một user, APNs là tối ưu | 8.3 | Chưa đo background delivery trên máy fen |
| Ước lượng proxy vài endpoint thì Java/Python lệch tốc độ nhỏ | 6.2 | Phán đoán, không benchmark |
