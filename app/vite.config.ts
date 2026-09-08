import fs from 'node:fs'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { VitePWA } from 'vite-plugin-pwa'

// https://vite.dev/config/
// PWA: manifest + service worker precache shell — mở được offline (NFR-03, task 1.3).
//
// COOP/COEP headers (dev + preview): SQLite-WASM cần SharedArrayBuffer cho VFS
// "opfs" (solution-design mục 4.1) — sqlite-wasm tự kiểm crossOriginIsolated.
// Lưu ý: khi deploy production phải cấu hình header này ở phía host — ghi chú
// trong MVP_PLAN (SPIKE storage). COEP require-corp chỉ ảnh hưởng nếu app load
// tài nguyên cross-origin; Reado R1 không load gì ngoài shell.
//
// HTTPS chỉ bật khi READO_HTTPS=1 (`npm run dev:https` / `preview:https`) — để
// phục vụ test trên iPhone: trang mở qua http:// + IP LAN KHÔNG phải secure
// context, mà OPFS lẫn Service Worker đều đòi secure context (đo thật
// 2026-09-08, xem MVP_PLAN mục 6). Cert tự sinh bằng `npm run cert`, SAN ghi
// IP LAN đúng chuẩn x509 (xem scripts/gen-cert.mjs vì sao không dùng plugin).
const coiHeaders = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
}

const useHttps = process.env.READO_HTTPS === '1'

function httpsCerts(): { key: Buffer; cert: Buffer } {
  const certPath = 'certs/dev-cert.pem'
  const keyPath = 'certs/dev-key.pem'
  if (!fs.existsSync(certPath) || !fs.existsSync(keyPath)) {
    throw new Error(
      `READO_HTTPS=1 nhưng thiếu ${certPath}/${keyPath} — chạy \`npm run cert\` trước. ` +
        `(thư mục certs/ không commit vào git vì SAN chứa IP LAN thay đổi theo mạng.)`,
    )
  }
  return { key: fs.readFileSync(keyPath), cert: fs.readFileSync(certPath) }
}

export default defineConfig({
  optimizeDeps: {
    // sqlite-wasm tự quản wasm loader của nó — prebundle làm gãy locateFile.
    exclude: ['@sqlite.org/sqlite-wasm'],
  },
  server: { headers: coiHeaders, ...(useHttps ? { https: httpsCerts() } : {}) },
  preview: { headers: coiHeaders, ...(useHttps ? { https: httpsCerts() } : {}) },
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      injectRegister: 'script',
      manifest: {
        name: 'Reado',
        short_name: 'Reado',
        description:
          'Học tiếng Anh từ sách thật: ảnh trang sách thành song ngữ + từ vựng ôn tập cách quãng (FSRS).',
        theme_color: '#0f172a',
        background_color: '#f8fafc',
        display: 'standalone',
        start_url: '.',
        lang: 'vi',
        icons: [
          // Tạm: icon chữ R (SVG). Icon thương hiệu thật + apple-touch-icon (PNG)
          // sẽ thay sau — việc nhỏ, chưa cần owner quyết.
          { src: '/icon.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any' },
        ],
      },
      workbox: {
        navigateFallback: 'index.html',
      },
    }),
  ],
})