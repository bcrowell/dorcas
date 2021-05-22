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
require_relative "lib/other_interpreters"
require_relative "lib/string_util"

def main()


  f = Font.new(font_name:"GFSPorson",serif:false,italic:true)
  print f;
  exit(0)

  text_file = 'sample.png'
  spacing_multiple = 1.0 # set to 2 if double-spaced

  temp_dir = 'temp'
  if not File.exists?(temp_dir) then Dir.mkdir(temp_dir) end

  text = ChunkyPNG::Image.from_file(text_file)
  print "Input file is #{text_file}\n"
  stats = ink_stats_1(text)
  peak_to_bg = stats['dark']/stats['submedian']
  text_line_spacing,x_height = estimate_scale(text,peak_to_bg,spacing_multiple:spacing_multiple)
  print "text_line spacing=#{text_line_spacing}, x_height=#{x_height}\n"
  stats = ink_stats_2(text,stats,(text_line_spacing*0.3).round)
  print "ink stats=#{stats}\n"
  if x_height<0.35*text_line_spacing/spacing_multiple then 
    warn("x-height appears to be small compared to line spacing for spacing_multiple=#{spacing_multiple}")
  end

  # The result of all this is that text_line_spacing is quite robust and fairly precise, whereas x_height is
  # total crap, should probably not be used for anything more than the warning above.
  # Although the value of text_line_spacing is good, the way I'm using it in setting the font size is
  # not super great, sometimes results in a font whose size is wrong by 15%.

  threshold = 0.65 # lowest correlation that we consider to be of interest

  if true then
    char = 'ε'

    #f = Font.new(font_name:"BosporosU",serif:false,italic:true)
    # threshold = 0.8 # with system default font, worked OK at 0.4
    # text_line_spacing *= 0.85

    f = Font.new(font_name:"GFSPorson",serif:false,italic:true)
    threshold = 0.5
    text_line_spacing *= 1.2
  end
  if false then
    char = 'π'
    f = Font.new(serif:false,italic:true)
    threshold = 0.75
    text_line_spacing *= 0.85
  end
  if false then
    char = 'h'
    f = Font.new(serif:true,italic:false)
  end

  print "character=#{char}, ",f.pango_string,"\n"

  # estimate scale so that pattern has resolution approximately equal to that of text
  dpi = 300 # initial guess
  dpi = (dpi*text_line_spacing.to_f/f.line_height_pixels(temp_dir,dpi).to_f).round
  background = stats['submedian'] # background ink level of text, in ink units

  bw,red,pat_line_spacing,bbox = char_to_pat(char,temp_dir,f,dpi)
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
  pat_stats = ink_stats_pat(bw_ink,red_ink) # calculates mean and sd
  print "pat_stats=#{pat_stats}\n"

  sdt = stats['sd_in_text']
  sdp = pat_stats['sd']
  norm = sdt*sdp # normalization factor for correlations
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
  results = correl_many(text_ink,bw_ink,red_ink,background,i_lo,i_hi,j_lo,j_hi,text_line_spacing.to_i,norm)

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
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

def warn(message)
  $stderr.print "****************************************************************************************************************\n"
  $stderr.print "              WARNING\n"
  $stderr.print message,"\n"
  $stderr.print "****************************************************************************************************************\n"
end

main()

