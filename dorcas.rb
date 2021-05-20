#!/bin/ruby
# coding: utf-8

require 'oily_png'
  # ubuntu package ruby-oily-png

require_relative "lib/fft"
require_relative "lib/estimate_scale"
require_relative "lib/image_util"
require_relative "lib/font_to_pat"
require_relative "lib/correl"
require_relative "lib/svg"
require_relative "lib/tempfile"
require_relative "lib/file_util"
require_relative "lib/constants"
require_relative "lib/smp"
require_relative "lib/graphing"
require_relative "lib/estimate_image_params"
require_relative "lib/stat"
require_relative "lib/r_interface"

def main()
  temp_dir = 'temp'
  text_file = 'sample.png'

  if not File.exists?(temp_dir) then Dir.mkdir(temp_dir) end

  text = ChunkyPNG::Image.from_file(text_file)
  print "Input file is #{text_file}\n"
  stats = ink_stats_1(text)
  peak_to_bg = stats['dark']/stats['submedian']
  text_line_spacing,font_height = estimate_scale(text,peak_to_bg)
  print "text_line spacing=#{text_line_spacing}\n"
  stats = ink_stats_2(text,stats,(text_line_spacing*0.3).round)
  print "ink stats=#{stats}\n"

  exit(0)

  f = Font.new()
  print f.pango_string,"\n"

  # estimate scale so that pattern has resolution approximately equal to that of text multiplied by hires, which should be a power of 2
  hires = 1
  dpi = 300 # initial guess
  dpi = (hires*dpi*text_line_spacing.to_f/f.line_height_pixels(temp_dir,dpi).to_f).round
  background = stats['submedian'] # background ink level of text, in ink units

  bw,red,pat_line_spacing,bbox = char_to_pat('ε',temp_dir,f,dpi)
  print "pat_line_spacing=#{pat_line_spacing}, bbox=#{bbox}\n"
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

  threshold = 0.03 # lowest inner product that we consider to be of interest
  # i and j are horizontal and vertical offsets of pattern relative to text; non-black part of pat can stick out beyond edges
  j_lo = bbox[2]-pat_line_spacing
  j_hi = ht-1+bbox[3]
  i_lo = -lbox
  i_hi = wt-1-rbox
  results = []
  i_lo.upto(i_hi) { |i|
    col = []
    j_lo.upto(j_hi) { |j|
      col.push(nil)
    }
    results.push(col)
  }
  highest_corr = 0.0
  results = correl_many(text_ink,bw_ink,red_ink,background,i_lo,i_hi,j_lo,j_hi,text_line_spacing.to_i)

  hits = []
  xr = ((bbox[1]-bbox[0])*0.8).round
  yr = ((bbox[3]-bbox[2])*0.8).round
  (j_lo+yr).upto(j_hi-yr) { |j|
    (i_lo+xr).upto(i_hi-xr) { |i|
      c = results[j-j_lo][i-i_lo]
      if c>threshold then
        local_max = true
        (-xr).upto(xr) { |di|
          (-yr).upto(yr) { |dj|
            if results[j+dj-j_lo][i+di-i_lo]>c then local_max=false end
          }
        }
        if local_max then
          ci = (i+wp/2).round
          cj = (j+hp/2).round
          print " local max: center,correl=#{ci},#{cj},#{c}\n"
          hits.push([i,j])
        end
      end
    }
  }

  svg_filename = 'a.svg'
  print "Writing svg file #{svg_filename}\n"
  images = []
  hits.each { |hit|
    i,j = hit
    images.push(["bw.png",i,j,bw.width,bw.height,1.0])
  }
  images.push([text_file,0,0,text.width,text.height,0.25])
  svg = svg_view(images,150.0)
  File.open(svg_filename,'w') { |f| f.print svg }
end


def die(message)
  $stderr.print message,"\n"
  exit(-1)
end

main()

