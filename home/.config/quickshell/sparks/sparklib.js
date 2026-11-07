.pragma library
// Rigid HUD FX for sparks/shell.qml, built from the same pieces as the waybar:
//   trace    - blocky stair-step red line (right angles only) that runs along the window's side edges
//   brackets - small yellow corner brackets that blink in
//   ticks    - tiny cyan blocks beside the line
//   label    - small clipped-corner block above the window, text decrypts in letter by letter
// Right angles only, hugging the window edges. Nothing starts from or travels to the centre.

var RED = "255,31,61", YEL = "252,238,9", CYAN = "0,229,255", INK = "12,2,8";
var GLY = ["#", "%", "&", "@", "/", "0", "1", "7", "A", "F", "X"];

function rnd(a, b) { return a + Math.random() * (b - a); }
function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
function pick(a) { return a[Math.floor(Math.random() * a.length)]; }

// -------------------------------------------------------------- trace path --

// Blocky line from A to B (a vertical or horizontal edge): flat runs joined by right-angle steps,
// like the waybar's red line. Never a diagonal.
function stairPath(A, B) {
  var vert = Math.abs(B[1] - A[1]) > Math.abs(B[0] - A[0]);
  var len = vert ? Math.abs(B[1] - A[1]) : Math.abs(B[0] - A[0]);
  var dir = vert ? (B[1] > A[1] ? 1 : -1) : (B[0] > A[0] ? 1 : -1);
  var pts = [], pos = 0, off = 0, run, delta, next, i;
  function P(along, across) { return vert ? [A[0] + across, A[1] + dir * along] : [A[0] + dir * along, A[1] + across]; }
  pts.push(P(0, 0));
  while (pos < len) {
    run = Math.round(rnd(16, 56) / 2) * 2;
    pos = Math.min(len, pos + run);
    pts.push(P(pos, off));
    if (pos >= len) break;
    delta = (Math.random() < 0.5 ? -1 : 1) * (Math.random() < 0.5 ? 4 : 6);   // right-angle step
    next = clamp(off + delta, -8, 8);
    if (next === off) next = off - delta;
    off = next;
    pts.push(P(pos, off));
  }
  var cum = [0];
  for (i = 1; i < pts.length; i++)
    cum.push(cum[i - 1] + Math.abs(pts[i][0] - pts[i - 1][0]) + Math.abs(pts[i][1] - pts[i - 1][1]));
  return { pts: pts, cum: cum, total: cum[cum.length - 1] };
}

function trace(A, B, born, grow, hold, out, w) {
  var p = stairPath(A, B);
  p.born = born; p.grow = grow; p.hold = hold; p.out = out; p.w = w; p.life = grow + hold + out;
  return p;
}

// Stroke the part of path p between length a and length b.
function strokePart(ctx, p, a, b, dx, dy) {
  var i, started = false, t0, t1, f, x0, y0, x1, y1, ax, ay, bx, by;
  ctx.beginPath();
  for (i = 1; i < p.pts.length; i++) {
    t0 = p.cum[i - 1]; t1 = p.cum[i];
    if (t1 <= a || t0 >= b || t1 === t0) continue;
    x0 = p.pts[i - 1][0]; y0 = p.pts[i - 1][1]; x1 = p.pts[i][0]; y1 = p.pts[i][1];
    ax = x0; ay = y0; bx = x1; by = y1;
    if (a > t0) { f = (a - t0) / (t1 - t0); ax = x0 + (x1 - x0) * f; ay = y0 + (y1 - y0) * f; }
    if (b < t1) { f = (b - t0) / (t1 - t0); bx = x0 + (x1 - x0) * f; by = y0 + (y1 - y0) * f; }
    if (!started) { ctx.moveTo(ax + dx, ay + dy); started = true; }
    ctx.lineTo(bx + dx, by + dy);
  }
  ctx.stroke();
}

// ------------------------------------------------------------------ bursts --

var LABELS = {
  open: ["// ACCESS", "y"], close: ["// TERMINATED", "r"], float: ["// FLOAT", "y"],
  tile: ["// TILE", "y"], move: ["// RELOCATE", "r"], menu: ["// BREACH", "y"]
};

function burst(S, r, kind, now, extra) {
  if (!S.traces) { S.traces = []; S.ticks = []; S.brackets = []; S.labels = []; }
  if (!S.ghosts) S.ghosts = [];

  if (kind === "ghost") {                             // afterimage of a window while it is being dragged
    S.ghosts.push({ x: r.x, y: r.y, w: r.w, h: r.h, born: now, life: 210 });
    if (S.ghosts.length > 14) S.ghosts = S.ghosts.slice(-14);
    return;
  }
  if (kind === "ws") {                                // workspace swipe: lines sweep along the top and bottom of the screen
    var dir = extra && extra.dir ? extra.dir : -1;    // -1: sweep right to left, 1: left to right
    var sx0 = dir > 0 ? r.x : r.x + r.w, sx1 = dir > 0 ? r.x + r.w : r.x, k, tx;
    S.traces.push(trace([sx0, r.y + 3], [sx1, r.y + 3], now, 130, 90, 120, 2),
                  trace([sx0, r.y + r.h - 3], [sx1, r.y + r.h - 3], now + 30, 130, 90, 120, 2));
    for (k = 0; k < 6; k++) {
      tx = r.x + rnd(0.05, 0.95) * r.w;
      S.ticks.push({ x: Math.round(tx), y: Math.round((k % 2 ? r.y + 8 : r.y + r.h - 12) + rnd(-3, 3)), w: 6, h: 3,
                     born: now + rnd(0, 120), life: rnd(140, 280) });
    }
    S.labels.push({ text: (extra && extra.text) || "// WS", tone: "y", x: r.x + r.w / 2 - 60, y: r.y + 44, born: now, life: 400 });
    if (S.traces.length > 16) S.traces = S.traces.slice(-16);
    if (S.ticks.length > 60) S.ticks = S.ticks.slice(-60);
    if (S.labels.length > 8) S.labels = S.labels.slice(-8);
    return;
  }
  var x = r.x, y = r.y, w = r.w, h = r.h, i, life = 420, W = 2;
  var lx = x - 3, rx = x + w + 3;                     // lines hug the outside of the side edges
  var down = kind === "open" || kind === "float" || kind === "move" || kind === "menu";
  var left = [[lx, y], [lx, y + h]], right = [[rx, y], [rx, y + h]];
  var grow = kind === "close" ? 110 : 140, hold = kind === "close" ? 40 : 120, out = 130;
  if (kind === "close") life = 340;

  function side(e) {
    if (down) S.traces.push(trace(e[0], e[1], now, grow, hold, out, W));
    else S.traces.push(trace(e[1], e[0], now, grow, hold, out, W));       // close / tile: run upward
  }
  side(left);
  if (kind !== "move") side(right);

  S.brackets.push({ x: x, y: y, w: w, h: h, born: now, life: life, arm: clamp(Math.min(w, h) * 0.05, 10, 16) });

  var nt = kind === "move" ? 3 : 6, sx, t;
  for (i = 0; i < nt; i++) {                          // cyan blocks beside the side lines
    sx = (kind === "move" || Math.random() < 0.5) ? lx : rx;
    t = rnd(0.08, 0.92);
    S.ticks.push({ x: Math.round(sx + (sx === lx ? -rnd(5, 14) : rnd(5, 14)) - 3), y: Math.round(y + h * t), w: 6, h: 3,
                   born: now + rnd(0, 140), life: rnd(140, 280) });
  }

  var L = LABELS[kind] || LABELS.open;
  S.labels.push({ text: L[0], tone: L[1], x: x, y: y, born: now, life: life + 60 });

  if (S.traces.length > 16) S.traces = S.traces.slice(-16);
  if (S.ticks.length > 60) S.ticks = S.ticks.slice(-60);
  if (S.brackets.length > 8) S.brackets = S.brackets.slice(-8);
  if (S.labels.length > 8) S.labels = S.labels.slice(-8);
}

// ----------------------------------------------------------------- drawing --

function bracket(ctx, cx, cy, sx, sy, arm, th) {      // L-shaped corner mark; sx,sy = which way the arms point
  ctx.beginPath();
  ctx.moveTo(cx, cy);
  ctx.lineTo(cx + sx * arm, cy);
  ctx.lineTo(cx + sx * arm, cy + sy * th);
  ctx.lineTo(cx + sx * th, cy + sy * th);
  ctx.lineTo(cx + sx * th, cy + sy * arm);
  ctx.lineTo(cx, cy + sy * arm);
  ctx.closePath();
  ctx.fill();
}

function clipped(ctx, x, y, w, h, c) {                // rectangle with two stepped notches (top-left, bottom-right), like the waybar blocks
  var m = c / 2;
  ctx.beginPath();
  ctx.moveTo(x + c, y);
  ctx.lineTo(x + w, y);
  ctx.lineTo(x + w, y + h - c);
  ctx.lineTo(x + w - m, y + h - c);
  ctx.lineTo(x + w - m, y + h - m);
  ctx.lineTo(x + w - c, y + h - m);
  ctx.lineTo(x + w - c, y + h);
  ctx.lineTo(x, y + h);
  ctx.lineTo(x, y + c);
  ctx.lineTo(x + m, y + c);
  ctx.lineTo(x + m, y + m);
  ctx.lineTo(x + c, y + m);
  ctx.closePath();
}

// Draw one frame, drop dead items, return true while anything is still alive.
function draw(ctx, S, W, H, now) {
  if (!S.traces) { S.traces = []; S.ticks = []; S.brackets = []; S.labels = []; }
  ctx.clearRect(0, 0, W, H);
  var i, age, a, b, step, p, k, q, l, o, full, shown, txt, bh, bx, by, g, ga;
  var liveT = [], liveK = [], liveB = [], liveL = [], liveG = [];
  if (!S.ghosts) S.ghosts = [];
  ctx.lineJoin = "miter";
  ctx.lineCap = "butt";

  for (i = 0; i < S.traces.length; i++) {             // --- trace lines
    p = S.traces[i];
    age = now - p.born;
    if (age >= p.life) continue;
    liveT.push(p);
    if (age < 0) continue;
    step = Math.max(24, p.total / 12);                // head and tail move in hard steps
    b = age >= p.grow ? p.total : Math.floor(age / p.grow * p.total / step) * step;
    a = age > p.grow + p.hold ? Math.floor(clamp((age - p.grow - p.hold) / p.out, 0, 1) * p.total / step) * step : 0;
    if (a >= b) continue;
    ctx.lineWidth = p.w + 3;
    ctx.strokeStyle = "rgba(" + INK + ",0.75)";
    strokePart(ctx, p, a, b, 0, 0);                   // dark edge so the red reads on any wallpaper
    ctx.lineWidth = p.w;
    ctx.strokeStyle = "rgb(" + RED + ")";
    strokePart(ctx, p, a, b, 0, 0);
  }

  for (i = 0; i < S.ghosts.length; i++) {             // --- drag afterimages: outline that fades in 3 hard steps
    g = S.ghosts[i];
    age = now - g.born;
    if (age >= g.life) continue;
    liveG.push(g);
    ga = [0.85, 0.5, 0.22][Math.min(2, Math.floor(age / g.life * 3))];
    ctx.strokeStyle = "rgba(" + RED + "," + ga + ")";
    ctx.lineWidth = 2;
    ctx.strokeRect(g.x + 1, g.y + 1, g.w - 2, g.h - 2);
    ctx.fillStyle = "rgba(" + CYAN + "," + ga + ")";
    ctx.fillRect(g.x - 2, g.y - 2, 5, 5); ctx.fillRect(g.x + g.w - 3, g.y - 2, 5, 5);
    ctx.fillRect(g.x - 2, g.y + g.h - 3, 5, 5); ctx.fillRect(g.x + g.w - 3, g.y + g.h - 3, 5, 5);
  }

  for (i = 0; i < S.ticks.length; i++) {              // --- cyan ticks
    k = S.ticks[i];
    age = now - k.born;
    if (age >= k.life) continue;
    liveK.push(k);
    if (age < 0) continue;
    ctx.fillStyle = "rgb(" + CYAN + ")";
    ctx.fillRect(k.x, k.y, k.w, k.h);
  }

  for (i = 0; i < S.brackets.length; i++) {           // --- yellow corner brackets
    q = S.brackets[i];
    age = now - q.born;
    if (age >= q.life) continue;
    liveB.push(q);
    if (age > 70 && age < 100) continue;              // blink off for a moment
    if (age > q.life - 80 && Math.floor(age / 40) % 2) continue;
    o = 3;
    ctx.fillStyle = "rgb(" + YEL + ")";
    bracket(ctx, q.x - o, q.y - o, 1, 1, q.arm, 3);
    bracket(ctx, q.x + q.w + o, q.y - o, -1, 1, q.arm, 3);
    bracket(ctx, q.x + q.w + o, q.y + q.h + o, -1, -1, q.arm, 3);
    bracket(ctx, q.x - o, q.y + q.h + o, 1, -1, q.arm, 3);
  }

  ctx.font = "bold 11px monospace";                   // --- label blocks
  ctx.textBaseline = "middle";
  for (i = 0; i < S.labels.length; i++) {
    l = S.labels[i];
    age = now - l.born;
    if (age >= l.life) continue;
    liveL.push(l);
    if (age < 0) continue;
    if (age > l.life - 110 && Math.floor(age / 40) % 2) continue;
    full = l.text; shown = Math.min(full.length, Math.floor(age / 14)); txt = full.substring(0, shown);
    if (shown < full.length && full.charAt(shown) !== " ") txt += pick(GLY);   // decrypting lead character
    var cw = 22, gap = 3, tw = Math.ceil(ctx.measureText(full).width) + 16;
    bh = 17; bx = Math.round(l.x); by = Math.round(l.y - bh - 6);
    if (by < 4) by = Math.round(l.y + 6);
    var hot = l.tone === "r", cellFill = hot ? RED : YEL;
    ctx.fillStyle = "rgba(0,0,0,0.4)";                // hard offset shadow
    clipped(ctx, bx + 1, by + 2, cw, bh, 5); ctx.fill();
    clipped(ctx, bx + cw + gap + 1, by + 2, tw, bh, 5); ctx.fill();
    ctx.fillStyle = "rgb(" + cellFill + ")";          // icon cell
    clipped(ctx, bx, by, cw, bh, 5); ctx.fill();
    ctx.fillStyle = "rgb(" + INK + ")";
    ctx.fillText(hot ? "!!" : ">>", bx + 5, by + bh / 2 + 1);
    ctx.fillRect(bx + 2, by + 2, 2, 2); ctx.fillRect(bx + cw - 4, by + bh - 4, 2, 2);       // corner pips
    var tx0 = bx + cw + gap;                          // text block
    ctx.fillStyle = "rgba(" + INK + ",0.92)";
    clipped(ctx, tx0, by, tw, bh, 5); ctx.fill();
    ctx.strokeStyle = "rgb(" + RED + ")"; ctx.lineWidth = 1.5;
    clipped(ctx, tx0 + 1, by + 1, tw - 2, bh - 2, 5); ctx.stroke();
    ctx.fillStyle = "rgb(" + RED + ")";
    ctx.fillText(txt, tx0 + 8, by + bh / 2 + 1);
    ctx.fillStyle = "rgb(" + YEL + ")";
    ctx.fillRect(tx0 + 3, by + 3, 2, 2); ctx.fillRect(tx0 + tw - 5, by + bh - 5, 2, 2);     // corner pips
  }

  S.traces = liveT; S.ticks = liveK; S.brackets = liveB; S.labels = liveL; S.ghosts = liveG;
  return liveT.length + liveK.length + liveB.length + liveL.length + liveG.length > 0;
}
