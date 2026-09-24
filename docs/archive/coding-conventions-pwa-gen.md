# Coding Conventions — Reado (task 1.4)

| Field | Value |
|---|---|
| Created | 2026-09-08 |
| Phạm vi | ⚠️ Bản PWA-gen (TS/Vite) — áp cho code PWA còn lại trong `app/`; bản Swift thay thế ở ROADMAP task 1.2. Nguồn spec: bộ docs sản phẩm. Mâu thuẫn với docs sản phẩm → docs thắng, ghi lại vào ROADMAP mục 4 |

## 1. Ngôn ngữ & tên gọi

- **TS strict** (`tsconfig` đã bật). Không `any` tràn lan; `unknown` + type guard khi
  parse dữ liệu ngoài (AI response, DB row).
- **Định danh code: tiếng Anh.** Thứ ở lại codebase là API/domain term tiếng Anh
  (`dueAt`, `dailyNewLimit`, `verifyExample`) — đổi provider, đổi người đọc vẫn hiểu.
- **Chữ người dùng thấy (UI): tiếng Việt.** Tách tuyệt đối: string hiển thị không bao
  giờ nằm trong `domain/` hay `storage/`; AI trả tiếng Việt ở `meaning_vi`/
  `translation_vi`/`summary_vi` là dữ liệu, không phải UI copy.
- Comment phức tạp được viết tiếng Việt (dự án một người, owner đọc là chính) — ngắn
  gọn, nói *vì sao*, không kể lại *cái gì*.

## 2. Layout thư mục (ranh giới cứng — solution-design mục 3)

```
app/src/
  domain/    — thuần TS; KHÔNG import DB/network. Nhận/trả dữ liệu thuần.
  storage/   — interface repository + adapter SQLite. Chỗ duy nhất chạy SQL.
  ai/        — interface provider + adapter Gemini. Chỗ duy nhất hit network.
  ui/        — React. CHỈ gọi domain qua use-case (domain/usecases/).
  app/       — bootstrap, settings, đăng ký service worker.
```

Dependency rule một chiều: `ui` → `domain`; `storage`/`ai` implement interface do
`domain` định nghĩa; `domain` không trỏ ra ngoài. Component React **không bao giờ**
gọi AI hay mở DB trực tiếp — vi phạm là vỡ ranh giới, không phải chuyện thẩm mỹ.

## 3. Error handling

- Lỗi AI (mạng, schema fail, finishReason ≠ STOP): class riêng trong `domain`
  (`AnalysisError` với mã phân biệt được), UI hiện thông điệp cụ thể + nút retry
  (FR-02/FR-04). **Không lưu bản ghi hỏng** nào.
- Query DB: repository ném lỗi có thông tin; transaction nào mà đổ giữa chừng thì
  rollback cả khối — đặc biệt `cards + review_logs` (xem điều cấm).
- Không nuốt lỗi im lặng (`catch {}` không có ghi chú là fail build).

## 4. Commit message — và PHẠM VI commit (owner chốt 2026-09-08)

- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:` kèm mã FR/task khi liên quan,
  ví dụ `feat(app): capture flow FR-01 (task 2.1)`.
- **Commit CHỈ chứa code trong `app/`.** Mọi docs/plan ở root repo (AGENTS.md,
  ROADMAP.md, docs/, qr/, ref/, idea.md, README, .env.example, scripts/) nằm NGOÀI
  git — lý do code để trong thư mục con. Ngoại lệ duy nhất: `.gitignore` root.
- Mỗi step code xong (check xanh) → commit một lần với message chi tiết việc đã
  làm/sửa, để owner trace được lịch sử.

## 5. Điều cấm (nguồn gốc: bảng "Đã chốt" + AGENTS mục 5 — vi phạm là đảo quyết định đã chốt)

| # | Điều cấm | Nguồn |
|---|---|---|
| 1 | Lưu `review_logs` trạng thái **sau** khi chấm — log là ảnh chụp **TRƯỚC** khi chấm | review-scheduling mục 4; AGENTS mục 5 |
| 2 | Gộp `cards.state` bớt còn 2 giá trị — **bốn** trạng thái `new/learning/relearning/review` | structure mục 3.2 |
| 3 | Tách transaction chấm thẻ: `update cards` + `insert review_logs` luôn **cùng một transaction** | solution-design mục 8.1 |
| 4 | Thêm ràng buộc `unique` trên `vocab_items` — cố ý không có; một dòng = một nghĩa | structure mục 6.3 |
| 5 | Tự viết SRS algorithm — chỉ dùng `ts-fsrs` (NG-09) | PRD mục 3 |
| 6 | Learning steps bật: `createScheduler` luôn `enable_short_term: false` (Q-12); state `learning` không bao giờ xuất hiện ở R1 | solution-design mục 9 |
| 7 | Timestamp mất timezone — mọi lưu trữ là TEXT ISO-8601 UTC `...Z`; "hôm nay" tính qua `domain/time.ts` `dayBounds()` | solution-design mục 4.3, 6 |
| 8 | `due_at` tính lại on-the-fly thay vì đọc cột DB | solution-design mục 5 |
| 9 | Secrets vào code/git — key AI chỉ đi từ user nhập (BYOK) vào `settings`, hoặc `.env` cho script dev; `.env` đã gitignore | Q-03 |
| 10 | AI tự đặt câu ví dụ — `example` phải đối chiếu được với `segments[].source_en`; item không khớp đánh dấu, **không** tự loại, **không** tự sửa | prompt-spec mục 6 |
| 11 | Đưa danh sách "từ đã thuộc" vào prompt — bộ lọc chạy phía client, sau response | prompt-spec mục 5 |
| 12 | Buffer cuộn persist — tối đa **10 trang**, sống trong phiên, hết phiên là mất (đúng hành vi) | Q-10; FR-06 |

## 6. Tooling (đã giữ trong repo, chạy sạch trước khi báo xong)

- `npm run lint` — **oxlint** (`app/.oxlintrc.json`). Ghi chú: task 1.4 ghi "ESLint"
  từ đầu; scaffold task 1.3 đã chọn oxlint (nhanh hơn, cùng nhóm rule), giữ oxlint
  để không churn. Nếu sau này cần rule type-aware thì cân nhắc lại.
- `npm run typecheck` — `tsc -b --noEmit`.
- `.editorconfig` — thống nhất indent/chuẩn file giữa editor.
- Prettier: **chưa thêm** — repo đang ở 0 commit, chưa có CI/contributor thứ hai;
  định dạng để oxlint/editor lo. Thêm khi có commit đầu.