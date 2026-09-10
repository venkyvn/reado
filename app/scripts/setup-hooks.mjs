/**
 * scripts/setup-hooks.mjs — trỏ git về thư mục hook `app/.husky`.
 *
 * Husky sống trong app/ (package.json nằm ở app/, không phải repo root), mà
 * lệnh `husky` trong prepare mặc định đặt `core.hooksPath=.husky` — thành ra
 * hook bị trơ trên fresh clone. Script này chạy NGAY SAU husky trong prepare
 * để sửa lại thành `app/.husky` (đường dẫn tương đối được git resolve từ thư
 * mục gốc repo — nơi mọi lệnh git thường chạy).
 *
 * Không nằm trong repo git (npm install một bản copy không có .git) thì bỏ qua
 * im lặng — hook vô nghĩa khi không có git.
 */
import { execFileSync } from "node:child_process"

try {
  execFileSync("git", ["config", "core.hooksPath", "app/.husky"], { stdio: "ignore" })
} catch {
  // Không phải working tree git — không có gì để gắn hook.
}