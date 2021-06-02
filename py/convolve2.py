import sys,re
import sys
from PIL import Image
# PIL library python3-pil ; is actually the fork called Pillow, https://en.wikipedia.org/wiki/Python_Imaging_Library
import numpy

'''
Defines an functional RPN language for doing convolutions and associated operations on images.
Because there are no side-effects, it is possible to parallelize the expensive operations, but
I haven't done that. The basic idea here is that if I have an image and 10 templates, I want
to be able to pass all that stuff to this code and have it crank away, rather than having to
read and pad the same data lots of times.

Internally, arrays are stored in real or complex floating point, but when writing to PNG
files they're converted to 8-bit integers. Operations like bloat that explicitly refer
to width and height are defined in (w,h) order, although PIL actually has things
transposed (see INTERNALS).

If things go wrong, note that there are special opcodes for debugging.

opcodes:
i,f,c -- integer, float, or character string; push the literal value onto the stack
d,r -- define and refer to symbols (includes a pop or a push, respectively)
b,s,a -- binary operation on atomic types, scalar with array, or array with array
u -- unary operation on array: fft, ifft, max, sum_sq
o -- output the atomic-type object on the top of the stack to stdout
bloat -- increase size of array
index -- pops x and y, then looks at pixel position (x,y) on the image on the top of the stack
         and pushes real part of the pixel's value; image is left alone
read -- pop stack to get filename; read image file and push
read_rot -- like read but rotates input by 180 degrees
write -- pop stack to get image and filename
dup -- duplicate the value on the top of the stack
rpn -- print the rpn, for debugging purposes
stack -- print the stack, for debugging purposes
print_stderr -- pop stack and write object to stderr
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
  if key=='c' or key=='d' or key=='r':
    return (key,data)
  if key=='b' or key=='s' or key=='a':
    if data=='+' or data=='-' or data=='*' or data=='/':
      return (key,data)
    else:
      die(f"unrecognized binary operator: {data}")
  if key=='u':
    if data=='fft' or data=='ifft' or data=='max' or data=='sum_sq':
      return (key,data)
    else:
      die(f"unrecognized unary operator: {data}")
  if (key=='o' or key=='read' or key=='read_rot' or key=='write' or key=='rpn' or key=='stack' or key=='bloat' or key=='exit'
                     or key=='print_stderr' or key=='index' or key=='dup'):
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
      symbols[symbol] = stack.pop()
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
    if key=='exit':
      sys.exit(0)
    if key=='print_stderr':
      sys.stderr.write(f"{stack.pop()}\n")
    if key=='dup':
      stack.append(stack[-1])
    if key=='index':
      y = stack.pop()
      x = stack.pop()
      im = stack[-1]
      stack.append(im[y,x].real) # numpy array is internally transposed, see INTERNALS
    if key=='bloat':
      background = stack.pop() # value to pad with
      h = stack.pop()
      w = stack.pop()
      im = stack.pop()
      z = bloat_op(im,w,h,background)
      if z[0]!=0:
        die(f"error: {z[1]}, line={line}")
      stack.append(z[1])

def bloat_op(im,w,h,background):
  if not (isinstance(w,int) and isinstance(h,int)):
    return (1,f"w={w} and h={h} should both be integers")
  if not is_array(im):
    return (1,f"object {im} is not a numpy array")
  background = float(background)
  bloated = numpy.full((h, w),background,dtype=numpy.float64)
  # ... gets transposed on conversion between numpy and PIL, see INTERNALS
  bloated[:im.shape[0], :im.shape[1]] = im # https://stackoverflow.com/a/44623017
  return (0,bloated)

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

def unary_array(key,op,x):
  if not is_array(x):
    return(1,f"object {x} is not a numpy array")
  if op=='fft':
    aa = numpy.fft.fft2(x)
    return (0,numpy.fft.fft2(x))
  if op=='ifft':
    return (0,numpy.fft.ifft2(x))
  if op=='max':
    return (0,numpy.max(x).real)
  if op=='sum_sq':
    return (0,numpy.sum(numpy.abs(x)**2))
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
  if type(x)!=type(y):
    return (1,"mismatched types")
  t = type(x)
  if (t is int) or (t is float):
    return binary_atomic_helper(op,x,y)
  return (1,"illegal type")

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
  return (1,f"unknown binary operator: {op}")

def is_array(x):
  return isinstance(x,numpy.ndarray) # https://stackoverflow.com/questions/40312013/check-type-within-numpy-array

def is_zero(x):
  t = type(x)
  if t is int:
    return x==0
  if t is float:
    return x==0.0
  die("illegal type")

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
