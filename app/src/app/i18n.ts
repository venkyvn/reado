/**
 * i18n.ts — khởi tạo i18next + react-i18next (ADR-018: setup NỀN TẢNG).
 *
 * Tiếng Việt là default và là ngôn ngữ duy nhất hiện tại — việc tách strings ra
 * `locales/vi.json` là để sau này thêm ngôn ngữ khác chỉ cần thêm file, KHÔNG
 * phải gỡ chữ khỏi component. Chỉ UI copy được dịch; dữ liệu người dùng thuộc
 * về ngôn ngữ nó được sinh ra (meaning_vi/translation_vi... KHÔNG qua i18next).
 *
 * Nguồn strings chưa dịch hết: chỉ HomeScreen là màn ví dụ đã tách. Các màn
 * khác vẫn giữ chữ tiếng Việt trong component cho tới khi cần đa ngôn ngữ thật.
 */
import i18n from "i18next"
import { initReactI18next } from "react-i18next"
import vi from "../i18n/locales/vi.json"

void i18n.use(initReactI18next).init({
  resources: { vi: { translation: vi } },
  lng: "vi",
  fallbackLng: "vi",
  interpolation: { escapeValue: false },
  // Resources nằm sẵn trong bundle → init đồng bộ, không có khoảng "chưa sẵn
  // sàng" lúc render đầu (useTranslation không trả về key thô).
  initAsync: false,
})

export default i18n
