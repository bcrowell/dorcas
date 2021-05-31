#-------------------------------------------------------------------------
#    2-dimensional fft
#-------------------------------------------------------------------------

def convolution_convenience_function(image_raw,kernel_raw,background,norm:1.0,high_pass_x:150,high_pass_y:200,options:{})
  # The inputs image and kernel can be ink arrays, ChunkyPNG images, or filenames of png files, and will be autodetected by the variables' types.
  # They don't need to have matched sizes, nor do their sizes need to be powers of 2. The image is automatically padded enough to prevent
  # the kernel from wrapping around when we get to the right and bottom edges. If from files, then
  # the inputs must be grayscale PNG files, 8 bits/pixel.
  # At the end, the result is automatically cropped back to the original size of the image. 
  # The results are returned as [max,ink,output_filename], where max is the greatest value in the output and
  # by default the output file has been deleted already and output_filename is nil.
  # an ink array or as a file, or both, depending on the options preserve_file and no_return_ink. The default is
  # to return only an ink array.
  # The factor norm is a division factor.
  # The defaults for the following flags are false.
  # The image and kernel are taken to be dark images on a light background. The kernel's background should be pure white.
  # The image's background is input as the parameter background, in ink units; this is used only for padding, since other than that,
  # any background in the image gets filtered out by the fft.
  # This is somewhat slow, mainly because it takes time to read in all the png files to ChunkyPNG and then writing them
  # back out to disk. However, we need to do this in order to pad them to the necessary sizes.
  verbosity = 3
  no_return_ink = (options['no_return_ink']==true)
  preserve_file = (options['preserve_file']==true)
  # Get inputs as ChunkyPNG, converting or reading if necessary:
  if verbosity>=3 then print "reading inputs\n" end
  image  = image_any_type_to_chunky(image_raw)
  kernel = image_any_type_to_chunky(kernel_raw)
  # The sums in the following are to prevent the kernel from wrapping around.
  w = boost_for_no_large_prime_factors(image.width+kernel.width)
  h = boost_for_no_large_prime_factors(image.height+kernel.height)
  if verbosity>=3 then print "padding\n" end
  image_padded  = pad_image(image,w,h,background)
  kernel_padded = pad_image(kernel,w,h,0.0)
  image_file = temp_file_name()+".png"
  kernel_file = temp_file_name()+".png"
  output_file = temp_file_name()+".png"
  image_padded.save(image_file)
  kernel_padded.save(kernel_file)
  if verbosity>=3 then print "convolving\n" end
  max = convolve_png_files(image_file,kernel_file,output_file,1,norm,high_pass_x,high_pass_y)
  FileUtils.rm_f(image_file)
  FileUtils.rm_f(kernel_file)
  if verbosity>=3 then print "reading in output\n" end
  im = image_from_file_to_grayscale(output_file).crop(0,0,image.width-1,image.height-1) # ChunkyPNG object, cropped back to original size
  ink = nil
  if !no_return_ink then ink=image_to_ink_array(im) end
  if !preserve_file then FileUtils.rm_f(output_file); output_file=nil end
  return [max,ink,output_file]
end

def convolve_png_files(signal_file,kernel_file,output_file,if_invert_kernel,norm2,high_pass_x,high_pass_y)
  # Example: python3 convolve.py signal.png kernel.png output.png 1 -1.0 70 150
  # Returns the highest value in the output (integer).
  # Doesn't care at all whether input sizes are a power of 2, but will be slow if they have large prime factors,
  # and kernel must be as big as the image.
  # if_invert_kernel is 0 or 1
  # norm2 is a division factor
  # high_pass_x,high_pass_y are periods
  # See the python source for more details.
  max = shell_out("python3 py/convolve.py \"#{signal_file}\" \"#{kernel_file}\" \"#{output_file}\" #{if_invert_kernel} #{-1.0*norm2} #{high_pass_x} #{high_pass_y}").to_i
  return max
end

#-------------------------------------------------------------------------
#    low-level arithmetic
#-------------------------------------------------------------------------

def boost_for_no_large_prime_factors(n)
  # Returns an integer that is >=n but as small as possible (or almost so) while having no prime factors greater than 7.
  # Fftw3 will be fastest on sizes that are outputs of this function.
  # This function has tests in test.rb.
  if n<1 then die("illegal n=#{n} in boost_for_no_large_prime_factors") end
  if n<=3 then return n end
  lazy = 65536
  if n>lazy then return 1024*boost_for_no_large_prime_factors((n/1024.0).ceil) end
  # If we fall through to here, then n is betwen 11 and lazy. The following could in principle
  # take many recursions, but in reality, acceptable results are fairly dense in this region.
  n.upto(lazy) { |k|
    if has_no_large_prime_factors(k) then return k end
  }
end

def has_no_large_prime_factors(n)
  # returns true if n has prime a factor equal to 11 or more
  if n<=3 then return true end
  [2,3,5,7].each { |k|
    if n%k==0 then return has_no_large_prime_factors(n/k) end
  }
  return false
end

#-------------------------------------------------------------------------
#    one-dimensional fft
#-------------------------------------------------------------------------
def windowing_and_padding(y,window,desired_length,value_for_padding)
  n = y.length
  y2 = y.clone
  while (y2.length<desired_length) do y2.push(value_for_padding) end
  0.upto(y2.length-1) { |j|
    x = 2.0*Math::PI*j.to_f/y.length
    if window=='none' then w = 1.0 end
    if window=='hann' then w = 0.5*(1-Math::cos(x)) end
    y2[j] *= w
  }
  return y2
end


# Code by Greg Johnson, http://www.gregfjohnson.com/fftruby/
#
# Solve "vec = fft_matrix * beta" for beta (modulo a constant.)
# (Divide result by Math::sqrt(vec.size) to preserve length.)
# vec.size is assumed to be a power of 2.
#
# Example use:  puts fft([1,1,1,1])
#
def fft(vec,direction:1)
    # direction=1 for Fourier transform, -1 for inverse Fourier transform
    return vec if vec.size <= 1

    even = Array.new(vec.size / 2) { |i| vec[2 * i] }
    odd  = Array.new(vec.size / 2) { |i| vec[2 * i + 1] }

    fft_even = fft(even)
    fft_odd  = fft(odd)

    fft_even.concat(fft_even)
    fft_odd.concat(fft_odd)

    Array.new(vec.size) {|i| fft_even[i] + fft_odd [i] * fft_helper(-i, vec.size,direction)}
end

# calculate individual element of FFT matrix:  (e ^ (2 pi i k/n))
# fft_matrix[i][j] = omega(i*j, n)
#
def fft_helper(k, n,direction)
    Math::E ** Complex(0, direction*2 * Math::PI * k / n)
end
