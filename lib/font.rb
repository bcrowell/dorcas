class Font
  def initialize(font_name:nil,file_path:nil,serif:true,italic:false,bold:false,size:12)
    # The most reliable way to specify a font us by using file_path and size.
    # If using font_name, then it needs to be a font name that is recognized by fc-match. For example,
    # on my system 'fc-match BosporosU' verifies that such a font is installed, as opposed to giving some fallback font.
    # Use of serif, italic, and bold args is not implemented. This is difficult to do well because most fonts do not contain multiple styles.
    # If, e.g., you need italics, it's best to explicitly name a .ttf file that is a purely italic font.
    @serif,@italic,@bold,@size = serif,italic,bold,size
    # font_name is, e.g., "BosporosU" if the font is in BosporosU.ttf in one of the standard locations
    if (not font_name.nil?) and file_path.nil? then
      file_path = `fc-match -f "%{file}" #{font_name}`
    end
    if not file_path.nil? then
      font_name = `fc-query -f "%{family}" #{file_path}`
    end
    @font_name,@file_path = font_name,file_path
  end

  def to_s()
    if false then # not implemented
      styling = "bold: #{self.bold} italic: #{self.italic} serif: #{self.serif} "
    else
      styling = ''
    end
    result = "Font:\n  name: #{self.font_name}\n  file: #{self.file_path}\n #{styling} size: #{self.size}\n"
  end

  def pango_string()
    # Ignores file_path because pango doesn't seem to allow explicit naming of font files.
    a = []
    if not @font_name.nil? then 
      a.push(@font_name)
    else
      if !@serif then a.push("sans") end
      # E.g., doing "BosporosU sans" causes it to fall back on some other sans serif font rather than Bosporos.
      # There is no recognized keyword 'serif', only a keyword 'sans'.
    end
    if @italic then a.push("italic") end
    if @bold then a.push("bold") end
    a.push(size.to_s)
    return a.join(' ')
  end

  def line_height_pixels(dir,dpi,script)
    image = string_to_image_pango_view(script.full_height_string(),dir,self,"test_line_height.png",0,dpi)
    return image.height
  end

  attr_reader :serif,:italic,:bold,:size,:font_name,:file_path
end
