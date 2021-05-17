use IO;

const max_w: int = 4096; // more than enough for 8.5 inches at 300 dpi
const max_h: int = 8192;

const max_pat_w: int = 256;
const max_pat_h: int = 256;

var w,h,wp,hp:int;
var norm,sum_p,sum_t,sum_pt,p,t:int;
var dx,dy,it,jt,background,dx_lo,dx_hi,dy_lo,dy_hi:int;
var p_mean,t_mean,c:real;
var progress,old_progress:real;

var text:[0..max_w-1,0..max_h-1] int;
var pat:[0..max_w-1,0..max_h-1] int;
var red:[0..max_w-1,0..max_h-1] int;

w = stdin.read(int);
h = stdin.read(int);
wp = stdin.read(int);
hp = stdin.read(int);
dx_lo = stdin.read(int);
dx_hi = stdin.read(int);
dy_lo = stdin.read(int);
dy_hi = stdin.read(int);
background = stdin.read(int);

if w>max_w || h>max_h || wp>max_pat_w || hp>max_pat_h then
  exit(-1);

for j in 0..h-1 {
  for i in 0..w-1 {
    text[i,j] = stdin.read(int);
  }
}
for j in 0..hp-1 {
  for i in 0..wp-1 {
    pat[i,j] = stdin.read(int);
    red[i,j] = stdin.read(int);
  }
}

old_progress = 0.0;
for dy in dy_lo..dy_hi {
  progress = ((dy-dy_lo):real/(dy_hi-dy_lo+1):real)*100.0;
  if progress>old_progress+25.0 then {
    stderr.writeln(progress); // without the newline, flush() doesn't have the desired effect
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

