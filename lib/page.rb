class Page
  # Conceptually, this is an image of text that can't be easily split into smaller
  # pieces without knowing about line breaks and layout.
  # Both reading the PNG file and making the ink array are slow operations.
  def initialize(image,png_filename:nil)
    @image = image
    @ink = image_to_ink_array(image)
    @png_filename = png_filename
  end

  attr_accessor :image,:ink,:png_filename

  def width
    return self.image.width
  end

  def height
    return self.image.height
  end

  def Page.from_file(filename_raw)
    # The filename can be the name of a png file or can have the syntax foo.pdf[37] for page 37 of foo.pdf. In
    # that case, the png_filename attribute is the name of the temp file.
    if filename_raw=~/pdf\[\d+\]$/ then png_filename=extract_pdf_page(filename_raw,500) else png_filename=filename_raw end
    # ... 500 dpi is the documented behavior
    return Page.new(image_from_file_to_grayscale(png_filename),png_filename:png_filename)
  end
end

def analyze_text_image(page,spacing_multiple,guess_dpi,guess_font_size)
  print "Input file is #{page.png_filename}\n"
  stats = ink_stats_1(page.image,page.ink)
  peak_to_bg = stats['dark']/stats['submedian']
  text_line_spacing,x_height = estimate_scale(page.image,peak_to_bg,spacing_multiple:spacing_multiple,guess_dpi:guess_dpi,guess_font_size:guess_font_size)
  stats['line_spacing'] = text_line_spacing
  stats['x_height'] = x_height
  stats = ink_stats_2(page.image,page.ink,stats,(text_line_spacing*0.3).round)
  print "ink stats:\n#{stats_to_string(stats)}"
  if x_height<0.35*text_line_spacing/spacing_multiple then 
    warn("x-height appears to be small compared to line spacing for spacing_multiple=#{spacing_multiple}")
  end
  stats['background'] = stats['submedian'] # background ink level of text, in ink units

  # The result of all this is that text_line_spacing is quite robust and fairly precise, whereas x_height is
  # total crap, should probably not be used for anything more than the warning above.
  # Although the value of text_line_spacing is good, the way I'm using it in setting the font size is
  # not super great, sometimes results in a font whose size is wrong by 15%.

  return [stats,peak_to_bg]
end

def match_seed_font_scale(font,stats,script,fudge_size)
  # estimate scale so that pattern has resolution approximately equal to that of text
  text_line_spacing = stats['line_spacing']*fudge_size
  dpi = 300 # initial guess
  dpi = (dpi*text_line_spacing.to_f/font.line_spacing_pixels(dpi,script).to_f).round

  return dpi
end
