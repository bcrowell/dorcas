class Page
  # Conceptually, this is an image of text that can't be easily split into smaller
  # pieces without knowing about line breaks and layout.
  # Both reading the PNG file and making the ink array are slow operations.
  def initialize(image,png_filename:nil)
    @image = image
    @ink = image_to_ink_array(image)
  end

  attr_accessor :image,:ink,:png_filename

  def Page.from_file(filename_raw)
    # The filename can be the name of a png file or can have the syntax foo.pdf[37] for page 37 of foo.pdf. In
    # that case, the png_filename attribute is the name of the temp file.
    if filename_raw=~/pdf\[\d+\]$/ then png_filename=extract_pdf_page(filename_raw,500) else png_filename=filename_raw end
    # ... 500 dpi is the documented behavior
    return Page.new(image_from_file_to_grayscale(png_filename),png_filename:png_filename)
  end
end
