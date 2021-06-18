class Page
  # Conceptually, this is an image of text that can't be easily split into smaller
  # pieces without knowing about line breaks and layout.
  # Both reading the PNG file and making the ink array are slow operations.
  # Once the analyze() method has been called, we know the proper threshold for this image, and
  # the ink? method will work on the image, which is more efficient than other methods of
  # doing nearest-neighbor logic.
  def initialize(image,png_filename:nil)
    @image = image
    @ink = image_to_ink_array(image)
    @png_filename = png_filename
    @fingerprint=file_fingerprint(@png_filename) # can be nil if the page isn't from a file, but otherwise is a hex number that is unique for this image
  end

  attr_accessor :image,:ink,:png_filename,:stats,:dpi,:peak_to_bg
  attr_reader :fingerprint

  def width
    return self.image.width
  end

  def height
    return self.image.height
  end

  def box
    return Box.new(0,self.width-1,0,self.height-1)
  end

  def Page.from_file(filename_raw,cache_dir)
    # The filename can be the name of a png file or can have the syntax foo.pdf[37] for page 37 of foo.pdf. In
    # that case, the png_filename attribute is the name of the temp file.
    dpi = 500 # this is the documented behavior when the input is a pdf
    if filename_raw=~/pdf\[\d+\]$/ then png_filename=extract_pdf_page(filename_raw,dpi,cache_dir) else png_filename=filename_raw end
    return Page.new(image_from_file_to_grayscale(png_filename),png_filename:png_filename)
  end

  def analyze(spacing_multiple,guess_dpi,guess_font_size)
    # Has the side-effect of mixing in Fat module for efficiency.
    print "Input file is #{self.png_filename}\n"
    s = ink_stats_1(self.image,self.ink)
    self.peak_to_bg = s['dark']/s['submedian']
    text_line_spacing,x_height = estimate_scale(self.image,self.peak_to_bg,
                        spacing_multiple:spacing_multiple,guess_dpi:guess_dpi,guess_font_size:guess_font_size)
    s['line_spacing'] = text_line_spacing
    s['x_height'] = x_height
    s = ink_stats_2(self.image,self.ink,s,(text_line_spacing*0.3).round)
    print "ink stats:\n#{stats_to_string(s)}"
    if x_height<0.35*text_line_spacing/spacing_multiple then 
      warn("x-height appears to be small compared to line spacing for spacing_multiple=#{spacing_multiple}")
    end
    s['background'] = s['submedian'] # background ink level of text, in ink units

    # The result of all this is that text_line_spacing is quite robust and fairly precise, whereas x_height is
    # total crap, should probably not be used for anything more than the warning above.
    # Although the value of text_line_spacing is good, the way I'm using it in setting the font size is
    # not super great, sometimes results in a font whose size is wrong by 15%.
 
    self.stats = s

    Fat.bless(self.image,s['threshold'])
  end

end


def match_seed_font_scale(font,stats,script,fudge_size)
  # estimate scale so that pattern has resolution approximately equal to that of text
  text_line_spacing = stats['line_spacing']*fudge_size
  dpi = 300 # initial guess
  dpi = (dpi*text_line_spacing.to_f/font.line_spacing_pixels(dpi,script).to_f).round

  return dpi.round
end


