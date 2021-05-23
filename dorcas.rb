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
require_relative "lib/clustering"
require_relative "lib/tempfile"
require_relative "lib/file_util"
require_relative "lib/constants"
require_relative "lib/smp"
require_relative "lib/graphing"
require_relative "lib/estimate_image_params"
require_relative "lib/stat"
require_relative "lib/other_interpreters"
require_relative "lib/string_util"
require_relative "lib/array_util"
require_relative "lib/reports"
require_relative "lib/svg"

def main()
  temp_dir,output_dir = create_directories()

  text_file = 'sample.png'
  spacing_multiple = 1.0 # set to 2 if double-spaced
  seed_font = Font.new(font_name:"GFSPorson")
  threshold = 0.62 # lowest correlation that we consider to be of interest
  fudge_size = 0.93
  script = Script.new('greek')

  text,stats,peak_to_bg,dpi = analyze_text_image(text_file,script,spacing_multiple)
  dpi = match_seed_font_scale(seed_font,stats,script,fudge_size)

  print seed_font
  print "font metrics: #{seed_font.metrics(dpi,script)}\n"
  print script,"\n"

  match_character('ε',text,text_file,temp_dir,output_dir,seed_font,dpi,script,threshold,stats)
end

def match_character(char,text,text_file,temp_dir,output_dir,f,dpi,script,threshold,stats)
  print "Searching for character #{char} in text file #{text_file}\n"
  pat = char_to_pat(char,temp_dir,f,dpi,script)
  print "pat.line_spacing=#{pat.line_spacing}, bbox=#{pat.bbox}\n"
  pat.bw.save('bw.png') # needed later to build svg
  pat.red.save('red.png')

  hits = match(text,pat,stats,threshold)
  matches_as_svg('a.svg',text_file,text,pat,hits)
  image = swatches(hits,text,pat,stats)
  image.save(output_dir+"/"+char+".png")
end

def analyze_text_image(text_file,script,spacing_multiple)
  text = ChunkyPNG::Image.from_file(text_file)
  print "Input file is #{text_file}\n"
  stats = ink_stats_1(text)
  peak_to_bg = stats['dark']/stats['submedian']
  text_line_spacing,x_height = estimate_scale(text,peak_to_bg,spacing_multiple:spacing_multiple)
  stats['line_spacing'] = text_line_spacing
  stats['x_height'] = x_height
  stats = ink_stats_2(text,stats,(text_line_spacing*0.3).round)
  print "ink stats:\n#{stats_to_string(stats)}"
  if x_height<0.35*text_line_spacing/spacing_multiple then 
    warn("x-height appears to be small compared to line spacing for spacing_multiple=#{spacing_multiple}")
  end
  stats['background'] = stats['submedian'] # background ink level of text, in ink units

  # The result of all this is that text_line_spacing is quite robust and fairly precise, whereas x_height is
  # total crap, should probably not be used for anything more than the warning above.
  # Although the value of text_line_spacing is good, the way I'm using it in setting the font size is
  # not super great, sometimes results in a font whose size is wrong by 15%.

  return [text,stats,peak_to_bg]
end

def match_seed_font_scale(font,stats,script,fudge_size)
  # estimate scale so that pattern has resolution approximately equal to that of text
  text_line_spacing = stats['line_spacing']*fudge_size
  dpi = 300 # initial guess
  dpi = (dpi*text_line_spacing.to_f/font.line_spacing_pixels(dpi,script).to_f).round

  return dpi
end

def create_directories()
  temp_dir = 'temp'
  if not File.exists?(temp_dir) then Dir.mkdir(temp_dir) end
  output_dir = 'output'
  if not File.exists?(output_dir) then Dir.mkdir(output_dir) end
  return [temp_dir,output_dir]
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

