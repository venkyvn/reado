# evidence.sh — dùng chung cho test.sh (ghi) và hook session-context.sh (so). Chỉ source, không chạy trực tiếp.

# code_tree <repo-root> — tree hash của app/. Băm cả file chưa track (Xcode compile cả chúng);
# sửa docs sau khi test không làm lệch. Dùng index tạm nên không đụng index thật.
code_tree() {
  ( cd "$1" || exit 1
    idx="$(mktemp -u)"
    GIT_INDEX_FILE="$idx" git add -A -- app >/dev/null 2>&1
    GIT_INDEX_FILE="$idx" git write-tree
    rm -f "$idx" )
}
