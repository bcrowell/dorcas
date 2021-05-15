#!/bin/ruby
# coding: utf-8

require 'oily_png'
  # ubuntu package ruby-oily-png

require_relative "lib/fft"
require_relative "lib/estimate_scale.rb"
require_relative "lib/image_util.rb"
require_relative "lib/font_to_pat.rb"
require_relative "lib/correl.rb"

def main()
  temp_dir = 'temp'
  if not File.exists?(temp_dir) then Dir.mkdir(temp_dir) end

  text = ChunkyPNG::Image.from_file('sample.png')
  text_line_spacing = estimate_line_spacing(text)
  print "text_line spacing=#{text_line_spacing}\n"

  f = Font.new()
  print f.pango_string,"\n"

  # estimate scale so that pattern has resolution approximately equal to that of text multiplied by hires, which should be a power of 2
  hires = 1
  dpi = 300 # initial guess
  dpi = (hires*dpi*text_line_spacing.to_f/f.line_height_pixels(temp_dir,dpi).to_f).round

  bw,red,pat_line_spacing,bbox = char_to_pat('ε',temp_dir,f,dpi)
  print "pat_line_spacing=#{pat_line_spacing}\n"
  bw.save('bw.png')
  red.save('red.png')

  scale = text_line_spacing/pat_line_spacing

  wt,ht = text.width,text.height
  wp,hp = bw.width,bw.height
  wbox = bbox[1]-bbox[0]+1 # width of black
  lbox = bbox[0] # left side of black
  rbox = bbox[1] # right side of black

  text_ink = image_to_ink_array(text)
  bw_ink = image_to_ink_array(bw)
  red_ink = image_to_ink_array(red)

  # i and j are horizontal and vertical offsets of pattern relative to text; non-black part of pat can stick out beyond edges
  (bbox[2]-pat_line_spacing).upto(ht-1+bbox[3]) { |j|
    print "j=#{j}\n"
    (-lbox).upto(wt-1-rbox) { |i|
      c = correl(text_ink,bw_ink,red_ink,i,j)
      if c>0.02 then
        ci = (i+wp/2).round
        cj = (j+hp/2).round
        print "  center,correl=#{ci},#{cj},#{c}\n"
      end
    }
  }
end


def die(message)
  $stderr.print message,"\n"
  exit(-1)
end

main()
