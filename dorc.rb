#!/bin/ruby
# coding: utf-8

require 'oily_png'
  # ubuntu package ruby-oily-png

require_relative "lib/fft"
require_relative "lib/estimate_scale.rb"
require_relative "lib/image_util.rb"
require_relative "lib/font_to_pat.rb"
require_relative "lib/correl.rb"
require_relative "lib/svg.rb"

def main()
  temp_dir = 'temp'
  text_file = 'sample_small.png'


  if not File.exists?(temp_dir) then Dir.mkdir(temp_dir) end

  text = ChunkyPNG::Image.from_file(text_file)
  text_line_spacing = estimate_line_spacing(text,window:'hann')
  print "text_line spacing=#{text_line_spacing}\n"

  f = Font.new()
  print f.pango_string,"\n"

  # estimate scale so that pattern has resolution approximately equal to that of text multiplied by hires, which should be a power of 2
  hires = 1
  dpi = 300 # initial guess
  dpi = (hires*dpi*text_line_spacing.to_f/f.line_height_pixels(temp_dir,dpi).to_f).round
  background = 0.0 # background ink level of text; should actually estimate this, e.g., take median and then take median of everything below that

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
  j_lo.upto(j_hi) { |j|
    print (j*100.0/j_hi).round," "
    if j%30==0 then print "\n" end
    i_lo.upto(i_hi) { |i|
      c = correl(text_ink,bw_ink,red_ink,bbox,i,j,background)
      results[i][j] = c
      if c>threshold then
        ci = (i+wp/2).round
        cj = (j+hp/2).round
        #print "\n  center,correl=#{ci},#{cj},#{c}\n"
        #if c>highest_corr then highest_corr=c; print "    **\n" end
      end
    }
  }

  hits = []
  xr = ((bbox[1]-bbox[0])*0.8).round
  yr = ((bbox[3]-bbox[2])*0.8).round
  (j_lo+yr).upto(j_hi-yr) { |j|
    (i_lo+xr).upto(i_hi-xr) { |i|
      if results[i][j]>threshold then
        c = results[i][j]
        local_max = true
        (-xr).upto(xr) { |di|
          (-yr).upto(yr) { |dj|
            if results[i+di][j+dj]>c then local_max=false end
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

  images = []
  hits.each { |hit|
    i,j = hit
    images.push(["bw.png",i,j,bw.width,bw.height,1.0])
  }
  images.push([text_file,0,0,text.width,text.height,0.25])
  svg = svg_view(images,150.0)
  File.open('a.svg','w') { |f| f.print svg }
end


def die(message)
  $stderr.print message,"\n"
  exit(-1)
end

main()

