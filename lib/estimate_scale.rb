def estimate_line_spacing(image,guess_dpi:150,guess_font_size:12)
  # This could probably be made less sensitive to rotation by taking power spectra on vertical strips and adding those.
  proj = []
  0.upto(image.height-1) { |j|
    x = 0.0
    0.upto(image.width-1) { |i|
      x = x+color_to_ink(image[i,j])
    }
    proj.push(x)
  }
  n = proj.length
  pow2 = (Math::log(n)/Math::log(2.0)).to_i
  if 2**pow2<n then pow2=pow2+1 end
  nn = 2**pow2
  avg = 0.0
  0.upto(n-1) { |i| avg=avg+proj[i] }
  avg = avg/n
  while proj.length<nn do proj.push(avg) end
  fourier = fft(proj)
  # The following is just so we have some idea what frequency range to look at.
  guess_period = 0.04*guess_dpi*guess_font_size
  guess_freq = (nn*0.5/guess_period).to_i # Is the 0.5 right, Nyquist frequency?
  min_freq = guess_freq/4
  if min_freq<2 then min_freq=2 end
  max_freq = guess_freq*3
  if max_freq>nn-1 then max_freq=nn-1 end
  max = 0.0
  best = -1
  min_freq.upto(max_freq) { |ff|
    a = fourier[ff].abs
    if a>max then max=a; best=ff end
  }
  period = nn/best.to_f
  return period
end
