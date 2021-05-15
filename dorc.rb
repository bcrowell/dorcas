#!/bin/ruby
# coding: utf-8

require 'oily_png'
  # ubuntu package ruby-oily-png

require_relative "lib/fft"
require_relative "lib/estimate_scale.rb"
require_relative "lib/image_util.rb"
require_relative "lib/font_to_pat.rb"

def main()
  temp_dir = 'temp'
  if not File.exists?(temp_dir) then Dir.mkdir(temp_dir) end

  text = ChunkyPNG::Image.from_file('sample.png')
  text_line_spacing = estimate_line_spacing(text)
  print "text_line spacing=#{text_line_spacing}\n"

  f = Font.new()
  print f.pango_string,"\n"

  # estimate scale so that pattern matches text
  dpi = 300 # initial guess
  dpi = (dpi*text_line_spacing.to_f/f.line_height_pixels(temp_dir,dpi).to_f).round

  bw,red,pat_line_spacing = char_to_pat('ε',temp_dir,f,dpi)
  print "pat_line_spacing=#{pat_line_spacing}\n"
  bw.save('bw.png')
  red.save('red.png')

  scale = text_line_spacing/pat_line_spacing

  wt,ht = text.width,text.height
  ink = image_to_ink_array(text)
end


def die(message)
  $stderr.print message,"\n"
  exit(-1)
end

main()
