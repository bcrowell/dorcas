/* Making the following too big has a huge impact on performance.
   With 2048x256, test case took 3.8 seconds; with 4096x8192, it took 11.4 seconds.
   Experiments show that on my machine 2048x512 is fast, but 2048x1024 is slow. */

#define CORREL_MAX_W 2048
   /* roughly enough for 8.5 inches at 300 dpi */
#define CORREL_MAX_H 512

#define CORREL_MAX_PAT_W 256
#define CORREL_MAX_PAT_H 256

#define SHOTGUN_MAX_W 4096
#define SHOTGUN_MAX_H 8192




