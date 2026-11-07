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
function ease(t) { return 1 - Math.pow(1 - t, 1.8); }   // gentle ease-out: fast start, soft landing

// -------------------------------------------------------------- trace path --

// Blocky line from A to B (a vertical or horizontal edge): flat runs joined by right-angle steps,
// like the waybar's red line. Never a diagonal.
function stairPath(A, B, amp) {
  amp = amp || 10;
  var vert = Math.abs(B[1] - A[1]) > Math.abs(B[0] - A[0]);
  var len = vert ? Math.abs(B[1] - A[1]) : Math.abs(B[0] - A[0]);
  var dir = vert ? (B[1] > A[1] ? 1 : -1) : (B[0] > A[0] ? 1 : -1);
  var pts = [], pos = 0, off = 0, run, delta, next, i;
  function P(along, across) { return vert ? [A[0] + across, A[1] + dir * along] : [A[0] + dir * along, A[1] + across]; }
  pts.push(P(0, 0));
  while (pos < len) {
    run = Math.round(rnd(70, 170) / 2) * 2;           // long flat runs = fewer zigzags
    pos = Math.min(len, pos + run);
    pts.push(P(pos, off));                            // ends mid-zigzag, no forced return to the edge
    if (pos >= len) break;
    delta = (Math.random() < 0.5 ? -1 : 1) * rnd(amp * 0.6, amp);   // right-angle step
    next = clamp(off + delta, -amp, amp);
    if (Math.abs(next - off) < amp * 0.4) next = clamp(off - delta, -amp, amp);
    off = Math.round(next);
    pts.push(P(pos, off));
  }
  var cum = [0];
  for (i = 1; i < pts.length; i++)
    cum.push(cum[i - 1] + Math.abs(pts[i][0] - pts[i - 1][0]) + Math.abs(pts[i][1] - pts[i - 1][1]));
  return { pts: pts, cum: cum, total: cum[cum.length - 1] };
}

function trace(A, B, born, grow, hold, out, w, amp) {
  var p = stairPath(A, B, amp);
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
    if (S.ghosts.length > 2) S.ghosts = S.ghosts.slice(-2);
    return;
  }
  if (kind === "ws") {                                // workspace swipe: lines sweep along the top and bottom of the screen
    var dir = extra && extra.dir ? extra.dir : -1;    // -1: sweep right to left, 1: left to right
    var sx0 = dir > 0 ? r.x : r.x + r.w, sx1 = dir > 0 ? r.x + r.w : r.x, k, tx;
    S.traces.push(trace([sx0, r.y + 6], [sx1, r.y + 6], now, 340, 220, 150, 4, 4),
                  trace([sx0, r.y + r.h - 6], [sx1, r.y + r.h - 6], now, 340, 220, 150, 4, 4),
                  trace([sx0, r.y + 14], [sx1, r.y + 14], now + 50, 340, 220, 150, 2, 3),
                  trace([sx0, r.y + r.h - 14], [sx1, r.y + r.h - 14], now + 50, 340, 220, 150, 2, 3));
    for (k = 0; k < 4; k++) {
      tx = r.x + rnd(0.05, 0.95) * r.w;
      S.ticks.push({ x: Math.round(tx), y: Math.round((k % 2 ? r.y + 8 : r.y + r.h - 12) + rnd(-3, 3)), w: 6, h: 3,
                     born: now + rnd(0, 300), life: rnd(300, 700) });
    }
    S.labels.push({ text: (extra && extra.text) || "// WS", tone: "y", x: r.x + r.w / 2, y: r.y + 54, center: true, below: true, big: true, born: now, life: 720 });
    if (S.traces.length > 28) S.traces = S.traces.slice(-28);
    if (S.ticks.length > 60) S.ticks = S.ticks.slice(-60);
    if (S.labels.length > 8) S.labels = S.labels.slice(-8);
    return;
  }
  var x = r.x, y = r.y, w = r.w, h = r.h, i, life = 920, W = 4;
  var GAP = 12, GAP2 = 14;                            // thick line zigzags 4-20px out, thin strand 10-18px out (they overlap), never touching the app
  var lx = x - GAP, rx = x + w + GAP, lx2 = x - GAP2, rx2 = x + w + GAP2;
  var down = kind === "open" || kind === "float" || kind === "move" || kind === "menu";
  var left = [[lx, y], [lx, y + h]], right = [[rx, y], [rx, y + h]];
  var left2 = [[lx2, y], [lx2, y + h]], right2 = [[rx2, y], [rx2, y + h]];
  var grow = kind === "close" ? 280 : 340, hold = kind === "close" ? 110 : 220, out = kind === "close" ? 120 : 150;
  life = grow + hold + out;

  function side(e, thin) {
    var f0 = 0, f1 = 1, a0 = e[0], b0 = e[1];             // every line spans the window's full height
    var A = [a0[0], Math.round(a0[1] + (b0[1] - a0[1]) * f0)], B = [b0[0], Math.round(a0[1] + (b0[1] - a0[1]) * f1)];
    var born = thin ? now + 50 : now, wd = thin ? 2 : W, am = thin ? 4 : 8;
    if (down) S.traces.push(trace(A, B, born, grow, hold, out, wd, am));
    else S.traces.push(trace(B, A, born, grow, hold, out, wd, am));       // close / tile: run upward
  }
  side(left); side(right);                            // thick lines
  side(left2, true); side(right2, true);              // thinner strands, overlapping the thick lines

  S.brackets.push({ x: x, y: y, w: w, h: h, born: now, life: life, arm: clamp(Math.min(w, h) * 0.05, 10, 16) });

  var nt = kind === "move" ? 3 : 5, sx, t;
  for (i = 0; i < nt; i++) {                          // cyan blocks beside the side lines
    sx = (kind === "move" || Math.random() < 0.5) ? lx : rx;
    t = rnd(0.08, 0.92);
    S.ticks.push({ x: Math.round(sx + (sx === lx ? -rnd(8, 16) : rnd(8, 16)) - 3), y: Math.round(y + h * t), w: 6, h: 3,
                   born: now + rnd(0, 300), life: rnd(300, 700) });
  }

  var L = LABELS[kind] || LABELS.open;
  S.labels.push({ text: L[0], tone: L[1], x: x, y: y, born: now, life: life + 60 });

  if (S.traces.length > 28) S.traces = S.traces.slice(-28);
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
    var prog = age >= p.grow ? 1 : ease(age / p.grow);   // draws straight through, no stop partway, eased out
    b = prog >= 1 ? p.total : Math.floor(prog * p.total / step) * step;
    a = age > p.grow + p.hold ? Math.floor(ease(clamp((age - p.grow - p.hold) / p.out, 0, 1)) * p.total / step) * step : 0;
    if (a >= b) continue;
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
    ctx.lineWidth = 4;
    ctx.strokeRect(g.x + 1, g.y + 1, g.w - 2, g.h - 2);
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
    o = 6;
    ctx.fillStyle = "rgb(" + YEL + ")";
    bracket(ctx, q.x - o, q.y - o, 1, 1, q.arm, 4);
    bracket(ctx, q.x + q.w + o, q.y + q.h + o, -1, -1, q.arm, 4);
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
    ctx.font = l.big ? "bold 15px monospace" : "bold 11px monospace";
    var cw = l.big ? 30 : 22, gap = 3, tw = Math.ceil(ctx.measureText(full).width) + (l.big ? 22 : 16);
    bh = l.big ? 24 : 17;
    bx = Math.round(l.center ? l.x - (cw + gap + tw) / 2 : l.x);
    if (l.below) by = Math.round(l.y);                // sits under the bar line, not over the clock
    else { by = Math.round(l.y - bh - 6); if (by < 4) by = Math.round(l.y + 6); }
    var hot = l.tone === "r", cellFill = hot ? RED : YEL;
    ctx.fillStyle = "rgb(" + cellFill + ")";          // icon cell
    clipped(ctx, bx, by, cw, bh, 5); ctx.fill();
    ctx.fillStyle = "rgb(" + INK + ")";
    ctx.fillText(hot ? "!!" : ">>", bx + (l.big ? 7 : 5), by + bh / 2 + 1);
    ctx.fillRect(bx + 2, by + 2, 2, 2); ctx.fillRect(bx + cw - 4, by + bh - 4, 2, 2);       // corner pips
    var tx0 = bx + cw + gap;                          // text block
    ctx.fillStyle = "rgba(" + INK + ",0.92)";
    clipped(ctx, tx0, by, tw, bh, 5); ctx.fill();
    ctx.fillStyle = "rgb(" + RED + ")";
    ctx.fillText(txt, tx0 + (l.big ? 11 : 8), by + bh / 2 + 1);
    ctx.fillStyle = "rgb(" + YEL + ")";
    ctx.fillRect(tx0 + 3, by + 3, 2, 2); ctx.fillRect(tx0 + tw - 5, by + bh - 5, 2, 2);     // corner pips
  }

  S.traces = liveT; S.ticks = liveK; S.brackets = liveB; S.labels = liveL; S.ghosts = liveG;
  return liveT.length + liveK.length + liveB.length + liveL.length + liveG.length > 0;
}
