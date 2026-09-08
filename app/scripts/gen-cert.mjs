#!/usr/bin/env node
/**
 * scripts/gen-cert.mjs — sinh chứng chỉ TỰ KÝ cho dev/preview server HTTPS.
 *
 * Vì sao tự sinh bằng openssl thay vì @vitejs/plugin-basic-ssl: plugin nhận
 * option `domains` nhưng nhét hết vào SAN kiểu DNS (type 2) — IP LAN ghi kiểu
 * đó là cert sai chuẩn x509, trình duyệt có quyền từ chối. Ở đây IP LAN được
 * ghi ĐÚNG kiểu (SAN type 7 — IP) nên không còn cảnh báo "sai tên miền" chồng
 * lên "chứng chỉ chưa tin cậy".
 *
 * Cert này CHỈ để dev (owner test iPhone qua LAN). Nó vẫn là chứng chỉ tự ký
 * nên iOS/Chrome hỏi chấp nhận MỘT lần — không dùng cho production, không
 * commit vào git (đã gitignore certs/).
 *
 * IP LAN đổi (router cấp lại lease) → chạy lại `npm run cert`. DNS:localhost và
 * IP:127.0.0.1 luôn có sẵn trong cert.
 */
import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { networkInterfaces } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const certsDir = path.join(here, "..", "certs");
const keyPath = path.join(certsDir, "dev-key.pem");
const certPath = path.join(certsDir, "dev-cert.pem");

/** Mọi IPv4 không phải loopback — máy có nhiều card thì vào hết, vô hại. */
function lanIpv4s() {
  const ips = [];
  for (const infos of Object.values(networkInterfaces())) {
    for (const info of infos ?? []) {
      if (info.family === "IPv4" && !info.internal) ips.push(info.address);
    }
  }
  return ips;
}

const ips = lanIpv4s();
if (ips.length === 0) {
  console.error("Không tìm thấy IPv4 LAN nào (networkInterfaces trống) — kiểm tra mạng.");
  process.exit(1);
}

const san = `subjectAltName=DNS:localhost,IP:127.0.0.1,${ips.map((ip) => `IP:${ip}`).join(",")}`;
mkdirSync(certsDir, { recursive: true });

execFileSync(
  "openssl",
  [
    "req",
    "-x509",
    "-newkey",
    "rsa:2048",
    "-keyout",
    keyPath,
    "-out",
    certPath,
    "-days",
    "825",
    "-nodes",
    "-sha256",
    "-subj",
    "/CN=Reado dev (LAN)",
    "-addext",
    san,
  ],
  { stdio: "inherit" },
);

// Tự kiểm tra: cert vừa sinh phải chứa đúng từng IP dự định — fail loud, không tin mù.
const text = execFileSync("openssl", ["x509", "-in", certPath, "-noout", "-text"], {
  encoding: "utf8",
});
const missing = ips.filter((ip) => !text.includes(`IP Address:${ip}`));
if (missing.length > 0) {
  console.error(`Cert sinh xong nhưng THIẾU SAN cho: ${missing.join(", ")} — bất thường, không tính là thành công.`);
  process.exit(1);
}

console.log(`✅ dev-cert.pem đã sinh tại ${certsDir}/`);
console.log(`   SAN: DNS:localhost, ${ips.map((ip) => `IP:${ip}`).join(", ")}`);
console.log("   URL cho iPhone: https://<IP này>:5174/ — chấp nhận cảnh báo chứng chỉ MỘT lần.");
console.log("   IP LAN đổi thì chạy lại: npm run cert");