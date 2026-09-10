/**
 * domain/usecases/library.ts — FR-08 Vocabulary List.
 *
 * Mỏng vì repo đã làm phần SQL (join tên collection + card state, ba mức lọc,
 * thứ tự term-adjacent cho criterion 3). Use-case tồn tại để giữ ranh giới kiến
 * trúc "UI không chạm repo trực tiếp" và để sau này chèn logic domain vào đây
 * (ví dụ: quy tắc sắp xếp khi có FR-17) mà không phải mổ màn hình.
 */
import type { LibraryFilter } from "../repositories"
import type { LibraryItemRow } from "../types"
import type { AppServices } from "../services"

export function listLibrary(svc: AppServices, filter: LibraryFilter): Promise<LibraryItemRow[]> {
  return svc.repos.vocabItems.listLibrary(filter)
}
