#!/bin/ruby
# coding: utf-8

require 'oily_png'
  # ubuntu package ruby-oily-png

def main()
  temp_dir = 'temp'
  if not File.exists?(temp_dir) then Dir.mkdir(temp_dir) end
  f = Font.new()
  print f.pango_string,"\n"
  char_to_pat('εχΗ',temp_dir,f)
end

def char_to_pat(c,dir,font)
  out_file = dir+"/"+"temp2.png"
  image = string_to_image(c,dir,font,out_file,0)
  image2 = string_to_image(c+"H",dir,font,out_file,0)
  if image.height!=image2.height then die("unequal heights for images") end
  bbox = bounding_box(image)
  print "bounding box=#{bbox}\n"
  red = image_minus(image2,image)
  red.save("foo.png")
end

def image_minus(image,image2)
  return image_bitwise(image,image2,lambda { |x,y| x and !y})
end

def image_bitwise(image,image2,op)
  w,h = image.width,image.height
  if image.height!=image2.height or image.width!=image2.width then die("unequal heights or widths for images") end
  result = ChunkyPNG::Image.new(w,h,ChunkyPNG::Color::WHITE)
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

def string_to_image(s,dir,font,out_file,side)
  # side=0 for left, 1 for right
  # empirically, pango-view seems to return a result whose height doesn't depend on the input
  pango_font = font.pango_string()
  in_file = dir+"/"+"temp1.txt"
  File.open(in_file,'w') { |f|
    f.print s
  }
  if side==0 then align="left" else align="right" end
  # pango-view --align=right --markup --font="Times italic 32" --width=500 --text="γράψετε" -o a.png
  cmd = "pango-view -q --align=#{side} --margin 0 --font=\"#{pango_font}\" --width=200 -o #{out_file} #{in_file}"
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
