#!/bin/ruby
# coding: utf-8

require 'oily_png'
  # ubuntu package ruby-oily-png
require 'json'

require_relative "lib/match"
require_relative "lib/fft"
require_relative "lib/estimate_scale"
require_relative "lib/image_util"
require_relative "lib/font"
require_relative "lib/script"
require_relative "lib/pat"
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
  stats['line_spacing'] = text_line_spacing
  stats['x_height'] = x_height
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
    threshold = 0.62
    text_line_spacing *= 0.93
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

  script = Script.new('greek')

  # estimate scale so that pattern has resolution approximately equal to that of text
  dpi = 300 # initial guess
  dpi = (dpi*text_line_spacing.to_f/f.line_spacing_pixels(dpi,script).to_f).round
  stats['background'] = stats['submedian'] # background ink level of text, in ink units

  print f
  print "font metrics: #{f.metrics(dpi,script)}\n"
  print script,"\n"
  print "character: #{char}\n"

  pat = char_to_pat(char,temp_dir,f,dpi,script)
  print "pat.line_spacing=#{pat.line_spacing}, bbox=#{pat.bbox}\n"
  pat.bw.save('bw.png')
  pat.red.save('red.png')

  hits = match(text,pat,stats,threshold)

  svg_filename = 'a.svg'
  print "Writing svg file #{svg_filename}\n"
  images = []
  hits.each { |hit|
    i,j = hit
    images.push(["bw.png",i,j,pat.bw.width,pat.bw.height,1.0])
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

