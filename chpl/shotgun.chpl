use IO;

type ii = int(32);

#include "../constants.h"

const max_w: ii = SHOTGUN_MAX_W; // sizes defined in constants.h
const max_h: ii = SHOTGUN_MAX_H;

const max_pat_w: ii = CORREL_MAX_PAT_W;
const max_pat_h: ii = CORREL_MAX_PAT_H;

var w,h:ii;
var norm,sum_p,sum_t,sum_pt,p,t:ii;

var text:[0..max_w-1,0..max_h-1] ii;

w = stdin.read(ii);
h = stdin.read(ii);

if w>max_w || h>max_h then {
  writeln(-1);
  writeln("size out of bounds in shorgun.chpl; ",
             w," ",h," ",max_w," ",max_h);
  exit(-1);
}
else {
  writeln(0);
  writeln("");
}

