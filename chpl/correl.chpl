use IO;

type ii = int(32); // empirically, switching from 64 to 32 made little difference when max_w and max_h were fixed at small values

// Making the following too big has a huge impact on performance.
// With 2048x256, test case took 3.8 seconds; with 4096x8192, it took 11.4 seconds.
// Experiments show that 2048x512 is fast, but 2048x1024 is slow.
const max_w: ii = 2048; // roughly enough for 8.5 inches at 300 dpi
const max_h: ii = 512;

const max_pat_w: ii = 256;
const max_pat_h: ii = 256;

var w,h,wp,hp:ii;
var norm,sum_p,sum_t,sum_pt,p,t:ii;
var dx,dy,it,jt,background,dx_lo,dx_hi,dy_lo,dy_hi:ii;
var p_mean,t_mean,c:real;
var progress,old_progress:real;

var text:[0..max_w-1,0..max_h-1] ii;
var pat:[0..max_w-1,0..max_h-1] ii;
var red:[0..max_w-1,0..max_h-1] ii;

w = stdin.read(ii);
h = stdin.read(ii);
wp = stdin.read(ii);
hp = stdin.read(ii);
dx_lo = stdin.read(ii);
dx_hi = stdin.read(ii);
dy_lo = stdin.read(ii);
dy_hi = stdin.read(ii);
background = stdin.read(ii);

if w>max_w || h>max_h || wp>max_pat_w || hp>max_pat_h then
  exit(-1);

for j in 0..h-1 {
  for i in 0..w-1 {
    text[i,j] = stdin.read(ii);
  }
}
for j in 0..hp-1 {
  for i in 0..wp-1 {
    pat[i,j] = stdin.read(ii);
    red[i,j] = stdin.read(ii);
  }
}

old_progress = 0.0;
for dy in dy_lo..dy_hi {
  progress = ((dy-dy_lo):real/(dy_hi-dy_lo+1):real)*100.0;
  if progress>old_progress+25.0 || dy==dy_hi then {
    stderr.writeln(progress:int); // without the newline, flush() doesn't have the desired effect
    stderr.flush();
    old_progress = progress;
  }
  for dx in dx_lo..dx_hi {
    norm = 0;
    sum_p = 0;
    sum_t = 0;
    sum_pt = 0;
    for i in 0..wp-1 {
      it = i+dx;
      for j in 0..hp-1 {
        jt = j+dy;
        if red[i,j]>0 then continue;
        p = pat[i,j];
        if it<0 || it>w-1 || jt<0 || jt>h-1 then
          t = background;
        else
          t = text[it,jt];
        norm = norm+1;
        sum_p = sum_p + p;
        sum_t = sum_t + t;
        sum_pt = sum_pt + p*t;
      }
    }

    if norm==0 then
      exit(-1);

    p_mean = sum_p:real/norm:real;
    t_mean = sum_t:real/norm:real;

    c = sum_pt:real/norm:real-p_mean*t_mean;

    writeln(c);
  }
}

