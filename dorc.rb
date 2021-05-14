#!/bin/ruby
# coding: utf-8

def main()
  temp_dir = 'temp'
  if not File.exists?(temp_dir) then Dir.mkdir(temp_dir) end
  f = Font.new()
  print f.pango_string,"\n"
  char_to_pat('β',temp_dir,f)
end

def char_to_pat(c,dir,font)
  # pango-view --align=right --markup --font="Times italic 32" --width=500 --text="γράψετε" -o a.png
  out_file = dir+"/"+"temp2.png"
  string_to_image(c,dir,font,out_file)
end

def string_to_image(s,dir,font,out_file)
  pango_font = font.pango_string()
  in_file = dir+"/"+"temp1.txt"
  File.open(in_file,'w') { |f|
    f.print s
  }
  cmd = "pango-view -q --align=left --font=\"#{pango_font}\" --width=500 -o #{out_file} #{in_file}"
  system(cmd)
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


main()
