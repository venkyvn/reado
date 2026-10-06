# Plan: workflow-docs-r1 — sửa bằng chứng test, workflow Claude Code, scripts và docs cho agent

> **Trạng thái:** open (2026-10-06) - T1–T4 xong; D1–D9 theo phương án "khuyên" (D6 bỏ qua), đang làm tiếp T5–T11

## Vấn đề & bằng chứng

Vấn đề gốc: những bằng chứng mà workflow dựa vào (kết quả test, plan đang mở, quyết định đã chốt) có thể sai mà không ai biết, và docs có nhiều bản của cùng một sự thật. Agent tin bản nó grep thấy trước, còn fen phải tự bắt lỗi.

Bằng chứng (đo tại `ca282b9`, 2026-10-06, phân tích read-only ở Cursor):

**Kết quả test không đáng tin**
- `scripts/test.sh:71,73,119,121`: dưới `set -euo pipefail`, nếu không có dòng `RESULT:` thì script thoát trước `write_summary`. `last-summary.txt` xanh cũ vẫn nằm nguyên và được hook nạp như kết quả mới. Đã tái hiện bằng bash.
- `sim_screens.sh:132–134` (`open` mặc định) và `sim_aibox.sh` đều gọi `scripts/test.sh build`. Ở lane build, `test.sh:79` chạy `rm -rf` xoá `last.xcresult`, `test.sh:123` ghi đè `last-summary.txt` thành `action: build` / `RESULT: n/a`, và `/tmp/build.log` cũng bị ghi đè. Hệ quả: verify UI sau khi chạy test là mất bằng chứng test.
- Summary ghi `head:` = HEAD lúc chạy. `/rhandoff` test trước rồi mới commit, nên sau commit `head` luôn khác HEAD (báo động giả). Ngược lại, sửa code sau khi test mà chưa commit thì `head` vẫn khớp (bỏ sót).

**Trạng thái session sai**
- Hook tìm plan bằng grep `**Trạng thái:** open`:
  - bỏ sót `pdf-reader-r1` (không có dòng trạng thái) và `apple-ai-r1` (sai format, T1–T7 đã xong);
  - vẫn hiện `structure-review-r1` (09-30) và `visual-polish-r1` (09-28) dù đã cũ;
  - 3 plan untracked dựng trên base `869902f`.
- `check-doc-links.mjs` báo 17 PROBLEMS: 7 là false positive (anchor `#Lnn` trỏ vào `.swift`), 10 là rác `[span_0]` trong `task.md`.
- Brief nhắc các branch đã merge và `plan_ocr_quality_r1.md`, file chưa từng vào git (nguồn là `~/.claude/plans/`).

**Secret có thể lộ**
- `settings.json` allow `Bash(grep *)`, và `guard.py` trả exit 0 cho `grep -rn API_KEY .` (đã chạy thử). `grep -r` không tôn trọng `.gitignore` và có đọc dotfile, nên trên máy build lệnh này in được `.env`.
- Grep tool với `glob: ".env*"` cũng qua được guard.
- Ngược lại, `git commit -m "chặn đọc .env"` bị chặn oan.

**Quyết định có nhiều bản**
- Q-09 xuất hiện trong 8 file. `ROADMAP.md:64` vẫn ghi "Theo collection" dù đã có ADR-066. `ROADMAP.md:50` vẫn ghi Q-03 "Hybrid".
- `decisions-log.md` có 68 ADR, không ADR nào có trường trạng thái. ADR-047 trùng số với nhánh `claude/upbeat-tesla-nc1rx2`; ADR-061 từng trùng số.

**Lịch sử nằm trong doc hợp đồng, và các chỗ lệch nhỏ**
- PRD: khoảng 16KB changelog; `Version` ghi 0.16 dù đã có v0.17.
- `solution-design.md`: tiêu đề vẫn "proxy hybrid", §4 hợp đồng proxy còn nguyên.
- ROADMAP: §2 đóng băng từ 09-18; §6 dài 25KB, ngừng cập nhật từ 10-02.
- `README.md:7` vẫn ghi "proxy hybrid".
- `MASTER.md:68` ghi tự ẩn sau 4s, trong khi code là 4s/7s (`ShellBanner.swift:24–26`).
- `db.md:7` "Last updated" vẫn là pdf-reader T0, dù migration v6 và v7 thêm sau đó.
- `coding-conventions.md` §7b ghi "Prefix luôn là `feat:`", nhưng 113/200 commit gần nhất dùng prefix khác.
- Conventions ghi `ReadoTests` có "4 lớp", thực tế có 5 file.

**`CLAUDE.md`, skill, agent, command**
- `CLAUDE.md` 13.160 byte, bị sửa ở 24 commit. §5 dài 3,4KB, phần lớn là "Chốt thêm…". §7 dài 3,9KB.
- Thiếu 3 luật cứng: không lưu file PDF gốc, key chỉ ở Keychain, logic ở ReadoKit. Luật "migration chỉ thêm case mới" không được viết ở đâu cả.
- `CLAUDE.md:124` ghi `pull_diagnostics.sh device`, nhưng thiếu `<udid>` thì script chỉ in danh sách máy rồi exit 1.
- `reado-ui`: gotcha đầu tiên dặn tự gọi `.safeAreaPadding`, trong khi code (`ShellTabBar.swift:14`, `App/ShellChrome.swift`) nói dùng `.shellScrollChrome()`, "không gọi tay". Bước verify build hai lần.
- `reado-dev` (sonnet) không làm được theo hợp đồng của chính nó: subagent không hỏi được fen và không gọi được `/rhandoff`.
- `/rhandoff` bước 1 tail `/tmp/build.log` liên tục (tốn token). `/rstart` lấy số test từ brief, tức số chép tay.

**Tự báo cáo lệch thực tế**
- Journal 2026-10-05 dòng 192 ghi `diag_summary.py` đã bỏ nhánh "OCR fix". Nhưng commit cuối đụng file này là `9e407d5`, và nhánh đó vẫn ở dòng 83–92.
- `/code-review` sau ocr-quality T3a bắt được 4 bug thật (`9e407d5`), nhưng review độc lập không nằm trong workflow.

**Chi phí ghi docs**
- `session-brief.md` bị sửa ở 100/246 commit. Mỗi commit `feat` gần đây đụng 4 file md. Journal 2026-10-05 dài 445 dòng dù `/rhandoff` dặn 3–5 dòng.

**Scripts lặp và thô**
- Tên simulator, đoạn tìm UDID và `BUNDLE_ID` lặp ở `test.sh:50,85–96`, `sim_screens.sh:48`, `sim_aibox.sh:16`. Bộ đọc `.env` có hai bản: một ở `sim_aibox.sh`, một ở `prompt_eval.py:80`.
- `sim_screens.sh`: `sleep 3` cho mỗi appearance (dòng 73), `sleep 4` sau launch (dòng 195), mà ảnh đầu vẫn có lúc trắng. Header liệt kê 23 màn viết tay.
- `prompt_eval.py:69` lấy literal `"""` đầu tiên nên chỉ eval được `Prompt.text`. `Prompt.pdfText` (`Prompt.swift:100`) không eval được, và placeholder `\(pageText)` không được thay. Baseline chỉ có `scripts/prompts/v5.txt` trong khi `Prompt.version = 6`.
- `diag_summary.py` in tới 30 lần phân tích. `pbxproj_tool.py:33` rglob qua cả DerivedData (0,74 giây); `add`/`remove` (dòng 143–147) là stub chết.

Đã qua `/ridea`: không. Phương án "không làm gì" bị loại vì sự cố đã xảy ra thật: kết quả test cũ, plan cũ, ADR trùng số.

Tiêu chí thành công (đo sau 30 commit kể từ khi khép plan):
- Hook cảnh báo khi code trong `app/` đã đổi sau lần test cuối hoặc khi `exit` khác 0, và liệt kê đủ mọi plan ngoài `done/`.
- Verify UI sau full test không làm mất kết quả test.
- `guard.py` chặn `grep -rn X .` nhưng vẫn cho `grep -rqwF x app/`.
- `scripts/verify/audit.sh` exit 0 trên HEAD; không commit được khi audit đỏ.
- `CLAUDE.md` ≤ khoảng 7000 byte và không commit `feat` nào phải sửa nó.
- `session-brief.md` bị sửa ở ≤ 15% số commit; trung bình ≤ 2 file md mỗi commit `feat`.
- Mỗi Q-xx chỉ được ghi như quyết định ở `CLAUDE.md` §5 và ADR; nơi khác chỉ trỏ tới.
- Replay `reado-reviewer` (Phụ lục D) tìm ra ≥ 2/4 lỗi đã biết.

Tiêu chí dừng:
- Replay ở T5 tìm ra dưới 2/4 lỗi: bước review trong `/rhandoff` chỉ để tuỳ chọn.
- Sau T4, nếu 3 task kế tiếp có vi phạm luật cứng mà trước đó không có: khôi phục phần `CLAUDE.md` liên quan.
- T6 làm vỡ `sim_screens`/`sim_aibox` mà không sửa được trong session: revert, giữ bản lặp.
- Task nào phải sửa Swift sản phẩm (ngoài 2 comment ghi ở Out-of-scope): dừng, tách plan riêng.

Đã đọc: ADR-035, ADR-044, ADR-046, ADR-049, `docs/plans/done/repo-hygiene-r1.md`.

## Spec
- FR / journey: không có. Đây là plan tooling + docs, cùng loại với repo-hygiene-r1.
- Nguyên lý: không phục vụ trực tiếp nguyên lý sản phẩm nào · NG: không đụng.
- In-scope: `scripts/**`, `.claude/**`, docs sống (`CLAUDE.md`, `README.md`, `ROADMAP.md`, `docs/**` trừ journal đã ghi), các file plan, `app/ReadoKit/CLAUDE.md` (mới).
- Out-of-scope / không đụng:
  - Swift sản phẩm, schema, FSRS, prompt, `project.pbxproj`. Ngoại lệ, chỉ sửa comment: `MigrationAndSeedTests.swift:190` và `VocabRepository.swift:417`.
  - Không đổi quyết định nào (trừ D9 nếu fen chọn), không viết lại FR/GWT. Chỉ dời, gộp, xoá bản trùng.
  - CI, XCUITest, Stop hook: xem "Ngoài plan này".
- Q mở: D1–D9. Task nào phụ thuộc một D chưa chốt thì không làm.

### Fen chốt trước khi bắt đầu
Đánh [x] vào lựa chọn. (khuyên) = phương án được đề xuất.

- **D1** — 3 plan untracked (`agent-json-settings-camera`, `floating-shell-tabbar`, `shell-tabbar-and-copy`): [ ] (a, khuyên) xoá khỏi `docs/plans/`, patch giữ ở `.lucy/carry/` · [ ] (b) track vào `done/` với trạng thái `closed`.
- **D2** — `structure-review-r1`, `visual-polish-r1`: [ ] (a, khuyên) chuyển `closed`, nợ xem tay dời sang `docs/qa/pending.md` · [ ] (b) giữ open.
- **D3** — `task.md`: [ ] (a, khuyên) xoá (git giữ lịch sử) · [ ] (b) dời sang `docs/plans/done/ux-redesign-r1-prompt.md`.
- **D4** — `docs/agent/agent-rulebook.md`: [ ] (a, khuyên) gộp vào `CLAUDE.md` §3 rồi xoá file · [ ] (b) giữ, §3 thêm một dòng trỏ tới nó.
- **D5** — `reado-dev`: [ ] (a, khuyên) xoá, thay bằng `reado-reviewer` + `reado-scout` · [ ] (b) giữ, viết lại hợp đồng thành "implement + test + trả báo cáo".
- **D6** — model cho main session: [ ] (a) `opusplan` (nếu bản Claude Code có alias này) · [ ] (b) Opus toàn bộ · [ ] (c) Sonnet, Opus chỉ cho `/ridea`, `/rplan` và reviewer.
- **D7** — 4 nhánh `claude/*` chưa merge: [ ] (a, khuyên) đối chiếu ở T11 rồi xoá · [ ] (b) merge từng nhánh.
- **D8** — đánh số ADR: [ ] (a, khuyên) trên nhánh viết `ADR-NEW-<slug>`, đánh số khi merge vào `main` · [ ] (b) giữ quy ước "lấy số tiếp theo".
- **D9** — prefix commit (§7b do fen chốt 2026-09-19, hiện 113/200 commit không theo): [ ] (a, khuyên) sửa §7b theo thực tế: `feat`/`fix`/`refactor`/`docs`/`chore`/`test` · [ ] (b) giữ "luôn `feat:`" và cho `audit.sh` cảnh báo commit sai prefix.

## Tầng 1 — HLD
- Module: không đụng Reado/ReadoKit (trừ 2 comment). Chỉ đụng `scripts/`, `.claude/` và docs.
- Mô hình docs 5 tầng (ghi thành ADR ở T7):

  | Tầng | File | Luật |
  |---|---|---|
  | Hiến pháp | `CLAUDE.md` (+ `app/ReadoKit/CLAUDE.md`), `vision.md`, `MASTER.md`, `coding-conventions.md` | Hiếm khi đổi, không ghi ngày |
  | Hợp đồng | `prd.md`, `journeys.md`, `db.md`, `solution-design.md`, `prompt-spec.md` | Chỉ ghi hiện tại; bia mộ tối đa 1 dòng |
  | Quyết định | `decisions-log.md` + index đầu file | Thân ADR bất biến; index được sửa |
  | Trạng thái | brief (§1–2 ≤ 3KB), `docs/qa/pending.md`, plans | Dùng ID ổn định, không dùng số thứ tự |
  | Lịch sử | journal, `prd-changelog.md` | Agent không đọc mặc định |

- Nguyên tắc 1: mỗi sự thật có đúng một nhà; mọi nơi khác chỉ trỏ tới.
- Nguyên tắc 2: việc máy kiểm được thì đưa vào script hoặc hook, không viết thành lời dặn.
- Nguyên tắc 3: mỗi loại bằng chứng chỉ có một script ghi, và bằng chứng gắn với nội dung code (tree hash của `app/`), không gắn với thời điểm (HEAD).
- Giữ nguyên số mục §4–§7 của `CLAUDE.md`, vì khoảng 25 chỗ trong code, ADR và spec đang trỏ theo số.
- File cấm: `project.pbxproj`; `app/**` (trừ 2 comment và `app/ReadoKit/CLAUDE.md`); thân các ADR đã ghi (chỉ được thêm index và ADR mới).

## Tầng 2 — Tasks
1 task = 1 session, làm theo thứ tự. Mọi task chạy trên máy có Claude Code và Xcode.

Phụ thuộc:
- T1 và T2 không phụ thuộc gì, làm trước tiên.
- T4 cần D4 và T1.
- T6 cần T1 và T4.
- T10 cần T2, T3 và T7.
- T11 cần D7, D8 và T7.

### T1 — Bằng chứng test không nói dối
- ✅ Xong 2026-10-06. Bằng chứng: kit xanh 589/590 và có `code:`; chèn lỗi biên dịch → summary `exit: 65`, hook báo "code đã đổi" + "không thành công" sau khi hoàn tác; full test 615/619 xanh rồi `test.sh build` → `last-summary.txt` (md5) và `last.xcresult` còn nguyên, build ghi `build-summary.txt`; `bash -n` sạch. Chưa kiểm: hook liệt kê 3 plan untracked của D1 (máy này không có 3 file đó). Hook nay liệt kê `pdf-reader-r1`/`apple-ai-r1` kèm cảnh báo thiếu dòng trạng thái (T3 sửa).
- Files: `scripts/test.sh`, `scripts/lib/evidence.sh` (mới), `.claude/hooks/session-context.sh`, `.claude/commands/{rhandoff,rstart}.md`.
- Làm:
  - `test.sh`: thêm `|| true` vào 4 phép gán ở dòng 71, 73, 119, 121. Khi không có `RESULT:` thì ghi `RESULT: n/a (build lỗi hoặc không có test result)`.
  - `test.sh`: lane `build` dùng đường dẫn riêng (`build.xcresult`, `build-summary.txt`, `/tmp/build-only.log`) và không đụng các file `last-*` (Phụ lục A1).
  - `write_summary` thêm dòng `code: <tree hash của app/>` (Phụ lục A2).
  - Hook: so `code:` và `exit` (Phụ lục A3); thay grep plan bằng vòng lặp (Phụ lục A4).
  - `/rhandoff` bước 1: chạy xong mới đọc `last-summary.txt` và dòng cảnh báo của hook. Không tail log lúc đang chạy; chỉ grep `error:` khi fail.
  - `/rstart` bước 5a: số test lấy từ summary (kèm khớp/không khớp), không lấy từ brief.
- Test:
  - `scripts/test.sh kit` xanh; `kit-summary.txt` có `exit: 0` và dòng `code:`.
  - Tạm thêm một lỗi biên dịch vào một file test ReadoKit, chạy `scripts/test.sh kit`: summary mới phải có `exit` khác 0. Hoàn tác.
  - Chạy `scripts/test.sh`, rồi `scripts/test.sh build`: `last-summary.txt` vẫn là kết quả test và `last.xcresult` vẫn còn.
  - Sau khi test, sửa một file `.swift`: hook báo "code đã đổi". Hoàn tác thì hết cảnh báo. Sửa một file docs hoặc commit ngay sau test: không cảnh báo.
  - `CLAUDE_PROJECT_DIR=$PWD .claude/hooks/session-context.sh` liệt kê `pdf-reader-r1`, `apple-ai-r1` và 3 file untracked.
  - `bash -n` sạch cho mọi script đã sửa.
- DoD: mọi lần chạy đều ghi summary mới; build không xoá kết quả test; hook cảnh báo đúng.

### T2 — Chặn lộ secret qua grep
- ✅ Xong 2026-10-06. Bằng chứng: `python3 scripts/verify/test_guard.py` 32/32 (17 case Phụ lục B + 15 case thêm: heredoc commit, `2>/dev/null`, `--recursive`, `rg --no-ignore`, `&& cat .env`…). Thêm vào `_bash_has_env_secret`: bỏ `--exclude=…` và nội dung `-m`/heredoc của `git commit`.
- Files: `.claude/hooks/guard.py`, `scripts/verify/test_guard.py` (mới).
- Làm:
  - Bash: chặn grep đệ quy (`grep|egrep|fgrep` có `-r`/`-R`/`--recursive`) khi không có path, hoặc path là `.`, `./`, `*`, hoặc gốc repo, trừ khi có `--exclude=.env*`. Chặn `rg` có `-u`/`--hidden`/`--no-ignore`. `git grep` vẫn cho qua (chỉ đọc file tracked).
  - Grep tool: chặn khi `glob` hoặc `path`, sau khi bỏ tiền tố `**/` và `*/`, khớp tên file secret.
  - `git commit`: không xét token `.env` trong `-m`; chỉ chặn `-F`/`--file` trỏ vào file secret.
  - Message khi chặn grep: "dùng Grep tool (tôn trọng .gitignore) hoặc thêm `--exclude='.env*'`".
  - `test_guard.py`: chạy toàn bộ bảng ở Phụ lục B qua `guard.py`, lệch case nào thì exit 1.
- Test: `python3 scripts/verify/test_guard.py` exit 0.
- DoD: mọi case trong Phụ lục B đúng; các luật cũ (pbxproj, `swift build`, `xcodebuild` trần, `cat .env`) vẫn chặn.

### T3 — Dọn plan + gate link xanh
- ✅ Xong 2026-10-06. Bằng chứng: checker exit 0; hook liệt kê đúng 3 plan open. D1 n/a (3 plan untracked không có trên máy này); D2a: `structure-review-r1`, `visual-polish-r1` → `done/` kèm nợ xem tay ở `docs/qa/pending.md`; D3a: xoá `task.md`; `plan_ocr_quality_r1.md` còn nên vào `docs/plans/ocr-quality-r1.md`.
- Files: `docs/plans/*.md`, `docs/plans/done/`, `task.md`, `scripts/verify/check-doc-links.mjs`, `.claude/commands/rhandoff.md`, `docs/session-brief.md` §1.
- Làm:
  - `pdf-reader-r1.md`: thêm dòng 3 `> **Trạng thái:** open (2026-10-04) - T0–T4 xong, còn T5 eval prompt trên PDF thật`.
  - `apple-ai-r1.md`: dòng 3 thành `closed (2026-10-05) - T1–T7 xong; phần soát OCR gỡ ở ADR-065`, `git mv` vào `done/`, sửa các con trỏ.
  - Áp D1, D2, D3.
  - Checker dòng 116: đổi thành `if (frag && resolved.toLowerCase().endsWith('.md'))`.
  - Brief §1: bỏ tên các branch đã merge. Hỏi fen `plan_ocr_quality_r1.md` đang ở đâu: còn thì đưa vào `docs/plans/ocr-quality-r1.md`; mất thì ghi "plan gốc không còn, xem journal 2026-10-05".
  - `/rhandoff` bước 4: checker exit khác 0 thì không commit.
- Test: `node scripts/verify/check-doc-links.mjs; echo $?` ra `0`; hook liệt kê đúng các plan đang open thật.
- DoD: 0 PROBLEMS; mọi plan ngoài `done/` có dòng 3 đúng format; không còn plan untracked.

### T4 — `CLAUDE.md`, skill, `app/ReadoKit/CLAUDE.md`
- ✅ Xong 2026-10-06 (D4a). Bằng chứng: `CLAUDE.md` 13160 → 7143 byte, mọi dòng luật cứng cũ còn (+4 dòng mới), không còn "Chốt thêm"; checker exit 0; `agent-rulebook.md` đã xoá, con trỏ sống ở ROADMAP/pdf-reader-r1 đã sửa (decisions-log, journal, plan done giữ nguyên). **Chưa làm:** bài hỏi 5 câu sau `/clear` và thử kích hoạt skill — cần session mới, fen/agent chạy ở session sau.
- Files: `CLAUDE.md`, `app/ReadoKit/CLAUDE.md` (mới), `.claude/skills/reado-diagnostics/SKILL.md` (mới), `.claude/skills/reado-ui/SKILL.md`, `docs/agent/agent-rulebook.md` (theo D4), mọi file trỏ tới `agent-rulebook.md`, `app/ReadoKit/Sources/ReadoKit/Vocab/VocabRepository.swift:417` (chỉ comment).
- Làm:
  - Ghi nguyên văn 4 file ở Phụ lục E (fen đã duyệt nội dung); chỉ sửa khi test dưới fail.
  - Theo D4: (a) xoá `agent-rulebook.md` và sửa con trỏ (`rg -l agent-rulebook`); (b) giữ file, thêm một dòng vào §3.
  - Comment ở `VocabRepository.swift:417`: đổi "(CLAUDE.md §7)" thành "(coding-conventions.md §9)". Bẫy NOCASE đã rời `CLAUDE.md`.
- Test:
  - `wc -c CLAUDE.md` khoảng 7000 trở xuống.
  - Mọi dòng của bảng luật cứng cũ còn trong §4 (được thêm 3 dòng mới).
  - Checker exit 0.
  - `/clear` rồi hỏi 5 câu: "thêm file Swift thế nào", "Q-09 là gì", "chạy test 1 lớp ReadoKit thế nào", "ngưỡng leech là bao nhiêu", "debug OCR bắt đầu từ đâu". Đúng cả 5, và câu cuối phải kích hoạt `reado-diagnostics`.
  - Đọc một file trong `app/ReadoKit/` rồi hỏi "luật migration là gì": agent trả lời theo `app/ReadoKit/CLAUDE.md`.
- DoD: đạt các test trên; `CLAUDE.md` không còn dòng "Chốt thêm 20xx".

### T5 — Reviewer subagent + định tuyến model
- Files: `.claude/agents/reado-reviewer.md` (mới, Phụ lục C), `.claude/agents/reado-scout.md` (mới), `.claude/agents/reado-dev.md` (theo D5), frontmatter của `.claude/commands/{ridea,rplan,raudit,rhandoff}.md`.
- Làm:
  - `reado-scout`: `model: haiku` (hoặc sonnet), `tools: Read, Grep, Glob`. Tra docs lớn và trả trích dẫn có `file:line`, tối đa 40 dòng.
  - `/rhandoff`: thêm bước 1b, gọi `reado-reviewer` trên diff. Có P0 thì sửa trước khi hỏi approve; P1/P2 liệt kê để fen chọn.
  - Frontmatter `model:`: `/ridea` và `/rplan` dùng opus, `/raudit` dùng haiku. Main session theo D6.
  - `/rplan` bước 5: plan làm ở plan mode phải được lưu thành `docs/plans/<id>.md` khi fen OK, không để ở `~/.claude/plans/`.
- Test: replay theo Phụ lục D.
- DoD: replay ≥ 2/4 thì bước 1b bắt buộc; dưới mức đó thì để tuỳ chọn. `reado-dev` xử lý theo D5.

### T6 — Scripts dùng chung + bỏ chờ cố định
- Files: `scripts/lib/sim.sh` (mới), `scripts/lib/envkey.py` (mới), `scripts/{test,sim_screens,sim_aibox}.sh`, `scripts/{prompt_eval,diag_summary,pbxproj_tool}.py`, `.claude/skills/{reado-ui,reado-diagnostics}/SKILL.md`.
- Làm:
  - `lib/sim.sh` gồm `SIM_NAME`, `BUNDLE_ID`, `sim_udid`, `sim_boot`, `app_path`, `install_launch`. `test.sh` (dòng 85–96), `sim_screens.sh` và `sim_aibox.sh` cùng dùng. Trong `sim_screens.sh`, gộp nhánh `open` với nhánh mặc định.
  - `lib/envkey.py`: một bộ đọc `.env` duy nhất (logic `pick_env_key` hiện ở `prompt_eval.py:80`); `sim_aibox.sh` gọi nó thay cho đoạn python nhúng. Không bao giờ in key.
  - `sim_screens.sh`:
    - Thay `sleep 3` (dòng 73) và `sleep 4` (dòng 195) bằng poll: chụp; nếu PNG nhỏ hơn ngưỡng (ảnh trắng nén rất nhỏ; đo ngưỡng một lần trên iPhone Air) thì đợi 0,5 giây rồi chụp lại, tối đa khoảng 8 giây.
    - Thêm lệnh `list`, in các case của `DebugLaunch.Screen` (`app/ReadoKit/Sources/ReadoKit/Shell/DebugLaunch.swift`). Header bỏ danh sách màn viết tay, trỏ sang `list`.
  - `prompt_eval.py`:
    - Thêm `--swift-func text|pdfText`, thay regex ở dòng 69 đang lấy literal đầu tiên. Map cả `\(pageOCR)` lẫn `\(pageText)` thành `{PAGE_OCR}`.
    - `--prompt git:<rev>` đọc `Prompt.swift` ở commit cũ qua `git show`, khỏi phải giữ snapshot `.txt`.
  - `diag_summary.py`: bỏ nhánh "OCR fix" (dòng 83–92; ADR-065 đã gỡ, app không còn ghi khoá `fixes`). Thêm `--last N` (mặc định 5).
  - `pbxproj_tool.py`: dùng đường dẫn cố định `app/Reado.xcodeproj/project.pbxproj` thay rglob (dòng 33); bỏ action `add`/`remove` (dòng 143–147).
  - Skills: `reado-ui` bỏ gotcha "ảnh đầu trắng" và trỏ sang `sim_screens.sh list`. `reado-diagnostics` bỏ câu "chưa eval được `pdfText`", thêm ví dụ `--swift-func pdfText`.
- Test:
  - `bash -n` và `python3 -m py_compile` sạch.
  - `sim_screens.sh open home --no-build`, rồi `shot t` 5 lần: không có ảnh trắng.
  - Số dòng `sim_screens.sh list` bằng số case của enum.
  - `sim_aibox.sh` chạy như cũ.
  - `prompt_eval.py --swift-func pdfText --limit 1` trên một thư mục diagnostics PDF. Chưa có dữ liệu thì ghi "chưa chạy được", không báo xong.
  - `pbxproj_tool.py check` vẫn qua; `scripts/test.sh` xanh.
- DoD: không còn bản thứ hai của đoạn tìm UDID hay bộ đọc `.env`; không còn `sleep` cố định trong `sim_screens.sh`.

### T7 — Index ADR + một nguồn quyết định
- Files: `docs/decisions-log.md`, `ROADMAP.md` (§0, §1), mục "Đã chốt" ở `docs/research/{vocabulary,review,tech-stack}.md`, `docs/agent/prompt-spec.md` §9, `docs/specs/solution-design.md` §2, `docs/specs/prd.md` §12.
- Làm:
  - Thêm index ở đầu `decisions-log.md`: `| ADR | Tiêu đề | Trạng thái | Thay bởi |`, đủ 68 ADR. Trạng thái là một trong: `hiệu lực` · `bị thay (ADR-xxx)` · `một phần (ADR-xxx)` · `bia mộ PWA`. Dùng `reado-scout` grep "đảo|thay|bỏ" theo từng số ADR. Sửa quy ước đầu file: thân ADR bất biến, index cập nhật mỗi khi có ADR mới.
  - Thêm ADR mới (đánh số theo D8) ghi mô hình docs 5 tầng và 3 nguyên tắc ở HLD.
  - Dời ROADMAP §1 (bảng Q) sang `docs/journal/archive-roadmap-2026-09.md`, để lại một dòng trỏ tới `CLAUDE.md` §5. ROADMAP §0: bỏ quy tắc "file này thắng" và "cập nhật mục 2 và mục 6".
  - Đầu mỗi mục "Đã chốt" ở research/spec, thêm `> Ảnh chụp lúc nghiên cứu. Quyết định hiện hành: CLAUDE.md §5 + index ADR.` Không sửa nội dung bên dưới.
- Test: số dòng index bằng `grep -c "^## ADR-" docs/decisions-log.md`; ROADMAP không còn Q-03/Q-09 đứng như quyết định; checker exit 0.
- DoD: mọi ADR có trong index; không còn bản cũ nào của Q-xx đứng như quyết định hiện hành.

### T8 — Đưa lịch sử ra khỏi doc hợp đồng + sửa lệch nhỏ
- Files: `ROADMAP.md`, `docs/journal/archive-roadmap-2026-09.md`, `docs/specs/prd.md`, `docs/specs/prd-changelog.md` (mới), `docs/specs/solution-design.md`, `docs/specs/db.md`, `README.md`, `docs/agent/coding-conventions.md`, `design-system/reado/MASTER.md`, `app/ReadoKit/Tests/ReadoKitTests/MigrationAndSeedTests.swift` (chỉ comment dòng 190).
- Làm:
  - ROADMAP §2 và §6: dời nguyên văn sang file archive của T7; mỗi mục để lại một dòng trỏ.
  - PRD: Document Control tối đa 12 dòng. Các khối `> **v0.x — …**` và bảng thay đổi FR đầu §7 dời nguyên văn sang `prd-changelog.md`. `Version` sửa thành 0.17.
  - `solution-design.md`:
    - Tiêu đề bỏ "proxy hybrid".
    - §4 thay bằng bia mộ 2 dòng (bỏ theo ADR-049; bản cuối xem bằng `git show <hash>:docs/specs/solution-design.md`).
    - Duyệt từng chỗ còn chữ "proxy": chỗ mô tả như hiện hành thì thành bia mộ một dòng; chỗ là lịch sử thì giữ.
  - `db.md:7`: bỏ dòng "Last updated" viết tay (git log là nguồn).
  - `README.md:7`: "AI qua BYOK OpenAI-compat hoặc Apple Intelligence trên máy".
  - `coding-conventions.md`:
    - §3 bỏ "AGENTS mục 4".
    - §7b sửa theo D9.
    - §7 đổi "ghi bằng chứng vào ROADMAP" thành "ghi vào plan".
    - §2 (dòng 45) và §7 (dòng 100) bỏ con số "4" lớp/file ReadoTests.
  - `MASTER.md:68`: "4s; 7s khi có dòng phụ (`ShellBanner.autoHideSeconds`)", cập nhật dòng "Đối chiếu code lần cuối".
  - Comment ở `MigrationAndSeedTests.swift:190`: `AGENTS mục 3.1` đổi thành `CLAUDE.md §4`.
- Test: checker exit 0; `/raudit` bước 6 (token MASTER) sạch; `scripts/test.sh kit` xanh.
- DoD: `ROADMAP.md` ≤ khoảng 45KB; `prd.md` nhẹ đi khoảng 15KB; doc sống không còn mô tả proxy như hiện hành.

### T9 — Tách brief: chờ quyết và nợ xem tay
- Files: `docs/session-brief.md`, `docs/qa/pending.md` (mới), `.claude/commands/rhandoff.md`, ngân sách trong `.claude/hooks/session-context.sh` và `.claude/commands/raudit.md`, các plan và ROADMAP đang trỏ `§2.N`.
- Làm:
  - `docs/qa/pending.md`: mỗi nợ xem tay là một mục `QA-NN`, giữ số cũ (§2.9 thành QA-09). Dạng `- [ ] QA-15a — <việc> · máy: sim/thật · plan: <đường dẫn>`. Đầu file có bảng ánh xạ `§2.N → QA-NN/OW-NN`; không sửa journal hay plan đã đóng.
  - Brief §2 chỉ giữ những câu cần fen quyết hoặc cần fen đưa dữ liệu, với ID `OW-NN`. Phân loại ước tính:
    - Sang OW: §2.1, §2.3, §2.6, §2.12, §2.13.
    - Sang QA: §2.9, §2.11, §2.14–2.16.
    - Tách đôi: §2.10.
    - Mục đã xong: xoá.
  - Brief §1 tối đa 10 dòng, mỗi plan một dòng. Ngân sách §1–2 hạ từ 8192 xuống 3072 byte (sửa ở cả hook lẫn `/raudit`).
  - `/rhandoff` bước 3:
    - Mỗi task chỉ ghi plan (task done + bằng chứng) và journal (≤ 5 dòng).
    - Brief chỉ sửa khi mở/khép plan hoặc khi OW đổi.
    - ROADMAP chỉ sửa khi FR đổi trạng thái.
    - Nợ xem tay mới thì thêm vào `docs/qa/pending.md`.
- Test: `awk` đo §1–2 ≤ 3072 byte; grep `§2\.[0-9]` trên file sống (trừ journal và `done/`) ra 0; checker exit 0.
- DoD: fen mở `docs/qa/pending.md` là đi được một lượt kiểm trên máy thật.

### T10 — Scripts hoá kiểm tra + cổng commit + permission
- Files: `scripts/verify/audit.sh` (mới), `scripts/close_plan.sh` (mới), `.claude/hooks/guard.py`, `.claude/commands/{raudit,rhandoff}.md`, `.claude/settings.json`, `scripts/verify/README.md`. File local trên máy NAB (không track): `.cursor/skills/raudit/SKILL.md`.
- Làm:
  - `audit.sh` gom bước 1–6 của `/raudit` và thêm:
    - dòng 3 của mọi plan ngoài `done/`; plan `closed` mà còn nằm ngoài `done/`; plan untracked;
    - mọi `## ADR-` có trong index; còn `ADR-NEW-` trên `main` (cảnh báo);
    - ngân sách brief; `CLAUDE.md` > 7000 byte (cảnh báo); entry journal hôm nay > 8 dòng (cảnh báo);
    - `python3 scripts/verify/test_guard.py`;
    - prefix commit nếu D9 = (b) (cảnh báo).

    Có PROBLEM thì exit 1.
  - `close_plan.sh <id> "<tóm tắt>"`: sửa dòng 3 thành `closed (<hôm nay>) - …`, `git mv` vào `done/`, sửa con trỏ ở ROADMAP, brief, plan đang mở và `docs/qa/pending.md`, rồi chạy checker.
  - `guard.py`: khi Bash là `git commit`, chạy `audit.sh`; exit 1 thì chặn (exit 2) và in danh sách PROBLEM.
  - `/raudit` rút còn: chạy `audit.sh`, tóm tắt ≤ 10 dòng. `/rhandoff` bước 4 gọi `close_plan.sh`.
  - Allow list thêm: `Bash(scripts/verify/audit.sh)`, `Bash(python3 scripts/verify/test_guard.py)`, `Bash(scripts/close_plan.sh *)`, `Bash(scripts/sim_screens.sh *)`, `Bash(python3 scripts/diag_summary.py *)`, `Bash(scripts/pull_diagnostics.sh *)`, `Bash(git mv *)`. Giữ `git commit` ngoài allow.
  - `.cursor/skills/raudit/SKILL.md` rút còn một dòng: chạy `scripts/verify/audit.sh`.
- Test: `audit.sh` exit 0 trên HEAD sạch. Tạo tạm một plan sai dòng 3: audit exit 1 và `git commit` bị chặn; xoá plan tạm. Chạy thử `close_plan.sh` trên một plan nháp tạm.
- DoD: `/raudit` không còn pipeline viết tay; không commit được khi audit đỏ.

### T11 — Điều phối song song: số ADR + nhánh mồ côi
- Files: `docs/decisions-log.md` (quy ước đầu file), `.claude/commands/{rplan,rhandoff}.md`, `CLAUDE.md` §7 Workflow (thêm một dòng).
- Làm:
  - Theo D8: trên nhánh viết `ADR-NEW-<slug>`; `/rhandoff` trên `main` (hoặc lúc merge) đổi sang số tiếp theo và cập nhật index.
  - Đối chiếu từng nhánh bằng `git log main..<nhánh>` và `git diff main...<nhánh>`:
    - `claude/eager-ptolemy-trkabr`: 1 commit sửa brief.
    - `claude/magical-dijkstra-6axsi4`: handoff dở của structure-review T1.
    - `claude/upbeat-tesla-nc1rx2`: ADR-047 về CI, trùng số với `main`; ý CI chuyển sang plan CI riêng.
    - `claude/wizardly-newton-dk2pgu`: plan fsrs-queue-fix, đã khép trên `main`.

    Nội dung còn giá trị thì ghi vào plan, rồi xử lý theo D7. Xoá nhánh remote là thao tác push: fen tự chạy hoặc approve.
  - Thêm vào `CLAUDE.md` §7 Workflow: cloud session (`claude/*`) chỉ commit code và plan, không sửa brief, journal, ROADMAP.
- Test: `git branch -r --no-merged origin/main` chỉ còn những nhánh có lý do giữ.
- DoD: không còn quyết định nào chỉ nằm trên một nhánh chưa merge.

## Ngoài plan này (mở plan riêng khi cần)
- CI GitHub Actions (runner macOS, lane `kit`): cần chốt trước repo public hay private, vì private thì phút macOS tính hệ số cao.
- Target XCUITest để tự động hoá các nợ QA cần chạm, vuốt, cuộn: fen tạo target trong Xcode.
- Stop hook nhắc chạy test khi `app/**` đổi sau summary gần nhất (dùng `code:` của T1); phải kiểm `stop_hook_active`.
- Chuyển repo trên máy NAB ra khỏi OneDrive.

---

## Phụ lục A — snippet cho T1

A1, `scripts/test.sh`: thay dòng 51. Các chỗ đang dùng `/tmp/build.log` ở dòng 111 và 115 đổi thành `"$LOG"`; dòng 123 ghi vào `"$ROOT/.tmp/results/$TAG-summary.txt"`.

```bash
case "$ACTION" in
  build) TAG=build; LOG=/tmp/build-only.log ;;
  *)     TAG=last;  LOG=/tmp/build.log ;;
esac
RESULT="$ROOT/.tmp/results/$TAG.xcresult"
```

Bốn phép gán dòng 71, 73, 119, 121, ví dụ:

```bash
RESULT_LINE="$(echo "$SUMMARY_OUT" | grep '^RESULT:' | head -1 || true)"
```

A2, `scripts/lib/evidence.sh` (`test.sh` và hook cùng source):

```bash
# Chỉ băm app/ (kể cả file chưa track — Xcode compile cả chúng); sửa docs sau khi test không làm lệch.
code_tree() {
  ( cd "$1" || exit 1
    idx="$(mktemp -u)"
    GIT_INDEX_FILE="$idx" git add -A -- app >/dev/null 2>&1
    GIT_INDEX_FILE="$idx" git write-tree
    rm -f "$idx" )
}
```

Trong `write_summary`, thêm: `echo "code: $(code_tree "$ROOT" 2>/dev/null || echo unknown)"`. Tác dụng phụ duy nhất là vài blob mới trong `.git/objects`; `git gc` sẽ dọn.

A3, hook, chèn sau `cat "$path"`:

```bash
source scripts/lib/evidence.sh
want="$(sed -n 's/^code: //p' "$path")"
now="$(code_tree . 2>/dev/null || echo '?')"
if [[ -z "$want" ]]; then
  echo "⚠️ summary cũ chưa có dòng code: — coi như chưa test"
elif [[ "$want" != "$now" ]]; then
  echo "⚠️ code trong app/ đã đổi sau lần chạy này — coi như chưa test"
fi
grep -q '^exit: 0$' "$path" || echo "⚠️ lần chạy cuối không thành công"
```

A4, hook, thay khối `OPEN_PLANS`:

```bash
echo
echo "Plan chưa vào done/:"
for f in docs/plans/*.md; do
  [[ -e "$f" ]] || continue
  s="$(sed -n 3p "$f")"
  [[ "$s" == '> **Trạng thái:** '* ]] || s="⚠️ thiếu/sai dòng trạng thái"
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 || s="$s (untracked)"
  echo "- $(basename "$f"): $s"
done
```

## Phụ lục B — case cho `guard.py` (T2)

| Tool | Input | Exit mong đợi |
|---|---|---|
| Bash | `grep -rn API_KEY .` | 2 |
| Bash | `grep -rn API_KEY` | 2 |
| Bash | `rg -uu API_KEY` | 2 |
| Bash | `rg --hidden KEY` | 2 |
| Bash | `grep -rqwF foo app/` | 0 |
| Bash | `grep -rn KEY . --exclude='.env*'` | 0 |
| Bash | `git grep API_KEY` | 0 |
| Grep | `glob: ".env*"` | 2 |
| Grep | `glob: "**/.env.local"` | 2 |
| Grep | `glob: "*.swift"` | 0 |
| Bash | `git commit -m "chặn đọc .env"` | 0 |
| Bash | `git commit -F .env` | 2 |
| Bash | `cat .env` | 2 |
| Bash | `cat .env.example` | 0 |
| Bash | `cd app && xcodebuild test` | 2 |
| Bash | `swift build` | 2 |
| Edit | `app/Reado.xcodeproj/project.pbxproj` | 2 |

## Phụ lục C — `.claude/agents/reado-reviewer.md` (T5)

```markdown
---
name: reado-reviewer
description: Review độc lập diff của một task Reado vừa xong, so với plan + luật cứng. Read-only. /rhandoff gọi trước khi hỏi fen approve; cũng dùng khi fen nói "review lại".
tools: Read, Grep, Glob, Bash
model: opus
---

# Reado Reviewer

Bạn không viết code này và không bênh nó. Tìm lỗi thật, không tìm lỗi trình bày.

Input: task-id (hoặc "không plan") + cách lấy diff (mặc định `git diff main...HEAD` và `git diff`).

Kiểm theo thứ tự:
1. DoD của task trong `docs/plans/<id>.md`: đạt chưa, thiếu gì.
2. Luật cứng `CLAUDE.md` §4, `app/ReadoKit/CLAUDE.md`, `docs/agent/coding-conventions.md` §3–6, §8.
3. Transaction và dữ liệu thật: trang nhiều đoạn ngắn, input rỗng, tiếng Việt có dấu, giờ quanh ranh giới ngày (`DayBoundary`).
4. Concurrency Swift 6: static không Sendable, gọi UIKit ngoài main actor.
5. Test: nhánh mới có test chưa; test có fail thật nếu code sai không.
6. Trùng lặp: logic đã có ở ReadoKit (grep trước khi kết luận).
7. Tuyên bố trong journal / brief / plan của task ("đã bỏ X", "đã sửa Y") có thật trong diff không.

Output: tối đa 10 finding, sắp theo mức.
- `P0` sai dữ liệu / vỡ luật cứng / crash · `P1` sai hành vi người dùng có thể gặp · `P2` nợ kỹ thuật.
- Mỗi finding: mức · `file:line` · một kịch bản cụ thể làm lỗi xảy ra · gợi ý sửa.
- Mức nào không có finding thì ghi "không có". Không sửa file. Chưa đọc dòng đó thì không cite `file:line`.
```

## Phụ lục D — replay để đo reviewer (T5)

```bash
git worktree add /tmp/reado-replay 1c161f0   # trạng thái ngay trước bản sửa 9e407d5
cd /tmp/reado-replay && git diff b679ccb^ 1c161f0 -- app scripts > /tmp/replay.diff
```

Gọi `reado-reviewer` với input "không plan, diff ở /tmp/replay.diff, repo ở /tmp/reado-replay". Đếm số lỗi tìm ra trong 4 lỗi đã biết (journal 2026-10-05, mục "Code review sau T3a"):
1. `mergeParagraphBoundaries` làm tròn độc lập từng đoạn; sai số dồn về cuối trang khi trang có nhiều đoạn ngắn.
2. `lines[]` trong `ocr.json` lệch với bản đã gửi model khi `engine=liveText`.
3. `UITextChecker` static không an toàn luồng.
4. Hai bản Levenshtein trùng nhau (`OCRFixApplier` và `OCRProbeTests`).

Xong thì dọn: `git worktree remove /tmp/reado-replay`.

## Phụ lục E — nội dung đích cho T4

Viết sẵn theo trạng thái sau T1 (đường dẫn summary/log của lane `build`). Đã đối chiếu code tại `ca282b9`.

### E1 — `CLAUDE.md`

````markdown
# CLAUDE.md — Reado

Hook SessionStart đã nạp sẵn: HEAD, `git status`, test gần nhất, plan open, brief §1–2.

## 1. Reado là gì

- App iOS native (SwiftUI) học từ vựng từ sách thật: chụp trang hoặc mở PDF → trích từ mới theo ngữ cảnh → ôn bằng FSRS.
- Local-first: SQLite trên máy, một người dùng (Q-02, NG-05).
- AI: BYOK OpenAI-compat (key ở Keychain) hoặc Apple Intelligence on-device, mặc định khi máy hỗ trợ và chưa chọn agent. OCR: engine `liveText` (iOS 26+).
- Owner = fen: product owner, không phải chuyên gia kỹ thuật. R1 = MVP một user; metric M-07: bỏ luồng chat Gemini thủ công.

## 2. Lệnh

```bash
scripts/test.sh                # build + full test — bắt buộc trước /rhandoff
scripts/test.sh kit            # ReadoKit trên macOS, ~10s — khi đang sửa logic
scripts/test.sh test -only-testing:ReadoKitTests/<Class>   # 1 lớp, simulator
scripts/test.sh test -only-testing:ReadoTests/<Class>      # lớp cần UIKit/Vision
scripts/test.sh build
python3 scripts/repo_map.py [--root app/ReadoKit/Sources --limit 40]
```

- Kết quả: `.tmp/results/{last,kit,build}-summary.txt` theo lane; hook cảnh báo khi code đổi sau lần test. Log `/tmp/build.log` (kit: `/tmp/build-kit.log`, build: `/tmp/build-only.log`) — fail thì grep `error:`, không đọc nguyên.
- Cấm `swift build`/`swift test`, cấm `xcodebuild` trần — hook chặn; bị chặn thì đọc message, không lách.
- Sửa view → skill `reado-ui`. Debug OCR/phân tích → skill `reado-diagnostics`.

## 3. Đụng X → đọc Y

| Đụng | Đọc |
|---|---|
| Nguyên lý, chỗ mơ hồ | `docs/specs/vision.md` |
| FR/NFR, scope R1/R2 | `docs/specs/prd.md` |
| Lối đi UI (J1–J6) | `docs/specs/journeys.md` |
| Schema, dialect SQLite | `docs/specs/db.md` |
| Module, ranh giới transaction | `docs/specs/solution-design.md` §3 |
| Đọc PDF (FR-23) | ADR-058, `solution-design.md` §8b, `db.md` A.2 |
| Prompt, output schema | `docs/agent/prompt-spec.md` |
| Quy ước Swift, layout, commit | `docs/agent/coding-conventions.md` |
| Look UI, token | `design-system/reado/MASTER.md` |
| FSRS/sync · collection/import · stack | `docs/research/{review,vocabulary,tech-stack}.md` |
| Vì sao có một quyết định | `docs/decisions-log.md` (grep số ADR) |
| Tiến độ FR, task tiếp | `ROADMAP.md` |

- File lớn — Grep rồi Read có offset/limit: mọi file trong `docs/specs/` trừ `vision.md`, `docs/research/*` (đọc TL;DR đầu file trước), `prompt-spec.md`, `decisions-log.md`, `ROADMAP.md`.
- Truy vết cũ: `docs/journal/`, `docs/investigations/`. `ref/pvo/` là R2 — không đọc khi build R1.

## 4. Luật cứng

| Luật | Chi tiết |
|---|---|
| Không `unique` trên `vocab_items` | Chống trùng ở tầng extract (FR-10) |
| FSRS dùng thư viện | `swift-fsrs` pin `4fbaf20` + `FSRSDefaults.defaultWv6`; cấm tự viết, cấm `FSRS()` mặc định (v5) |
| FR-07 / FR-13 là bia mộ | Cấm implement, cấm xoá dòng bia mộ khỏi docs |
| Không ảnh trang vào SQLite | NFR-04 — chỉ segments JSON |
| Không lưu file PDF gốc | `pdf_sources` chỉ giữ bookmark + số trang (ADR-058) |
| Key API chỉ ở Keychain | Không ghi vào SQLite, plist, log |
| `cards.state` có 4 giá trị | `new`/`learning`/`review`/`relearning` |
| Chấm = 1 transaction | `UPDATE cards` + `INSERT review_logs` cùng transaction; log là snapshot TRƯỚC khi chấm |
| Timestamp, uuid | ISO-8601 UTC hậu tố `Z`; uuid TEXT có gạch; `fsrs_params` TEXT JSON |
| Logic ở ReadoKit | Không target test nào link app → logic tách được để ở ReadoKit; view chỉ giữ state SwiftUI |
| Không thêm dependency | Trừ khi thật cần và fen xác nhận |

## 5. Đã chốt / còn mở

Nguồn duy nhất cho "đã chốt chưa"; command và agent không chép lại. Doc khác ghi khác → doc kia lệch, báo fen.

Q-01 iOS native · Q-02 SQLite local · Q-06 không lemmatize · Q-08 "đã thuộc" = `stability >= 21` · Q-10 giữ 10 phiên đọc mỗi collection có tên · Q-12 tắt steps · FR-19 leech = 6 lần Again (không gộp Q-08).

| Mục | Đã chốt | ADR |
|---|---|---|
| Q-03 | AI chỉ BYOK + Apple Intelligence (R1 chỉ on-device); không proxy | 049, 063 |
| Q-09 | FR-10 so khớp toàn app, không theo collection (kèm D1–D4) | 066 |
| Q-13 | Từ khớp khoá đã thuộc gập vào nhóm riêng, không xoá | 056 |
| FR-23 | PDF đọc tại chỗ, ≤ 1 PDF mỗi bộ có tên; lớp chữ trước, OCR khi rác/scan; EPUB ngoài | 058 |
| FR-02 | OCR `liveText`; không có bước soát OCR bằng LLM | 064, 065 |
| FR-24 | Gộp từ trùng: fen duyệt từng nhóm, giữ thẻ tiến bộ nhất, không tự động | 067 |

**Mở — phải hỏi fen:** Q-11 (jitter hai chế độ R2, chốt trước Phase 4).

## 6. Xử lý mơ hồ

1. Chiếu vào 6 nguyên lý `docs/specs/vision.md` (mục "Chống lại").
2. Kiểm non-goals NG-01..09 và §5. Dòng đã chốt có vẻ sai → báo fen, không tự sửa.
3. Còn mơ hồ và đụng dữ liệu/lịch ôn → hỏi fen. Thiếu hợp đồng → `/rplan` hoặc hỏi, không tự lấp.
4. Chỉ là chi tiết hiển thị → chọn cách đơn giản nhất, ghi lại lựa chọn.

Fen nhắc một công nghệ ("dùng X để…") là giả thuyết, không phải quyết định: nêu vấn đề gốc, so ≥ 2 phương án (kể cả không làm) rồi mới hỏi chốt. Idea thô → `/ridea`.

## 7. Cách làm việc

**Workflow**
- Idea thô → `/ridea`. Fen chốt hướng → `/rplan`. Đầu session → `/rstart`.
- Task nhỏ (bug UI, copy, test bổ sung khi FR/journey đã chốt) → code luôn, nói một câu vì sao skip plan.
- Đụng hợp đồng (schema, FR mới, transaction, protocol module, Q mở) → `/rplan`, fen confirm rồi mới code.
- Mỗi session một task trong "Tầng 2" của plan. Xong → `/rhandoff`; context dài → `/rhandoff` rồi `/clear`.
- Commit chỉ sau khi fen approve; format: `docs/agent/coding-conventions.md` §7b.
- Không build/test được (cloud, simulator hỏng) → không bịa số test, không ghi "xong".

**Bẫy môi trường**
- Simulator **iPhone Air**; `scripts/test.sh` tự boot. Treo > 10 phút → kill, báo fen chạy tay.
- TOCropViewController lấy từ SPM → build đầu cần mạng.
- `project.pbxproj` dùng synchronized folders (ADR-046): cấm sửa tay, cấm đọc nguyên. Thêm/xoá/chuyển file = tạo/xoá/`git mv` trong thư mục; đổi target, build setting, package → nhờ fen làm trong Xcode.
- Mọi file trong `app/` đều được compile, kể cả file chưa track → file nháp để ngoài `app/`.
- xcodebuild tự re-sort pbxproj → trước commit chỉ giữ hunk thật.
- Secret ở `.env`: không đọc, không grep đệ quy từ gốc repo; chỉ `.env.example` hợp lệ.
- Không `find` trần trên workspace (`.build/`, `DerivedData/`) — dùng Glob hoặc `git ls-files`.
````

### E2 — `app/ReadoKit/CLAUDE.md`

````markdown
# app/ReadoKit — đọc khi sửa package

Luật đầy đủ: `docs/agent/coding-conventions.md` §2–6, §8–9. Dưới đây là chỗ hay sai nhất.

- Kiểu của swift-fsrs không lọt ra API public — vào/ra qua `CardSnapshot`, `ReadoRating`, `ReviewOutcome`.
- Tham số FSRS luôn qua `ReadoFSRS.parameters(from:)`; cấm `FSRS()` trần.
- Chấm điểm đi qua `ReviewService.record` (một transaction, snapshot trước). Undo = xoá đúng dòng log vừa ghi + trả card về snapshot, cùng transaction.
- Thời gian qua `Clock`, "hôm nay" qua `DayBoundary.window(...)`. Cấm `Date()` trần trong logic, cấm `datetime('now')` trong SQL.
- Timestamp qua `ISOTimestamp`. `ISO8601FormatStyle()` trần không parse được — phải compose đủ field.
- `COLLATE NOCASE` chỉ gập ASCII — gập tiếng Việt ở tầng Swift (FR-20).
- Lane `kit` chạy macOS, ghi vào `~/Documents` thật: class nào chạm `DebugTrace` phải set `DebugTrace.documentsDirectoryOverride` sang thư mục tạm ở `setUp`/`tearDown`.

## Đổi schema (khi đã có plan fen confirm)

1. Thêm `case N:` mới trong `Migration.run` (nâng N → N+1) và tăng `currentVersion`. **Không sửa case cũ** — DB đã ở version cao hơn sẽ không bao giờ chạy lại nó.
2. Cập nhật DDL ở `docs/specs/db.md`.
3. Test nâng cấp từ version cũ trong `MigrationAndSeedTests` bằng `Migration.run(on:upTo:)`.
4. Bảng/cột mới có vào export (FR-16) không: quyết, ghi vào `db.md`; nếu có thì sửa `ExportService` + `ExportTests`.
````

### E3 — `.claude/skills/reado-diagnostics/SKILL.md`

````markdown
---
name: reado-diagnostics
description: Đọc log chẩn đoán DebugTrace (ADR-037) khi kết quả OCR hoặc phân tích trên máy thật/simulator bị sai — ngắt đoạn lạ, mất dòng, model trả rác, lỗi phân tích — hoặc khi cần so prompt mới với prompt đang chạy. Dùng khi fen nói đã cắm máy / mở simulator, gửi ảnh kết quả sai, hoặc hỏi vì sao một trang ra như vậy.
---

# Reado diagnostics

Log chỉ có khi app build DEBUG (fen bấm Run trong Xcode là Debug). Ngoại lệ NFR-04 chỉ áp cho log này.

## Kéo về và đọc
1. Simulator đang boot: `scripts/pull_diagnostics.sh sim`.
   Máy thật: `scripts/pull_diagnostics.sh device` lần đầu chỉ in danh sách máy rồi thoát — chạy lại với `scripts/pull_diagnostics.sh device <udid>`.
2. Script in ra thư mục `.tmp/diagnostics/<ts>/`. Đọc tóm tắt trước: `python3 scripts/diag_summary.py <thư mục>` (thêm `--full` khi cần segment/vocab).
3. Không mở thẳng `events.jsonl` / `analysis.json`; cần chi tiết thì grep đúng analysis id.

Mỗi lần phân tích là một thư mục `analyses/<id>/` (ảnh, OCR, từng hàng kèm lý do ngắt đoạn, response, lỗi). App giữ 30 lần gần nhất.

## So prompt
`python3 scripts/prompt_eval.py --diagnostics .tmp/diagnostics/<ts> --prompt scripts/prompts/v5.txt --prompt app/ReadoKit/Sources/ReadoKit/Analysis/Prompt.swift`
- Output Markdown ở `.tmp/prompt-eval/` để fen chấm cạnh nhau. Không commit (bản quyền sách).
- Script tự đọc key trong `.env`; agent không tự mở `.env`.
- Hiện chỉ eval được `Prompt.text`, chưa eval được `Prompt.pdfText`.

## Báo lại
Nêu analysis id + bằng chứng (dòng nào, lý do ngắt). Ngưỡng ngắt đoạn: ADR-037; engine OCR: ADR-064. Đổi prompt là đụng hợp đồng → `/rplan` (`docs/agent/prompt-spec.md`).
````

### E4 — `.claude/skills/reado-ui/SKILL.md`

````markdown
---
name: reado-ui
description: Dùng khi sửa hoặc thêm SwiftUI view trong app/Reado/** — luật UI (MASTER), gotcha đã gặp, và cách verify bằng ảnh chụp simulator. Không dùng cho ReadoKit, test hay docs.
paths: app/Reado/**/*.swift
---

# Reado UI

## Luật
Đọc `design-system/reado/MASTER.md` trước khi sửa. MASTER ghi tên token; giá trị nằm ở `app/Reado/Shared/DesignSystem.swift` và `app/Reado/App/ReadoApp.swift`.

## Gotchas
- **ShellTabBar che cuối màn.** Root mỗi tab tự có khe; màn push qua `navigationDestination` thì không → gắn `.shellScrollChrome()` lên đúng `ScrollView`/`List` gốc của màn (đã gồm padding + ẩn/hiện thanh khi cuộn, `App/ShellChrome.swift`). Không gọi `.safeAreaPadding` tay, không cộng thêm `height`.
- **`UIViewRepresentable` nuốt chiều cao sibling** (vd `PDFView` + thanh "Tr. N/M"): dùng `VStack(spacing: 0) { representable.frame(maxWidth: .infinity, maxHeight: .infinity); thanh }`. Dò bằng cách tạm tô nền thanh `Color.red` rồi chụp (`PDF/PDFReaderView.swift`).
- **`Button` nuốt chạm link trong `Text`** → dùng `.onTapGesture`; link đi qua `openURL` (`EncounterText.swift`).
- **Thẻ giật đầu kéo:** `DragGesture(minimumDistance: 20)` cho `translation` ~20pt ở lần `onChanged` đầu → neo `dragAnchor` rồi trừ (`ReviewQueueView+Card.swift`).
- **Alert không hiện dưới sheet** → `.appErrorAlert()` ở gốc mỗi `sheet`/`fullScreenCover` (`Shared/ErrorAlert.swift`).
- **Alert quyền camera kẹt trên simulator** (qua cả uninstall) → `xcrun simctl shutdown <udid>` rồi `scripts/sim_screens.sh --fresh`.
- **Ảnh đầu sau `open` có thể trắng** → `shot` lại lần 2 trước khi kết luận màn sai.

## Màn mới
Thêm case vào `DebugLaunch.Screen` để `sim_screens.sh open` tới thẳng được. Không có case thì màn đó luôn là "chưa xem tay".

## Verify trước khi báo xong
1. `scripts/test.sh build` xanh.
2. `scripts/sim_screens.sh open <màn> --no-build [--theme forest|sepia|indigo|system] [--fresh]`, rồi `scripts/sim_screens.sh shot after-<màn>`. Danh sách màn và cờ khác: header `scripts/sim_screens.sh`.
3. Đọc cả hai PNG light/dark trong `.tmp/screens/`, đối chiếu checklist cuối MASTER (accent thứ hai, Dynamic Type `accessibility-extra-large`, không bị ShellTabBar che, diff không có hex/số lẻ mới).
4. Màn `open` không tới được → ghi "chưa xem tay", không báo xong.
````
