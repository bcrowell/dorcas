def image_to_ink_array(image)
  w,h = image.width,image.height
  return generate_array(w,h,lambda {|i,j| color_to_ink(image[i,j]) })
end

def ink_array_dimensions(a)
  return [a.length,a[0].length]
end

def image_to_list_of_floats(image)
  result = []
  ink = image_to_ink_array(image)
  w,h = ink_array_dimensions(ink)
  f = []
  0.upto(w-1) { |i|
    0.upto(h-1) { |j|
      f.push(ink[i][j])
    }
  }
  return f
end

def color_to_ink(color) # returns a measure of darkness
  r,g,b = ChunkyPNG::Color.r(color),ChunkyPNG::Color.g(color),ChunkyPNG::Color.b(color)
  return 1.0-(r+g+b)/(3.0*255.0)
end

def ink_to_color(ink) # inverse of color_to_ink
  gray = ((1.0-ink)*255).round
  return ChunkyPNG::Color.rgb(gray,gray,gray)
end

def erase_inside_box(image,bbox)
  bbox[0].upto(bbox[1]) { |i|
    bbox[2].upto(bbox[3]) { |j|
      image[i,j] = ChunkyPNG::Color::WHITE
    }
  }
end

def image_minus(image,image2)
  return image_bitwise(image,image2,lambda { |x,y| x and !y})
end

def image_or(image,image2)
  return image_bitwise(image,image2,lambda { |x,y| x or y})
end

def image_bitwise(image,image2,op)
  w,h = assert_same_size(image,image2)
  result = image_empty_copy(image)
  0.upto(w-1) { |i|
    0.upto(h-1) { |j|
      p = image[i,j]
      p2 = image2[i,j]
      x = has_ink(p)
      y = has_ink(p2)
      if op.call(x,y) then result[i,j] = ChunkyPNG::Color::BLACK end
    }
  }
  return result
end

def mask_to_background(image,mask,background,fatten)
  # changes the image in place
  # background is an ink value
  # fatten is an amount by which to beef up the mask
  background_color = ink_to_color(background)
  w,h = assert_same_size(image,mask)
  0.upto(w-1) { |i|
    0.upto(h-1) { |j|
      done = false
      (-fatten).upto(fatten) { |di|
        ii = i+di
        if ii<0 or ii>w-1 then next end
        (-fatten).upto(fatten) { |dj|
          jj = j+dj
          if jj<0 or jj>h-1 then next end
          if has_ink(mask[ii,jj]) then image[i,j]=background_color; done=true; break end
        }
        if done then break end
      }
    }
  }
end

def assert_same_size(image,image2)
  w,h = image.width,image.height
  if image.height!=image2.height or image.width!=image2.width then 
    image.save("debug1.png")
    image2.save("debug2.png")
    die("unequal heights or widths for images being combined bitwise, #{w}x#{h} and #{image2.width}x#{image2.height}; images saved in debug1.png and debug2.png; this can happen if char_to_pat renders some characters in a fallback font that has a different line height") 
  end
  return [w,h]
end

def image_empty_copy(image)
  w,h = image.width,image.height
  return ChunkyPNG::Image.new(w,h,ChunkyPNG::Color::WHITE)
end

def bounding_box(image)
  w,h = image.width,image.height
  # find bounding box on ink
  bbox = [w,-1,h,-1] # left, right, top, bottom
  0.upto(w-1) { |i|
    0.upto(h-1) { |j|
      p = image[i,j]
      #print "#{i},#{j}    #{p>>8} #{has_ink(p)}\n"
      if has_ink(p) then
        #print "i,j=#{[i,j]}, #{p}\n"
        if i<bbox[0] then bbox[0]=i end
        if i>bbox[1] then bbox[1]=i end
        if j<bbox[2] then bbox[2]=j end
        if j>bbox[3] then bbox[3]=j end
      end
    }
  }
  return bbox
end

def project_onto_y(image,lo_col,hi_col)
  n = image.height
  proj = []
  0.upto(image.height-1) { |j|
    x = 0.0
    0.upto(image.width-1) { |i|
      x = x+color_to_ink(image[i,j])
    }
    proj.push(x)
  }
  return proj
end

def random_sample(image,n_points,threshold,scale)
  # Try to efficiently and fairly take a sample not containing any duplicated points.
  # If n_points is comparable to or greater than the number of pixels in the image, then
  # nothing really bad happens except that the details of the sampling will not be quite
  # statistically ideal. If n_points is greater than the number of pixels, then we only
  # take a number of samples equal to the number of pixels (or nearly so).
  # Use with threshold:
  # If threshold is not nil, then we only return results that appear to be in or near actual text (as opposed to margins or other
  # large regions of whitespace). There must be a pixel over threshold within the distance scale.
  # This will be much, much slower.
  sample = []
  w = image.width
  h = image.height
  n = w*h
  if n_points>w*h then n_points=n end
  lambda = n_points.to_f/n # probability that a given point will be sampled
  z0 = rand(n) # index of point currently being sampled
  z1 = 0 # should end up being approximately equal to n-1
  0.upto(n_points-1) { |count|
    z = z0+z1
    k = z%n
    i = k%w
    j = k/w
    if not threshold.nil? then
      hit = false
      (i-scale).upto(i+scale) { |ii|
        if ii<0 or ii>w-1 then next end
        (j-scale).upto(j+scale) { |jj|
          if jj<0 or jj>h-1 then next end
          if color_to_ink(image[ii,jj])>threshold then hit=true; break end
        }
        if hit then break end
      }
    else
      hit = true
    end
    if hit then sample.push(color_to_ink(image[i,j])) end
    # Wait time between events in a Poisson process is exponentially distributed. Generate a number with an exponential distribution.
    # https://www.eg.bucknell.edu/~xmeng/Course/CS6337/Note/master/node50.html
    y = rand # uniform (0,1)
    x = -Math::log(1-y)/lambda
    step = x.round
    if lambda>0.1 and step>1 and z1/(n-1).to_f>count/(n_points-1).to_f then
      # Because we forbid step=0, when lambda is large there will be a systematic bias toward too-large step sizes.
      step=step/2 # Take a baby step to compensate.
    end
    if step<1 then step=1 end
    z1 = z1+step
  }
  return sample
end

def has_ink(color)
  # color is a ChunkyPNG::Color
  # https://rdoc.info/gems/chunky_png/ChunkyPNG/Color
  # alpha = color & 0xff ... is always 255
  # This only tests whether or not the color is totally white, so use only on artificially constructed images, not camera data.
  rgb = (color >> 8)
  return (rgb != 0xffffff)
end

def enhance_contrast(image,background,threshold,dark)
  # changes the image in place
  # leaves threshold in place, but pushes more pixels closer to background and dark values
  # This may help for scans of old books set with lead type, where some letters come out faint. The faintness reduces correlations a *lot*.
  w,h = image.width,image.height
  0.upto(w-1) { |i|
    0.upto(h-1) { |j|
      x = color_to_ink(image[i,j])
      x = enhance_contrast_one_pixel(x,background,threshold,dark)
      x = ink_to_color(x)
      image[i,j] = x
    }
  }
end

def enhance_contrast_one_pixel(x,background,threshold,dark)
  # inputs x, which is a ChunkyPNG color; returns an ink value on [0,1]
  xx = (contrast_helper(x,background,threshold,dark)-background)/(dark-background)
  if xx<-0.0001 or xx>1.0001 then
    die("coding error, output of enhance_contrast_one_pixel is not in [0,1], x,xx,background,threshold,dark=#{[x,xx,background,threshold,dark]}")
  end
  return xx
end

def contrast_helper(x,background,threshold,dark)
  if x>dark then return dark end
  if x<background then return background end
  if x>threshold then return threshold+contrast_helper2(x-threshold,dark-threshold) end
  # The remaining case is where it's between background and threshold.
  # Tried two possibilities: (1) enhance it using the same kind of curve as above threshold, but rotated 180 degrees; (2) leave it alone.
  # Doing 1 worsens dropouts where the ink is faint.
  # Doing 2 leaves a lot of cruft in the background.
  # Decided 1 was better.
  return threshold-contrast_helper2(-(x-threshold),-(background-threshold)) # ... option 1
  # return x # ... option 2
end

def contrast_helper2(x,max)
  # x is in [0,max], output is in [0,max]
  xx = x.to_f/max.to_f
  # Find a function that takes [0,1] to [0,1], is quadratic, and has slope b at x=0.
  # That function is ax^2+bx+c, where c=0, 1=a+b+c, and s=b.
  # b=1 gives no enhancement, b=2 is the maximum that doesn't result in a non-monotonic function.
  # b=2 is equivalent to rotating the page 180 degrees, squaring the function, and then rotating back.
  # To get more enhancement, could do the equivalent of b=2, but with a higher exponent, but this would be slower.
  b = 2.0
  y = (1.0-b)*xx*xx+b*xx
  return y*max
end
