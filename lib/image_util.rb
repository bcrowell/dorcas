def image_any_type_to_chunky(x,grayscale:true)
  # Input x can be a ChunkyPNG object, the filename of a png file, or an ink array, and will be autodetected by x's type.
  # Returns a ChunkyPNG object.
  if x.class == String then return image_from_file_to_grayscale(x) end
  if x.class == Array then return ink_array_to_image(x,grayscale:true) end
end

def image_from_file_to_grayscale(filename)
  return ChunkyPNG::Image.from_file(filename).grayscale
  # ... Conversion to grayscale can in principle be complicated. E.g., simply adding
  #     r+b+g is very inaccurate. However, we don't really care for our application.
  #     Note that this may be different from what PIL does, so to avoid confusion
  #     about normalization, never provide color images to PIL.
end

def pad_image(image,w,h,background)
  # Given a ChunkyPNG object, returns a new copy that has been padded to the indicated size, using a background color given in ink units.
  return ChunkyPNG::Image.new(w,h,bg_color=ink_to_color(background)).replace(image,offset_x=0,offset_y=0)
end

def ink_array_to_image(ink,transpose:false,grayscale:true)
  # Input should consist of ink values, i.e., 0 to 1.0 and should be stored in [col][row] order.
  # Returns a grayscale object by default.
  w,h = ink_array_dimensions(ink)
  if transpose then w2,h2=h,w else w2,h2=w,h end
  im = ChunkyPNG::Image.new(w2,h2,ChunkyPNG::Color::WHITE)
  0.upto(w2-1) { |i|
    0.upto(h2-1) { |j|
      if transpose then
        im[i,j] = ink_to_color(ink[j][i])
      else
        im[i,j] = ink_to_color(ink[i][j])
      end
    }
  }
  if grayscale then im=im.grayscale end
  return im
end

def image_to_ink_array(image)
  w,h = image.width,image.height
  return generate_array(w,h,lambda {|i,j| color_to_ink(image[i,j]) })
end

def image_fingerprint(image)
  # input is a chunkypng object
  w,h = image.width,image.height
  result = 0
  0.upto(w-1) { |i|
    0.upto(w-1) { |j|
      color = image[i,j]
      r,g,b = ChunkyPNG::Color.r(color),ChunkyPNG::Color.g(color),ChunkyPNG::Color.b(color)
      result = result + r+b+g
    }
  }
  return result
end

def ink_array_fingerprint(image)
  w,h = ink_array_dimensions(image)
  result = 0.0
  0.upto(w-1) { |i|
    0.upto(w-1) { |j|
      color = image[i,j]
      result = result + image[i][j]
    }
  }
  return result
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

def n_black_pixels(image)
  # Input is a chunkypng image.
  w,h = image.width,image.height
  nb = 0
  0.upto(w-1) { |i|
    0.upto(h-1) { |j|
      if color_to_ink(image[i,j])>0.5 then nb+=1 end
    }
  }
  return nb
end

def color_to_ink(color) # returns a measure of darkness
  r,g,b = ChunkyPNG::Color.r(color),ChunkyPNG::Color.g(color),ChunkyPNG::Color.b(color)
  return 1.0-(r+g+b)/(3.0*255.0)
end

def ink_to_png_8bit_grayscale(ink)
  # The output from this function has black=0 and white=255.
  # This is only needed for stuff like the interface between ruby (which uses chunkypng) and python (which uses PIL).
  # In those cases, we need to make sure that any color images are converted to grayscale in a consistent way, by chunkypng,
  # which is what we always do by reading with image_from_file_to_grayscale(). Then when we write a file for PIL to read,
  # it's already grayscale. This routine is not designed to be efficient, and there should never be any need to call it
  # on a pixel-by-pixel basis. This is for things like converting threshold values for use by python.
  z = ((1.0-ink)*255).round
  if z<0 then z=0 end
  if z>255 then z=255 end
  return z
end

def ink_to_color(ink) # inverse of color_to_ink
  gray = ((1.0-ink)*255).round
  return ChunkyPNG::Color.rgb(gray,gray,gray)
end

def compose_safe(a,b,i,j)
  # ChunkyPNG crashes if b hangs outside of a. In that situation, just silently fail.
  # Some of the ! functions like compose! seem to crash, so don't use them.
  if i+b.width>a.width-1 or j+b.height>a.height-1 then return a end
  return a.compose(b,i,j)
end

def erase_inside_box(image,bbox)
  w,h = image.width,image.height
  bbox[0].upto(bbox[1]) { |i|
    bbox[2].upto(bbox[3]) { |j|
      if i>=0 and i<=w-1 and j>=0 and j<=h-1 then image[i,j] = ChunkyPNG::Color::WHITE end
    }
  }
end

def image_minus(image,image2)
  return image_bitwise(image,image2,lambda { |x,y| x and !y})
end

def image_bitwise(image,image2,op)
  # This function seems to be a bit of a bottleneck in terms of performance, and when I hit control-C and look at a stack trace, it
  # seems like the issue is simply accessing pixels in the image. Unfortunately, I don't know how to improve that.
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

def image_or(image,image2)
  # This function seems to be a bit of a bottleneck in terms of performance, and when I hit control-C and look at a stack trace, it
  # seems like the issue is simply accessing pixels in the image. Unfortunately, I don't know how to improve that.
  # I tried converting both images to grayscale first, but that was slower.
  return image_bitwise(image,image2,lambda { |x,y| x or y})
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
  # To make the output of the program reproducible, the random sample is actually pseudorandom,
  # and is always based on the same seed every time this function is called.
  # If n_points is comparable to or greater than the number of pixels in the image, then
  # nothing really bad happens except that the details of the sampling will not be quite
  # statistically ideal. If n_points is greater than the number of pixels, then we only
  # take a number of samples equal to the number of pixels (or nearly so).
  # Use with threshold:
  # If threshold is not nil, then we only return results that appear to be in or near actual text (as opposed to margins or other
  # large regions of whitespace). There must be a pixel over threshold within the distance scale.
  # This will be much, much slower.
  prng = Random.new(0) # seed is 0
  sample = []
  w = image.width
  h = image.height
  n = w*h
  if n_points>w*h then n_points=n end
  lambda = n_points.to_f/n # probability that a given point will be sampled
  z0 = prng.rand(n) # index of point currently being sampled
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
    y = prng.rand # uniform (0,1)
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

def enhance_contrast(image,background,threshold,dark,do_foreground:true,do_background:false,severe:false)
  # changes the image in place
  # leaves threshold in place, but pushes more pixels closer to background and dark values
  # This may help for scans of old books set with lead type, where some letters come out faint. The faintness reduces correlations a *lot*.
  # The default is to do only the foreground. This is appropriate with single images, as opposed to averages or composites.
  # Consider the case where you have a value that's above background but below threshold.
  # Tried two possibilities: (1) enhance it using the same kind of curve as above threshold, but rotated 180 degrees; (2) leave it alone.
  # Doing 1 worsens dropouts where the ink is faint.
  # Doing 2 leaves a lot of cruft in the background.
  # Decided 1 was better for single images.
  w,h = image.width,image.height
  0.upto(w-1) { |i|
    0.upto(h-1) { |j|
      x = color_to_ink(image[i,j])
      x = enhance_contrast_one_pixel(x,background,threshold,dark,do_foreground,do_background,severe)
      x = ink_to_color(x)
      image[i,j] = x
    }
  }
end

def enhance_contrast_one_pixel(x,background,threshold,dark,do_foreground,do_background,severe)
  # inputs x, which is a ChunkyPNG color; returns an ink value on [0,1]
  xx = (contrast_helper(x,background,threshold,dark,do_foreground,do_background,severe)-background)/(dark-background)
  if xx<-0.0001 or xx>1.0001 then
    die("coding error, output of enhance_contrast_one_pixel is not in [0,1], x,xx,background,threshold,dark=#{[x,xx,background,threshold,dark]}")
  end
  return xx
end

def contrast_helper(x,background,threshold,dark,do_foreground,do_background,severe)
  if x>dark then return dark end
  if x<background then return background end
  if x>threshold then
    if do_foreground then
      return threshold+contrast_helper2(x-threshold,dark-threshold,severe)
    else
      return x
    end
  end
  if do_background then
    #return background
    return threshold-contrast_helper2(-(x-threshold),-(background-threshold),severe)
  else
    return x 
  end
end

def contrast_helper2(x,max,severe)
  # x is in [0,max], output is in [0,max]
  xx = x.to_f/max.to_f
  # Find a function that takes [0,1] to [0,1], is quadratic, and has slope b at x=0.
  # That function is ax^2+bx+c, where c=0, 1=a+b+c, and s=b.
  # b=1 gives no enhancement, b=2 is the maximum that doesn't result in a non-monotonic function.
  # b=2 is equivalent to rotating the page 180 degrees, squaring the function, and then rotating back.
  b = 2.0
  y = (1.0-b)*xx*xx+b*xx
  if severe then
    if y<0.25 then y=y*4 else y=1.0 end
  end
  return y*max
end

def average_images(images)
  w,h = images[0].width,images[0].height
  n = images.length
  avg = generate_array(w,h,lambda {|i,j| 0.0})
  images.each { |im|
    if im.width!=w or im.height!=h then die("w and h don't match") end
    if im.class!=ChunkyPNG::Image then die("class of im is #{im.class}") end
  }
  0.upto(w-1) { |i|
    0.upto(h-1) { |j|
      sum = 0.0
      images.each { |im|
        sum += color_to_ink(im[i,j])
      }
      avg[i][j] = sum/n
    }
  }
  return ink_array_to_image(avg)
end

def remove_flyspecks(image,threshold,radius)
  w,h = image.width,image.height
  radius.upto(w-1-radius) { |i|
    radius.upto(h-1-radius) { |j|
      x = color_to_ink(image[i,j])
      if x>threshold then next end
      dark_nearby = false
      (-radius).upto(radius) { |di|
        (-radius).upto(radius) { |dj|
          if color_to_ink(image[i+di,j+dj])>threshold then dark_nearby=true end
        }
      }
      if !dark_nearby then 
        x = x-threshold
        if x<0 then x=0 end
        image[i,j] = ink_to_color(x)
      end
    }
  }
end
