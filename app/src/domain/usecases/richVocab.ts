/**
 * domain/usecases/richVocab.ts — task 3.12: user sửa 3 field rich vocab
 * (tags/synonyms/antonyms) của từ ĐÃ LƯU trong kho.
 *
 * Đường AI-sinh nằm ở analyze (verify.ts normalize) + save; đường sửa tay sau
 * khi đã vào kho nằm ở đây — usecase mỏng giữ ranh giới "UI không chạm repo"
 * (solution-design mục 3.1), toàn bộ SQL ở storage/repos/vocabItems.ts.
 */
import type { AppServices } from "../services"
import type { RichVocabFields } from "../types"

export interface UpdateRichFieldsInput {
  vocabItemId: string
  fields: RichVocabFields
}

export async function updateVocabRichFields(
  svc: AppServices,
  input: UpdateRichFieldsInput,
): Promise<void> {
  await svc.repos.vocabItems.updateRichFields(input.vocabItemId, input.fields)
}
