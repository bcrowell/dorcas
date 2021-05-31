# Usage:
#   python3 convolve.py signal.png kernel.png output.png 1 -1.0 70 150
#   Convolves signal.png with kernel.png. Writes the result to output.png and prints the maximum
#   value of the output to stdout in the format __output__<max>.
#   This is set up so that it's convenient to take inputs that are black signal on a white background,
#   and write an output that is white on black, which is more convenient for input to code.
#   If the max printed to stdout is greater than 255, then you know that clipping occurred.
#   I tried finding a way to write 16 bit/pixel PNG as an output, but this would have involved
#   adding a dependency to some other library such as opencv, which may or may not be stable
#   and likely to be supported for a long time.
#   I thought about just using some text format for images, but this would have been slow, and
#   would also have made it more difficulty to quickly play with the data visually.
#   The use of 8 bits/pixel does require that you do some previous estimation of how big the
#   peaks are likely to be, but for my application this is not too hard to do.
#   Here the 1 means that we invert the kernel file by changing each pixel p to max-p, where
#   max is the highest brightness of any pixel. This allows us to convolve with a kernel
#   that is represented by black stuff on a white background. Supplying 0 for this
#   argument means that the inversion is not performed.
#   A high-pass filter is applied to get rid of periods longer than 70 in the x direction and 150 in y.
#   For no filtering, supply -1 for these arguments.
#   Normalization is performed so that the total energy in the output is the same as
#   in the signal, and then the final result is multiplied by -1.0, which is necessary with white-background
#   images because after high-pass filtering, the signal is all negative.

import sys
from PIL import Image
# PIL library python3-pil ; is actually the fork called Pillow, https://en.wikipedia.org/wiki/Python_Imaging_Library
import numpy

def main():
  args = sys.argv
  signal_file = args[1]
  kernel_file = args[2]
  result_file = args[3]
  if_invert_kernel = (int(args[4])==1)
  norm = float(args[5])
  high_pass_x = float(args[6])
  high_pass_y = float(args[7])
  max = convolve(signal_file,kernel_file,result_file,if_invert_kernel,norm,high_pass_x,high_pass_y)
  print(f'__output__{max}')

def convolve(signal_file,kernel_file,result_file,if_invert_kernel,norm2,high_pass_x,high_pass_y):
  signal,w,h = read_image(signal_file,False)
  kernel,w2,h2 = read_image(kernel_file,True)

  if if_invert_kernel:
    max = numpy.max(kernel)
    kernel = max-kernel

  print(f'w={w} h={h}')

  if w!=w2 or h!=h2:
    die(f"image and kernel are not the same size: w={w} h={h} w2={w2} h2={h2}")

  sf = numpy.fft.fft2(signal)
  kf = numpy.fft.fft2(kernel)

  norm = numpy.sum(kernel) # ... make the convolution preserve the total power
  c = sf*kf*(norm2/norm)

  # Filtering. This makes pattern-matching insensitive to background.
  if high_pass_x>0.0:
    hpx = round(w/high_pass_x)
    for i in range(hpx):
      for j in range(h):
        c[j][i] = 0
  if high_pass_y>0.0:
    hpy = round(w/high_pass_y)
    for j in range(hpy):
      for i in range(w):
        c[j][i] = 0

  d = numpy.fft.ifft2(c).real
  max = numpy.max(d)

  write_image(d,result_file)
  return round(max)

def write_image(image,filename):
  # inputs a numpy array
  # When values are out of range, the behavior of these methods seems to be that they pin the meter (which is good) rather than wrapping around.
  to_grayscale(Image.fromarray(image)).save(filename)

def read_image(filename,rotate):
  # Returns a numpy array.
  im = to_grayscale(Image.open(filename))
  if rotate:
    im = im.rotate(180)
  z = numpy.array(im)
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
