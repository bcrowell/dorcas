def image_to_ink_array(image)
  w,h = image.width,image.height
  ink = []
  0.upto(w-1) { |i|
    col = []
    0.upto(h-1) { |j|
      col.push(color_to_ink(image[i,j]))
    }
    ink.push(col)
  }
  return ink
end

def ink_array_dimensions(a)
  return [a.length,a[0].length]
end

def color_to_ink(color) # returns a measure of darkness
  r,g,b = ChunkyPNG::Color.r(color),ChunkyPNG::Color.g(color),ChunkyPNG::Color.b(color)
  return 1.0-(r+g+b)/(3.0*255.0)
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
  w,h = image.width,image.height
  if image.height!=image2.height or image.width!=image2.width then die("unequal heights or widths for images") end
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

def project_onto_y(image)
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

def random_sample(image,n_points)
  # Try to efficiently and fairly take a sample not containing any duplicated points.
  # If n_points is comparable to or greater than the number of pixels in the image, then
  # nothing really bad happens except that the details of the sampling will not be quite
  # statistically ideal. If n_points is greater than the number of pixels, then we only
  # take a number of samples equal to the number of pixels (or nearly so).
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
    sample.push(color_to_ink(image[i,j]))
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
  # https://rdoc.info/gems/chunky_png/ChunkyPNG/Color
  # alpha = color & 0xff ... is always 255
  # Or should I be comparing with ChunkyPNG::Color::WHITE or something?
  rgb = (color >> 8)
  return (rgb != 0xffffff)
end
