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

def has_ink(color)
  # https://rdoc.info/gems/chunky_png/ChunkyPNG/Color
  # alpha = color & 0xff ... is always 255
  # Or should I be comparing with ChunkyPNG::Color::WHITE or something?
  rgb = (color >> 8)
  return (rgb != 0xffffff)
end
