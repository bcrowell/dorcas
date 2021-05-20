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
