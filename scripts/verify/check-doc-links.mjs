#!/usr/bin/env node
// Kiểm tra link markdown + anchor trong FILE SỐNG (root *.md + docs/ trừ
// journal/). Quy ước v2 (2026-09-19): link nội bộ viết gốc-repo
// `docs/...` — resolve gốc-repo trước, fallback file-relative.
// Loại khỏi quét (snapshots đóng băng theo plan tái cấu trúc):
// docs/journal/ ref/ design-system/ .agents/
// Cách chạy: node scripts/verify/check-doc-links.mjs
// Exit 1 nếu có link/anchor hỏng. Reference-style link chỉ cảnh báo.
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.argv[2] || '.');
const FROZEN = new Set(['journal', 'ref', 'design-system']);

function frozenParts(relParts) {
  return relParts.some((p) => FROZEN.has(p));
}

function walk(dir, acc = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ent.name.startsWith('.') && ent.name !== '.') continue; // bỏ .git/.agents/...
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, acc);
    else if (ent.name.toLowerCase().endsWith('.md')) acc.push(p);
  }
  return acc;
}

const files = walk(ROOT).filter(
  (f) => !frozenParts(path.relative(ROOT, f).split(path.sep))
);
const slugCache = new Map();

// GitHub-style anchor slug: lowercase, chỉ giữ chữ/số/space/-/_, mỗi space -> '-'
// (giữ '--' sinh bởi dấu gạch ngang; heading trùng lặp đánh thêm -1, -2 ...).
function slugify(text) {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s\-_]/gu, '')
    .replace(/\s/g, '-');
}

function headingAnchors(file) {
  if (slugCache.has(file)) return slugCache.get(file);
  const anchors = new Set();
  const counts = new Map();
  const content = fs.readFileSync(file, 'utf8');
  for (const line of content.split('\n')) {
    const m = /^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$/.exec(line);
    if (!m) continue;
    const base = slugify(m[1]) || 'section';
    const n = counts.get(base) || 0;
    counts.set(base, n + 1);
    anchors.add(n === 0 ? base : `${base}-${n}`);
  }
  slugCache.set(file, anchors);
  return anchors;
}

const problems = [];
const warnings = [];
const external = new Set();

for (const abs of files) {
  const rel = path.relative(ROOT, abs);
  const dir = path.dirname(abs);
  const lines = fs.readFileSync(abs, 'utf8').split('\n');
  let inFence = false;
  lines.forEach((line, i) => {
    if (line.trimStart().startsWith('```')) inFence = !inFence;
    for (const m of line.matchAll(/\[[^\]]*\]\(/g)) {
      if (inFence) continue; // link ví dụ trong code fence không quét
      if (m.index === undefined) continue;
      const openAt = m.index + m[0].length - 1;
      let depth = 1;
      let j = openAt + 1;
      let target = '';
      for (; j < line.length && depth > 0; j++) {
        if (line[j] === '(') depth++;
        else if (line[j] === ')') depth--;
        if (depth > 0) target += line[j];
      }
      if (depth !== 0) { problems.push(`${rel}:${i + 1}: ngoặc link không cân bằng`); continue; }
      const clean = target.replace(/^<|>$/g, '').trim();
      if (!clean || clean.includes('...')) continue; // "..." = ví dụ cú pháp, không phải link
      if (!clean || /^(https?:|mailto:|data:|javascript:|#)/.test(clean)) {
        if (/^https?:/.test(clean)) external.add(clean);
        continue;
      }
      let frag = '';
      const hash = clean.indexOf('#');
      let filePart = clean;
      if (hash >= 0) {
        filePart = clean.slice(0, hash);
        try { frag = decodeURIComponent(clean.slice(hash + 1)); }
        catch { frag = clean.slice(hash + 1); }
      }
      const noQuery = filePart.split('?')[0];
      if (!noQuery) {
        if (!headingAnchors(abs).has(frag)) {
          problems.push(`${rel}:${i + 1}: anchor "#${frag}" không có trong chính file`);
        }
        continue;
      }
      // Quy ước gốc-repo trước; fallback file-relative.
      let resolved = null;
      for (const base of [ROOT, dir]) {
        const p = path.resolve(base, noQuery);
        if (fs.existsSync(p)) { resolved = p; break; }
      }
      if (!resolved) {
        problems.push(`${rel}:${i + 1}: link hỏng → ${clean}`);
        continue;
      }
      if (fs.statSync(resolved).isDirectory()) continue;
      if (frag) {
        const anchors = headingAnchors(resolved);
        if (!anchors.has(frag)) {
          const near = [...anchors].filter((a) => a.includes(frag.slice(0, 12))).slice(0, 3);
          problems.push(
            `${rel}:${i + 1}: anchor "#${frag}" không có trong ${path.relative(ROOT, resolved)}` +
            (near.length ? ` (gần giống: ${near.map((n) => '#' + n).join(', ')})` : '')
          );
        }
      }
    }
    for (const m of line.matchAll(/\[\S+?\]\[([^\]]+)\]/g)) {
      if (inFence) continue;
      warnings.push(`${rel}:${i + 1}: reference-style link [${m[1]}] chưa kiểm tra (xem tay)`);
    }
  });
}

const allText = files.map((f) => fs.readFileSync(f, 'utf8')).join('\n');
const orphans = files
  .map((f) => path.relative(ROOT, f))
  .filter((rel) => rel === 'ROADMAP.md' || rel === 'README.md' || !allText.includes(path.basename(rel)))
  .filter((rel) => !['ROADMAP.md', 'README.md'].includes(rel));

console.log('== Số file md kiểm tra:', files.length, '==');
if (problems.length) {
  console.log('\n== PROBLEMS (' + problems.length + ') ==');
  for (const p of problems) console.log(' •', p);
} else {
  console.log('\n== Không có link nội bộ hỏng nào ==');
}
if (warnings.length) {
  console.log('\n== CẢNH BÁO reference-style (không tính exit) ==');
  for (const w of warnings) console.log(' ~', w);
}
console.log('\n== File mồ côi (không ai trỏ tới bằng basename; kiểm tra tay) ==');
for (const o of orphans) console.log(' •', o);
console.log('\n== External links (' + external.size + ') — KHÔNG verify mạng ==');
for (const u of [...external].sort()) console.log(' •', u);
process.exit(problems.length ? 1 : 0);