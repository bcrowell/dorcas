import sys,re,json
import sys
from PIL import Image
# PIL library python3-pil ; is actually the fork called Pillow, https://en.wikipedia.org/wiki/Python_Imaging_Library
import numpy

from gaussian_cross import * # just defines a bunch of pure functions

'''

Defines a functional RPN language for doing convolutions and
associated operations on images.  The basic idea here is that if I
have an image and 10 templates, I want to be able to pass all that
stuff to this code and have it crank away, rather than having to read
and pad the same data lots of times.

Because there are no side-effects, it is possible to parallelize the
expensive operations, but I haven't done that. There is a strict_fp
flag that is on by default, but turning it off allows definitions to
be deleted, which may be desirable for memory efficiency when not doing
any parallelism. It probably works just as well, if not better, to
do parallelization at a higher level, with multiple invocations of
this low-level program.

When parallelizing by invoking this script multiple times, a quick
and easy method is to use a single output file for all the processes,
and tell the peaks() function to open a file to append. On linux,
this is probably reliable as long as every line is less than about
~4k characters. The output from the different processes should appear
interleaved, but individual lines should be written atomically.

We want conveniences for hand-assembled code such as comments,
indentation, or ways to put multiple statements on one line, but these
are taken care of in the calling program, not in here. The convolve()
function in fft.rb has a human_input flag that is turned on by default
and preprocesses the input to allow these things. Don't use it with
machine-generated code, because commas in filenames will cause
problems.

Internally, arrays are stored in real or complex floating point, but
when writing to PNG files they're converted to 8-bit
integers. Operations like bloat that explicitly refer to width and
height are defined in (w,h) order, although PIL actually has things
transposed (see INTERNALS).

Any color input images are silently converted to grayscale using PIL's
image.convert('L'). This is probably not the same as ChunkyPNG's
image.grayscale. To avoid confusion about normalization, it's safest if
images are always converted to grayscale before passing them to this code.

If things go wrong, note that there are special opcodes for debugging.

opcodes:
i,f,c -- integer, float, or character string; push the literal value onto the stack
d,r -- define and refer to symbols (includes a pop or a push, respectively)
b,s,a -- binary operation on atomic types, scalar with array, or array with array; operations are +, -, *, /, max
u -- unary operation on array: fft, ifft, max, sum_sq; these all eat the array
o -- output the atomic-type object on the top of the stack to stdout
dup -- duplicate the value on the top of the stack
swap -- swap the two value on the top of the stack
gaussian_cross_kernel -- calculates a numpy array for a peak-detection kernel; see description in comments at top of gaussian_cross.py;
         pops the parameters w, h, a, and sigma for a window that's 2a+1 pixels on a side and fits a gaussian peak with width sigma
bloat, bloat_rot -- increase size of array
index -- pops x and y, then looks at pixel position (x,y) on the image on the top of the stack
         and pushes real part of the pixel's value; image is left alone
high_pass -- in the frequency domain; zeroes all channels of the fourier spectrum at < the given x and y values; copies, doesn't mutate
noneg -- sets all negative pixel values to zero in the image on the top of the stack; copies, doesn't mutate
clip -- clip all pixel values to the given range
read -- pop stack to get filename; read image file and push
read_rot -- like read but rotates input by 180 degrees
write -- pop stack to get image and filename; range has to 0-255 or output will be goofy; can use noneg to avoid negative values
forget -- forget a previously defined symbol; for memory efficiency, this lets us to get rid of all references so that garbage
     collection can happen; but this mutates the symbol table and therefore potentially breaks parallelism, so by default it's
     not allowed; to allow it, set the symbol strict_fp to 0
rpn -- print the rpn, for debugging purposes
stack -- print the stack, for debugging purposes
print_stderr -- pop stack and write object to stderr
peaks -- detect peaks and write them to a file
exit -- end the program prematurely
'''

def main():
  rpn = []
  for line in sys.stdin:
    line = line.rstrip() # removes all trailing whitespace, including newline
    #print(line)
    capture = re.search(r"^\s*([^\s]+)(\s+(.*))?",line) # keyword optionally followed by whitespace and then data
    if capture:
      key,data = capture.group(1,3)
      rpn.append(parse(key,data))
  #print(rpn)
  execute(rpn)

def parse(key,data):
  if key=='i':
    return (key,int(data))
  if key=='f':
    return (key,float(data))
  if key=='c' or key=='d' or key=='r' or key=='forget':
    return (key,data)
  if key=='b' or key=='s' or key=='a':
    if data=='+' or data=='-' or data=='*' or data=='/' or data=='max':
      return (key,data)
    else:
      die(f"unrecognized binary operator: {data}")
  if key=='u':
    if data=='fft' or data=='ifft' or data=='max' or data=='sum_sq':
      return (key,data)
    else:
      die(f"unrecognized unary operator: {data}")
  if key in ('o','read','read_rot','write','rpn','stack','bloat','bloat_rot','exit','print_stderr','index','high_pass','noneg','clip','dup','swap',
                   'gaussian_cross_kernel','peaks'):
    return (key,None)
  die(f"unrecognized key: {key}")

def execute(rpn):
  stack = []
  symbols = {}
  count = 0
  for line in rpn:
    #print(stack)
    key,data = line
    count += 1
    if key=='o':
      print(stack.pop())
    if key=='rpn':
      print(rpn)
    if key=='stack':
      print(stack)
    if key=='i' or key=='f' or key=='c':
      stack.append(data)
    if key=='d': # d=define: pop and define a symbol as that value
      symbol = data
      if symbol in symbols:
        die(f"symbol {symbol} redefined") # don't mutate the symbol table, that breaks pure fp behavior and creates possible problems for parallelization
      symbols[symbol] = stack.pop()
    if key=='forget':
      # This mutates the symbol table, which could break parallelism.
      if strict_fp(symbols):
        die(f"strict_fp is set, so the forget operation is not allowed")
      symbol = data
      del symbols[symbol]
    if key=='r': # r=reference: push value of a symbol
      symbol = data
      stack.append(symbols[symbol])
    if key=='u':
      z = unary_array(key,data,stack.pop())
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
      result = z[1]
      if not (result is None):
        stack.append(result)
    if key=='b' or key=='s' or key=='a':
      y = stack.pop()
      x = stack.pop()
      z = binary(key,data,x,y)
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
      result = z[1]
      if not (result is None):
        stack.append(result)
    if key=='read' or key=='read_rot':
      z = read_op(stack.pop(),key=='read_rot')
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
      stack.append(z[1])
    if key=='write':
      filename = stack.pop()
      im = stack.pop()
      z = write_op(im,filename)
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
    if key=='peaks':
      batch_code = stack.pop()
      th = stack.pop()
      tw = stack.pop()
      norm = stack.pop()
      label = stack.pop()
      mode = stack.pop()
      filename = stack.pop()
      max_peaks = stack.pop()
      radius = stack.pop()
      threshold = stack.pop()
      array = stack.pop()
      z = peaks_op(array,threshold,radius,max_peaks,filename,mode,label,norm,tw,th,batch_code)
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
    if key=='gaussian_cross_kernel':
      sigma = stack.pop()
      a = stack.pop()
      h = stack.pop()
      w = stack.pop()
      z = do_gaussian_cross_kernel(w,h,a,sigma)
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
      stack.append(z[1])
    if key=='exit':
      sys.exit(0)
    if key=='print_stderr':
      sys.stderr.write(f"{stack.pop()}\n")
    if key=='dup':
      stack.append(stack[-1])
    if key=='swap':
      t = stack[-2]
      stack[-2] = stack[-1]
      stack[-1] = t
    if key=='index':
      y = stack.pop()
      x = stack.pop()
      im = stack[-1]
      stack.append(im[y,x].real) # numpy array is internally transposed, see INTERNALS
    if key=='high_pass':
      y = stack.pop()
      x = stack.pop()
      im = stack.pop()
      z = high_pass(im,x,y)
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
      stack.append(z[1])
    if key=='noneg':
      im = stack.pop()
      z = noneg(im)
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
      stack.append(z[1])
    if key=='clip':
      max = stack.pop()
      min = stack.pop()
      im = stack.pop()
      z = clip(im,min,max)
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
      stack.append(z[1])
    if key=='bloat' or key=='bloat_rot':
      background = stack.pop() # value to pad with
      h = stack.pop()
      w = stack.pop()
      im = stack.pop()
      z = bloat_op(im,w,h,background,key=='bloat_rot')
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
      stack.append(z[1])

def strict_fp(symbols):
  if 'strict_fp' in symbols:
    return (symbols['strict_fp']==1)
  else:
    return true

def bloat_op(im,w,h,background,rot):
  if not (isinstance(w,int) and isinstance(h,int)):
    return (1,f"w={w} and h={h} should both be integers")
  if not is_array(im):
    return (1,f"object {im} is not a numpy array")
  background = float(background)
  bloated = numpy.full((h, w),background,dtype=numpy.float64)
  # ... gets transposed on conversion between numpy and PIL, see INTERNALS
  # In the following, the python notation a:b only goes up to b-1.
  if rot:
    bloated[h-im.shape[0]:h, w-im.shape[1]:w] = im
  else:
    bloated[:im.shape[0], :im.shape[1]] = im # https://stackoverflow.com/a/44623017
  return (0,bloated)

def noneg(im):
  return clip(im,0.0,numpy.Inf)

def clip(im,min,max):
  # See comments in high_pass() re immutable data and parallelism.
  if not isinstance(max,float):
    return (1,f"object {max} is not a float")
  a = numpy.clip(im,min,max)
  return (0,a)

def high_pass(im,x,y):
  # In order to avoid messing up the possibility of parallelism, this is implemented so that the original
  # array is not modified in place, i.e., everything is in an fp style with immutable data.
  a = deep_copy_numpy_array(im)
  a[:y,:x] = 0.0 # Order is because of transposition, see INTERNALS. I believe this does 0..(x-1) and 0..(y-1)
  return (0,a)

def deep_copy_numpy_array(b):
  # The following should make a deep copy.  There is also a copyto(), but it's not clear to me from the docs
  # whether that really makes a deep copy.
  a = numpy.empty_like(b)
  a[:] = b
  return a

def read_op(filename,rotate):
  if not isinstance(filename,str):
    return (1,f"object {filename} is not a string")
  im,w,h = read_image(filename,rotate)
  return (0,im)

def write_op(im,filename):
  if not isinstance(filename,str):
    return (1,f"object {filename} is not a string")
  if not is_array(im):
    return (1,f"object {im} is not a numpy array")
  write_image(im,filename)
  return (0,None)

def peaks_op(array,threshold_raw,radius,max_peaks,filename,mode,label,norm,tw,th,batch_code):
  # Look for array elements that are the greatest within a square with a certain radius and that are above
  # a certain threshold. Sort them by descending order of score, and then write the first max_peaks candidates
  # to the given file.
  if not isinstance(filename,str):
    return (1,f"object {filename} is not a string")
  if not isinstance(mode,str):
    return (1,f"object {mode} is not a string")
  if not is_array(array):
    return (1,f"object {array} is not a numpy array")
  h,w = array.shape
  threshold = threshold_raw/norm
  #sys.stderr.write(f"h,w={h},{w} threshold={threshold}\n")
  hits = search_for_peaks(array,w,h,tw,th,threshold,threshold+1.0/norm,radius,norm,max_peaks,0)
  n = len(hits)
  if n>max_peaks:
    n=max_peaks
  with open(filename,mode) as f: # On linux, when you open to append it's non-locking. This may not work on windows.
    for i in range(n):
      z = hits[i].copy()
      flag_edge = z.pop()
      misc = {"label":label,"batch":batch_code}
      if flag_edge:
        misc['edge']=1 # This flag means that this point has at least one negative coord, should be checked against neighbors to see if any are redundant.
      z.append(misc)
      print(json.dumps(z),file=f) # On linux, most likely this is atomic if the line is under about 4k.
      # At least on unix, this seems likely to avoid having one line interrupted by another from another process. 
      # https://unix.stackexchange.com/a/42564/39248
  return (0,None)

def search_for_peaks(array,w,h,tw,th,lo,hi,radius,norm,max_peaks,depth):
  err,hits = search_for_peaks_low_level(array,w,h,tw,th,lo,hi,radius,norm,max_peaks)
  if err==0:
    return hits
  # too many hits
  if numpy.isinf(hi):
    mid = lo+1.0/norm
  else:
    mid = (lo+hi)*0.5
  hits1 = search_for_peaks(array,w,h,tw,th,mid,hi,radius,norm,max_peaks,depth+1)
  if len(hits1)==max_peaks:
    return hits1
  hits2 = search_for_peaks(array,w,h,tw,th,lo,mid,radius,norm,max_peaks-len(hits1),depth+1)
  return hits1+hits2

def search_for_peaks_low_level(array,w,h,tw,th,lo,hi,radius,norm,max_peaks):
  # Returns [err,hits].
  # If there were going to be too many hits by more than the amount defined by overdo, returns with an error.
  # If the number of hits is greater than max_peaks but less than overdo, returns the highest ones as requested.
  overdo = max_peaks*2+10000
  hits = []
  for i in range(w):
    for j in range(h):
      x = array[j,i].real
      # ... Even when not using high-pass filtering, results have small imaginary parts.
      #     Note that numpy.complex64 will not throw an error on comparison: https://stackoverflow.com/q/67840584/1142217
      if x<lo or x>=hi:
        continue
      # For efficiency, first do some code that tries to efficienctly impose the local max condition right away.
      if (i>0 and x<array[j,i-1]) or (i<w-1 and x<array[j,i+1]) or (j>0 and x<array[j-1,i]) or (j<h-1 and x<array[j+1,i]):
        continue
      # The following search can be very cpu-intensive.
      bad = False
      for ii in range(i-radius,i+radius+1): # top end is excluded from range
        if ii<0 or ii>w-1:
          continue
        for jj in range(j-radius,j+radius+1):
          if jj<0 or jj>h-1 or (ii==0 and jj==0):
            continue
          if x<array[jj,ii].real:
            bad=True
            break
        if bad:
          break
      if bad:
        continue
      if len(hits)>overdo:
        return [1,None]
      # We have a local max that is over the threshold.
      # Coords (i,j) can legitimately be negative, as when the character is very near the left edge of the page, and the template's width hangs outside.
      # These wrap around due to how the fft works, so fix them here. In cases where (i,j) lies within radius of the left or top, this can
      # result in multiple hits being returned for what is actually a single hit. Trying to handle this correctly in the performance-intensive
      # loop above would be a bad idea. Will need to clean that up later. See 'edge' flag below.
      flag_edge = False
      i2,j2 = i,j
      if i>tw-1:
        i2=i-w
        flag_edge = True
      if j>th-1:
        j2=j-h
        flag_edge = True
      hits.append([x*norm,i2,j2,flag_edge])
  hits.sort(reverse=True,key=lambda a: a[0])
  if len(hits)>max_peaks:
    hits = hits[:max_peaks]
  return [0,hits]

def do_gaussian_cross_kernel(w,h,a,sigma):
  if not (isinstance(a,int)):
    return (1,f"a={a} should be an integer")
  ker = gaussian_cross_kernel(w,h,a,sigma)
  return (0,ker)

def unary_array(key,op,x):
  if not is_array(x):
    return(1,f"object {x} is not a numpy array")
  if op=='fft':
    aa = numpy.fft.fft2(x)
    return (0,numpy.fft.fft2(x))
  if op=='ifft':
    return (0,numpy.fft.ifft2(x))
  if op=='max':
    return (0,float(numpy.max(x).real)) # convert to standard float from, e.g., numpy float64
  if op=='sum_sq':
    return (0,float(numpy.sum(numpy.abs(x)**2)))
  return(1,f"unrecognized unary array operation {op}")

def binary(key,data,x,y):
  # returns (0,data) or (0,None) on success; in the latter case, nothing should be pushed onto the stack
  if key=='b':
    return binary_atomic(data,x,y)
  if key=='s':
    return binary_scalar_with_array(data,x,y)
  if key=='a':
    return binary_array_with_array(data,x,y)
  return (1,f"coding error, binary() was called with the illegal key {key}")

def binary_array_with_array(op,x,y):
  if not (is_array(x) and is_array(y)):
    return (1,f"operation {op} with key a is supposed to be used on an array combined with an array, not {type(x)} with {type(y)}")
  if x.shape!=y.shape:
    return (1,f"in binary_array_with_array, with operation {op}, shapes are not the same: {x.shape} and {y.shape}")
  if op!='*' and op!='+' and op!='-':
    return (1,f"only *, +, and - are implemented for arrays with arrays; operation {op} is not implemented")
  if op=='*':
    return (0,x*y)
  if op=='+':
    return (0,x+y)
  if op=='-':
    return (0,x-y)

def binary_scalar_with_array(op,x,y):
  if is_array(x)==is_array(y):
    return (1,f"operation {op} with key s is supposed to be used on an array combined with a scalar, not {type(x)} with {type(y)}")
  if is_array(y) and (not is_array(x)):
    if (op=='+' or op=='*'):
      # For commutative operations, allow either order; recurse so that array is first.
      return binary_scalar_with_array(op,y,x)
    else:
      return (1,f"For the operation {op} on an array with a scalar, the array must come first.")
  # If we get to here, then we're guaranteed that x is an array and y is a scalar.
  if op=='/' and is_zero(y):
    return (1,"division by zero")
  if op=='/' and isinstance(y, float):
    return binary_scalar_with_array('*',x,1.0/y)
  if op=='/' and isinstance(y,int):
    return (1,"division by an integer is not implemented")
  if op=='*':
    return (0,x*y) # numpy multiplication of array by scalar
  if op=='+':
    return (0,x+y) # numpy addition of array and scalar
  if op=='save':
    write_image(x,y) # write image x to filename y
    return (0,None)
  return (1,f"coding error, operation {op} fell through")

def binary_atomic(op,x,y):
  # In the following, we can have, for example, a float and a numpy.float64.
  if is_float(x) and is_float(y):
    return binary_atomic_helper(op,float(x),float(y))
  if is_int(x) and is_int(y):
    return binary_atomic_helper(op,int(x),int(y))
  return (1,f"mismatched or illegal types, {x} and {y}, types are {str(type(x))} and {str(type(y))}")

def binary_atomic_helper(op,x,y):
  if op=='+':
    return (0,x+y)
  if op=='-':
    return (0,x-y)
  if op=='*':
    return (0,x*y)
  if op=='/':
    if is_zero(y):
      return (1,"division by zero")
    return (0,x/y)
  if op=='max':
    return (0,max((x,y)))
  return (1,f"unknown binary operator: {op}")

def is_array(x):
  return isinstance(x,numpy.ndarray) # https://stackoverflow.com/questions/40312013/check-type-within-numpy-array

def is_float(x):
  return isinstance(x,float)

def is_int(x):
  return isinstance(x,int)

def is_zero(x):
  if isinstance(x,int):
    return x==0
  if isinstance(x,float):
    return x==0.0
  die(f"illegal type in is_zero, x={x}")

def write_image(image,filename):
  # inputs a numpy array
  # When values are out of range, the behavior of these methods seems to be that they pin the meter (which is good) rather than wrapping around.
  image = image.real.astype(numpy.uint8)
  shape = numpy.shape(image)
  to_grayscale(Image.fromarray(image)).save(filename)

def read_image(filename,rotate):
  # Returns a numpy array.
  im = to_grayscale(Image.open(filename))
  if rotate:
    im = im.rotate(180)
  z = numpy.array(im).astype(numpy.float64)
  shape = numpy.shape(z)
  w = shape[1]
  h = shape[0]
  return (z,w,h)

def to_grayscale(image):
  # inputs a PIL object
  return image.convert('L') # convert to grayscale, https://stackoverflow.com/a/12201744

def die(message):
  sys.exit(message)

main()
