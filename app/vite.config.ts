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
const coiHeaders = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
}

export default defineConfig({
  optimizeDeps: {
    // sqlite-wasm tự quản wasm loader của nó — prebundle làm gãy locateFile.
    exclude: ['@sqlite.org/sqlite-wasm'],
  },
  server: { headers: coiHeaders },
  preview: { headers: coiHeaders },
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