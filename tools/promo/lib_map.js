// Pustaka peta ilustrasi (dikongsi oleh enjin video). Diekstrak daripada scenes.html.
'use strict';
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const lerp = (a, b, t) => a + (b - a) * t;
const sstep = (a, b, x) => { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); };
const eio = t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
const eout = t => 1 - Math.pow(1 - clamp(t), 3);
const eback = t => { t = clamp(t); const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); };
const hash = (i, j, s) => { let h = Math.imul(i | 0, 374761393) ^ Math.imul(j | 0, 668265263) ^ Math.imul(s | 0, 2246822519); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };


let LAT0, LNG0, MX, MY;
const ll = (lat, lng) => [(lng - LNG0) * MX, (lat - LAT0) * MY];
// ───────────────────────── geometri laluan ─────────────────────────
function chaikin(pts, n) { for (let r = 0; r < n; r++) { const o = [pts[0]]; for (let i = 0; i < pts.length - 1; i++) { const a = pts[i], b = pts[i + 1]; o.push([.75 * a[0] + .25 * b[0], .75 * a[1] + .25 * b[1]], [.25 * a[0] + .75 * b[0], .25 * a[1] + .75 * b[1]]); } o.push(pts[pts.length - 1]); pts = o; } return pts; }
function withCum(pts) { const c = [0]; for (let i = 1; i < pts.length; i++) c.push(c[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1])); return { pts, cum: c, len: c[c.length - 1] }; }
function atAlong(r, s) { s = clamp(s, 0, r.len); let lo = 0, hi = r.cum.length - 1; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (r.cum[m] <= s) lo = m; else hi = m; } const t = (s - r.cum[lo]) / Math.max(1e-6, r.cum[hi] - r.cum[lo]); const a = r.pts[lo], b = r.pts[hi]; return { x: lerp(a[0], b[0], t), y: lerp(a[1], b[1], t), brg: Math.atan2(b[0] - a[0], b[1] - a[1]) }; }
let NAV, OV;                                    // laluan nav resolusi penuh & laluan gambaran keseluruhan
function buildGeo() {
  NAV = withCum(chaikin(HEAD.points.map(p => ll(p[0], p[1])), 2));
  // bearing kamera: purata arah di hadapan, ditapis supaya kamera ketinggalan sedikit (seperti app sebenar).
  const step = 4, n = Math.floor(NAV.len / step);
  NAV.camBrg = []; NAV.carBrg = [];
  let cb = atAlong(NAV, 0).brg;
  for (let i = 0; i <= n; i++) {
    const s = i * step; const a = atAlong(NAV, s), b = atAlong(NAV, s + 45);
    let tgt = Math.atan2(b.x - a.x, b.y - a.y);
    let d = tgt - cb; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI;
    cb += d * 0.14;
    NAV.camBrg.push(cb); NAV.carBrg.push(a.brg);
  }
  OV = ROUTES.map(r => withCum(r.points.map(p => ll(p[0], p[1]))));
}
function navState(s) {
  const i = clamp(s / 4, 0, NAV.camBrg.length - 1), i0 = Math.floor(i), i1 = Math.min(NAV.camBrg.length - 1, i0 + 1), f = i - i0;
  const p = atAlong(NAV, s);
  let cb = lerp(NAV.camBrg[i0], NAV.camBrg[i1], f);
  const a = atAlong(NAV, s + 30), b = atAlong(NAV, s + 8);
  const carB = Math.atan2(b.x - p.x, b.y - p.y);
  let yaw = carB - cb; while (yaw > Math.PI) yaw -= 2 * Math.PI; while (yaw < -Math.PI) yaw += 2 * Math.PI;
  return { x: p.x, y: p.y, cam: cb, yawDeg: yaw * 180 / Math.PI };
}
function hudIndex(s) { let best = 0, bd = 1e9; for (let i = 0; i < TRACK.length; i++) { const d = Math.abs(TRACK[i].alongM - s); if (d < bd) { bd = d; best = i; } } return TRACK[best].k; }

// ───────────────────────── kamera perspektif & peta ilustrasi ─────────────────────────
const D_CAM = 1500;
function mkCam(fx, fy, brg, phiDeg, ppm, cx, cy) {
  const phi = phiDeg * Math.PI / 180;
  return { fx, fy, sT: Math.sin(brg), cT: Math.cos(brg), sp: Math.sin(phi), cp: Math.cos(phi), b: D_CAM * Math.cos(phi), hc: D_CAM * Math.sin(phi), F: ppm * D_CAM, cx, cy, ppm, phi, brg };
}
function pr(cam, x, y) {                        // dunia -> skrin; z<=0 bermakna di belakang kamera
  const dx = x - cam.fx, dy = y - cam.fy;
  const fwd = dx * cam.sT + dy * cam.cT, rgt = dx * cam.cT - dy * cam.sT;
  const f = fwd + cam.b;
  const yc = f * cam.sp - cam.hc * cam.cp, z = f * cam.cp + cam.hc * cam.sp;
  return [cam.cx + cam.F * rgt / z, cam.cy - cam.F * yc / z, z];
}
const NEAR = 40;
function clipSeg(cam, ax, ay, bx, by) {
  let A = pr(cam, ax, ay), B = pr(cam, bx, by);
  if (A[2] < NEAR && B[2] < NEAR) return null;
  if (A[2] < NEAR || B[2] < NEAR) {
    const t = (NEAR - A[2]) / (B[2] - A[2]);
    const mx = ax + (bx - ax) * t, my = ay + (by - ay) * t, M = pr(cam, mx, my);
    if (A[2] < NEAR) A = M; else B = M;
  }
  return [A, B];
}
const PAL = {
  light: { block: '#E3E8F1', land: '#EEF1F6', road: '#FFFFFF', cas: '#D6DDEA', park: '#CDE8D4', water: '#B7D6F0', fog: '#E9EDF5', sky: '#DCE6F7', routeCas: '#FFFFFF', pass: 'rgba(25,211,184,.35)', text: '#10244A', pillBg: '#FFFFFF' },
  dark: { block: '#122038', land: '#0F1A2E', road: '#243653', cas: '#0B1424', park: '#10302F', water: '#0D2A4D', fog: '#0F1A2E', sky: '#0A1326', routeCas: '#081022', pass: 'rgba(25,211,184,.3)', text: '#EAF1FF', pillBg: '#16233D' }
};
const ROT = 0.34, cR = Math.cos(ROT), sR = Math.sin(ROT);
const toUV = (x, y) => [x * cR + y * sR, -x * sR + y * cR];
const fromUV = (u, v) => [u * cR - v * sR, u * sR + v * cR];
const LAYERS = [{ C: 90, w: .07, skip: .24, seed: 1 }, { C: 360, w: .09, skip: .15, seed: 2 }, { C: 1500, w: .1, skip: .1, seed: 3 }, { C: 6000, w: .09, skip: .05, seed: 4 }];

function drawMap(ctx, w, h, cam, pal, opt = {}) {
  ctx.save();
  ctx.fillStyle = pal.land; ctx.fillRect(0, 0, w, h);
  const horizon = cam.cy - cam.F * Math.tan(cam.phi);
  const view = Math.hypot(w, h) / cam.ppm;
  const R = Math.min(view * 0.95 / Math.max(Math.sin(cam.phi), .42), 9e5);
  const [fu, fv] = toUV(cam.fx, cam.fy);
  const poly = pts => { ctx.beginPath(); let ok = true; for (const p of pts) { const q = pr(cam, p[0], p[1]); if (q[2] < NEAR) { ok = false; break; } ctx.lineTo(q[0], q[1]); } if (ok) ctx.closePath(); return ok; };
  // taman & air (blok besar, mengikut grid berputar)
  for (const lay of [LAYERS[1], LAYERS[2], LAYERS[3]]) {
    const cpx = lay.C * cam.ppm; if (cpx < 10 || cpx > 900) continue;
    const a = clamp((cpx - 10) / 14);
    const i0 = Math.floor((fu - R) / lay.C), i1 = Math.ceil((fu + R) / lay.C), j0 = Math.floor((fv - R) / lay.C), j1 = Math.ceil((fv + R) / lay.C);
    if ((i1 - i0) * (j1 - j0) > 2600) continue;
    ctx.globalAlpha = a;
    for (let i = i0; i < i1; i++) for (let j = j0; j < j1; j++) {
      const hv = hash(i, j, lay.seed * 31);
      if (hv < .9 || (hv > .965 && lay.C < 1500)) continue;
      const wet = hv > .965 && lay.C >= 1500;
      const ins = lay.C * (.06 + .1 * hash(i, j, 7));
      const c = [[i * lay.C + ins, j * lay.C + ins], [(i + 1) * lay.C - ins, j * lay.C + ins], [(i + 1) * lay.C - ins, (j + 1) * lay.C - ins], [i * lay.C + ins, (j + 1) * lay.C - ins]].map(p => fromUV(p[0], p[1]));
      if (poly(c)) { ctx.fillStyle = wet ? pal.water : pal.park; ctx.fill(); }
    }
  }
  ctx.globalAlpha = 1;
  // sungai
  { const wpx = 150 * cam.ppm; if (wpx > 1.4) {
    ctx.strokeStyle = pal.water; ctx.lineWidth = clamp(wpx, 2, 60); ctx.lineJoin = 'round'; ctx.lineCap = 'round'; ctx.beginPath(); let pen = false;
    const st = 90 / Math.max(.2, Math.min(1, cam.ppm * 40));
    for (let u = fu - R; u <= fu + R; u += Math.max(80, st)) { const v = 2600 * Math.sin(u / 3900) + 900 * Math.sin(u / 1300 + 1.3) + 7200; const [x, y] = fromUV(u, v); const q = pr(cam, x, y); if (q[2] < NEAR) { pen = false; continue; } if (!pen) { ctx.moveTo(q[0], q[1]); pen = true; } else ctx.lineTo(q[0], q[1]); }
    ctx.stroke(); } }
  // blok bangunan (tekstur bandar) pada skala jalan kecil
  { const lay = LAYERS[0], cpx = lay.C * cam.ppm;
    if (cpx >= 26 && cpx < 700) {
      const i0 = Math.floor((fu - R) / lay.C), i1 = Math.ceil((fu + R) / lay.C), j0 = Math.floor((fv - R) / lay.C), j1 = Math.ceil((fv + R) / lay.C);
      if ((i1 - i0) * (j1 - j0) <= 3400) {
        ctx.globalAlpha = clamp((cpx - 26) / 20); ctx.fillStyle = pal.block;
        for (let i = i0; i < i1; i++) for (let j = j0; j < j1; j++) {
          if (hash(i, j, 11) < .42) continue; const ins = lay.C * .16;
          const c = [[i * lay.C + ins, j * lay.C + ins], [(i + 1) * lay.C - ins, j * lay.C + ins], [(i + 1) * lay.C - ins, (j + 1) * lay.C - ins], [i * lay.C + ins, (j + 1) * lay.C - ins]].map(p => fromUV(p[0], p[1]));
          if (poly(c)) ctx.fill();
        }
        ctx.globalAlpha = 1;
      }
    } }
  // jalan: lapisan ikut skala
  for (const lay of LAYERS) {
    const cpx = lay.C * cam.ppm; if (cpx < 14) continue;
    const a = clamp((cpx - 14) / 16) * (1 - clamp((cpx - 700) / 500));
    if (a <= 0.01) continue;
    const i0 = Math.floor((fu - R) / lay.C), i1 = Math.ceil((fu + R) / lay.C), j0 = Math.floor((fv - R) / lay.C), j1 = Math.ceil((fv + R) / lay.C);
    if ((i1 - i0) * (j1 - j0) > 3400) continue;
    const wpx = clamp(cpx * lay.w, 1.1, 6);
    const paths = [new Path2D(), new Path2D()];
    for (let i = i0; i <= i1; i++) for (let j = j0; j < j1; j++) {
      if (hash(i, j, lay.seed) < lay.skip) continue;
      const ju = i * lay.C + (hash(i, 3, lay.seed + 9) - .5) * lay.C * .25;
      const jv = j * lay.C + (hash(3, j, lay.seed + 5) - .5) * lay.C * .25;
      const s1 = (() => { const [ax, ay] = fromUV(ju, j * lay.C), [bx, by] = fromUV(ju, (j + 1) * lay.C); return clipSeg(cam, ax, ay, bx, by); })();
      if (s1) { paths[0].moveTo(s1[0][0], s1[0][1]); paths[0].lineTo(s1[1][0], s1[1][1]); }
      if (hash(j, i, lay.seed + 77) >= lay.skip) {
        const [ax, ay] = fromUV(i * lay.C, jv), [bx, by] = fromUV((i + 1) * lay.C, jv);
        const s2 = clipSeg(cam, ax, ay, bx, by); if (s2) { paths[1].moveTo(s2[0][0], s2[0][1]); paths[1].lineTo(s2[1][0], s2[1][1]); }
      }
    }
    ctx.globalAlpha = a; ctx.lineCap = 'round';
    for (const pass of [0, 1]) {
      ctx.strokeStyle = pass === 0 ? pal.cas : pal.road; ctx.lineWidth = pass === 0 ? wpx + 2.2 : wpx;
      ctx.stroke(paths[0]); ctx.stroke(paths[1]);
    }
  }
  ctx.globalAlpha = 1;
  // kabus & langit di ufuk
  if (cam.phi < 1.45) {
    const hy = horizon;
    const fogH = Math.max(120, (cam.cy - hy) * .5);
    if (hy > -10) {
      ctx.fillStyle = pal.sky; ctx.fillRect(0, 0, w, Math.max(0, hy));
    }
    const g = ctx.createLinearGradient(0, Math.max(-5, hy - 4), 0, Math.max(-5, hy) + fogH);
    g.addColorStop(0, pal.fog); g.addColorStop(1, pal.fog + '00');
    ctx.fillStyle = g; ctx.fillRect(0, Math.max(-5, hy - 4), w, fogH + 8);
    if (hy > 30) { const g2 = ctx.createLinearGradient(0, 0, 0, hy); g2.addColorStop(0, pal.sky); g2.addColorStop(1, pal.fog); ctx.fillStyle = g2; ctx.fillRect(0, 0, w, hy); }
  }
  ctx.restore();
}

// Garisan laluan dengan lebar bersandar kedalaman. pts = [[x,y]...]; range [s0,s1] ikut jarak kumulatif.
function strokeRoute(ctx, cam, r, s0, s1, wpx, color, alpha = 1, cap = 'round') {
  ctx.save(); ctx.strokeStyle = color; ctx.globalAlpha = alpha; ctx.lineCap = cap; ctx.lineJoin = 'round';
  const zf = D_CAM;
  for (let i = 1; i < r.pts.length; i++) {
    if (r.cum[i] < s0 || r.cum[i - 1] > s1) continue;
    let a = r.pts[i - 1], b = r.pts[i], ca = r.cum[i - 1], cb = r.cum[i];
    let ax = a[0], ay = a[1], bx = b[0], by = b[1];
    if (ca < s0) { const t = (s0 - ca) / (cb - ca); ax = lerp(a[0], b[0], t); ay = lerp(a[1], b[1], t); }
    if (cb > s1) { const t = (s1 - ca) / (cb - ca); bx = lerp(a[0], b[0], t); by = lerp(a[1], b[1], t); }
    const sg = clipSeg(cam, ax, ay, bx, by); if (!sg) continue;
    const zm = (sg[0][2] + sg[1][2]) / 2;
    ctx.lineWidth = Math.max(1.2, wpx * zf / zm);
    ctx.beginPath(); ctx.moveTo(sg[0][0], sg[0][1]); ctx.lineTo(sg[1][0], sg[1][1]); ctx.stroke();
  }
  ctx.restore();
}

