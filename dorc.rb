#!/bin/ruby
# coding: utf-8

require 'oily_png'
  # ubuntu package ruby-oily-png

require_relative "lib/fft"

def main()

  text = ChunkyPNG::Image.from_file('sample.png')
  proj = []
  0.upto(text.height-1) { |j|
    x = 0.0
    0.upto(text.width-1) { |i|
      x = x+ink(text[i,j])
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
  guess_dpi = 150
  guess_font_size = 12
  guess_period = 0.04*guess_dpi*guess_font_size
  guess_freq = (nn*0.5/guess_period).to_i # Is the 0.5 right, Nyquist frequency?
  print "guess_period=#{guess_period} guessing frequency=#{guess_freq}, out of nn=#{nn}\n"
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
  period = nn/best
  print "best freq=#{best}, period=#{period}\n"
  exit(0)

  temp_dir = 'temp'
  if not File.exists?(temp_dir) then Dir.mkdir(temp_dir) end
  f = Font.new()
  print f.pango_string,"\n"
  dpi = 72
  bw,red = char_to_pat('ε',temp_dir,f,dpi)
  bw.save('bw.png')
  red.save('red.png')

end

def ink(color) # returns a measure of darkness
  r,g,b = ChunkyPNG::Color.r(color),ChunkyPNG::Color.g(color),ChunkyPNG::Color.b(color)
  return 1.0-(r+g+b)/(3.0*255.0)
end

def char_to_pat(c,dir,font,dpi)
  out_file = dir+"/"+"temp2.png"
  image = []
  bbox = []
  red = []
  0.upto(1) { |side|
    image.push(string_to_image(c,dir,font,out_file,side,dpi))
    bbox.push(bounding_box(image[side]))
    red.push(red_one_side(c,dir,font,out_file,side,image[side],dpi))
  }
  print "bounding boxes=#{bbox}\n"
  box_w = bbox[0][1]-bbox[0][0]
  w = dpi*font.size/20
  h = image[0].height
  image_final = ChunkyPNG::Image.new(w,h,ChunkyPNG::Color::WHITE)
  red_final = ChunkyPNG::Image.new(w,h,ChunkyPNG::Color::WHITE)
  slide_to = (w-box_w)/2 # put them so the left side of the bounding box is here
  0.upto(1) { |side|
    dx = slide_to-bbox[side][0]
    0.upto(w-1) { |i|
      i0 = i-dx
      if i0<0 || i0>image[0].width-1 then next end
      0.upto(h-1) {  |j|
        if side==0 then image_final[i,j] = image[side][i0,j] end
        red_final[i,j] = red[side][i0,j]
      }
    }
  }
  return [image_final,red_final]
end

def red_one_side(c,dir,font,out_file,side,image,dpi)
  red = image_empty_copy(image)
  if side==0 then other = "iAWTS1!HIμ.,;:'{{-_=|\`~?/" else other="!]':?>HIT1iXo" end
  other.chars.each { |c2|
    if side==0 then s=c+c2 else s=c2+c end
    image2 = string_to_image(s,dir,font,out_file,side,dpi)
    red = image_or(red,image_minus(image2,image))
  }
  bbox = bounding_box(image)
  erase_inside_box(red,bbox) # when side=1, text is not aligned in precisely the same spot every time, varies by ~1 pixel
  w,h = image.width,image.height
  0.upto(h-1) { |j|
    started = false
    0.upto(w-1) { |ii|
      if side==1 then i=w-1-ii else i=ii end
      if has_ink(red[i,j]) then started=true end
      if started then red[i,j]=ChunkyPNG::Color::BLACK end
    }
  }
  return red
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

def has_ink(color)
  # https://rdoc.info/gems/chunky_png/ChunkyPNG/Color
  # alpha = color & 0xff ... is always 255
  # Or should I be comparing with ChunkyPNG::Color::WHITE or something?
  rgb = (color >> 8)
  return (rgb != 0xffffff)
end

def string_to_image(s,dir,font,out_file,side,dpi)
  # side=0 for left, 1 for right
  # empirically, pango-view seems to return a result whose height doesn't depend on the input
  pango_font = font.pango_string()
  in_file = dir+"/"+"temp1.txt"
  File.open(in_file,'w') { |f|
    f.print s
  }
  if side==0 then align="left" else align="right" end
  # pango-view --align=right --dpi=#{dpi} --markup --font="Times italic 32" --width=500 --text="γράψετε" -o a.png
  cmd = "pango-view -q --align=#{align} --margin 0 --font=\"#{pango_font}\" --width=200 -o #{out_file} #{in_file}"
  system(cmd)
  image = ChunkyPNG::Image.from_file(out_file)
  return image
end

class Font
  def initialize(serif:true,italic:false,bold:false,size:12)
    @serif,@italic,@bold,@size = serif,italic,bold,size
  end

  def pango_string()
    a = []
    if @serif then a.push("serif") else a.push("sans") end
    if @italic then a.push("italic") end
    if @bold then a.push("bold") end
    a.push(size.to_s)
    return a.join(' ')
  end

  attr_reader :serif,:italic,:bold,:size
end

def die(message)
  $stderr.print message,"\n"
  exit(-1)
end

main()
