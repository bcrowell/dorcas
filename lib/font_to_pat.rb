# coding: utf-8

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

  def line_height_pixels(dir,dpi)
    image = string_to_image("A",dir,self,"test_line_height.png",0,dpi)
    return image.height
  end

  attr_reader :serif,:italic,:bold,:size,:font_name,:file_path
end

def char_to_pat(c,dir,font,dpi)
  bw,red,line_spacing,bbox = char_to_pat_without_cropping(c,dir,font,dpi)
  # for each column in red, count number of red pixels
  w,h = red.width,red.height
  nred = []
  0.upto(w-1) { |i|
    count = 0
    0.upto(h-1) { |j|
      if has_ink(red[i,j]) then count += 1 end
    }
    nred.push(count)
  }
  # find region near center where number of red pixels is not max
  left = nil
  0.upto(w-1) { |i|
    if nred[i]<nred[0] then left=i; break end
  }  
  right = nil
  0.upto(w-1) { |i|
    ii = w-i-1
    if nred[ii]<nred[w-1] then right=ii; break end
  }
  if left.nil? or right.nil? then
    bw.save("debug1.png")
    red.save("debug2.png")
    die("left or right is nil, left=#{left}, right=#{right}; bw written to debug1.png, red written to debug2.png")
  end
  bw2  = bw.crop(left,0,right-left+1,h)
  red2 = red.crop(left,0,right-left+1,h)
  bbox[0] -= left
  bbox[1] -= left
  if bbox[0]<0 or bbox[1]<0 then die("bbox=#{bbox} contains negative values") end
  return [bw2,red2,line_spacing,bbox]
end

def char_to_pat_without_cropping(c,dir,font,dpi)
  out_file = dir+"/"+"temp2.png"
  image = []
  bboxes = []
  red = []
  0.upto(1) { |side|
    image.push(string_to_image(c,dir,font,out_file,side,dpi))
    bboxes.push(bounding_box(image[side]))
    red.push(red_one_side(c,dir,font,out_file,side,image[side],dpi))
  }
  #print "bounding boxes=#{bboxes}\n"
  box_w = bboxes[0][1]-bboxes[0][0]
  w = dpi*font.size/20
  h = image[0].height
  image_final = ChunkyPNG::Image.new(w,h,ChunkyPNG::Color::WHITE)
  red_final = ChunkyPNG::Image.new(w,h,ChunkyPNG::Color::WHITE)
  slide_to = (w-box_w)/2 # put them so the left side of the bounding box is here
  final_bbox = bboxes[0].clone
  final_bbox[0] = slide_to
  final_bbox[1] = slide_to+bboxes[0][1]-bboxes[0][0]
  0.upto(1) { |side|
    dx = slide_to-bboxes[side][0]
    0.upto(w-1) { |i|
      i0 = i-dx
      if i0<0 || i0>image[0].width-1 then next end
      0.upto(h-1) {  |j|
        if side==0 then image_final[i,j] = image[side][i0,j] end
        red_final[i,j] = red[side][i0,j]
      }
    }
  }
  pat_line_spacing = image_final.height # this may be wrong, but it seems like pango sets the height of the image to the line height
  return [image_final,red_final,pat_line_spacing,final_bbox]
end

def red_one_side(c,dir,font,out_file,side,image,dpi)
  red = image_empty_copy(image)
  script = char_to_code_block(c) # returns greek, latin, or hebrew
  # Many fonts that contain one script don't contain coverage of other scripts. Rendering libraries may leave a blank or sub in some other font, but
  # this produces goofy results, such as unpredictable variations in line height. So use guard-rail characters
  # that are from the same script. This was an issue for GFSPorson, which lacks Latin characters.

  # To find out how much white "personal space" the character has around it, we render various other "guard-rail" characters
  # to the right and left of it. The logical "or" of these is space that we know can be occupied by other characters. I visualize
  # this as red."
  # side=0 means guard-rail chars will be on the right of our character, 1 means left
  other = nil
  if script=='latin' then
    #if side==0 then other = "AT1!H.,;:'{_=|~?/" else other="!]':?HTiXo" end
  end
  if script=='greek' then
    # Don't add characters to the following that may not be covered in a Greek font. In particular, GFSPorson lacks Latin characters.
    if side==0 then other = "ΠΩΔΥΗ.,'" else other="ΠΩΔΥΗ'" end
  end
  if script=='hebrew' then
    # Don't add characters to the following that may not be covered in a Hebrew font.
    if side==0 then other = "ח.,'" else other="ר''" end
  end
  if other.nil? then
    # provide some kind of fall-back
    if side==0 then other = "1.,'" else other="1''" end
  end
  other.chars.each { |c2|
    if side==0 then s=c+c2 else s=c2+c end
    image2 = string_to_image(s,dir,font,out_file,side,dpi)
    red = image_or(red,image_minus(image2,image))
  }
  bbox = bounding_box(image)
  erase_inside_box(red,bbox) # when side=1, text is not aligned in precisely the same spot every time, varies by ~1 pixel
  w,h = image.width,image.height
  0.upto(h-1) { |j|
    started = false
    0.upto(w-1) { |ii|
      if side==1 then i=w-1-ii else i=ii end
      if has_ink(red[i,j]) then started=true end
      if started then red[i,j]=ChunkyPNG::Color::BLACK end
    }
  }
  return red
end


def string_to_image(s,dir,font,out_file,side,dpi)
  return string_to_image_gd(s,dir,font,out_file,side,dpi)
end

def string_to_image_pango_view(s,dir,font,out_file,side,dpi)
  # side=0 for left, 1 for right
  # Empirically, pango-view seems to return a result whose height doesn't depend on the input, but with the following
  # exception: if it can't find a character in the font you're using, it picks some other font in which to render that
  # character; but then if that other font has a greater height, the whole image gets taller. For this reason, I have
  # code above that tries to autodetect the script that a character is in, and only use guard-rail characters from
  # that script.
  # See comment block below with some perl code I could shell out to if I decide to dump pango-view.
  pango_font = font.pango_string()
  in_file = dir+"/"+"temp1.txt"
  if side==0 then align="left" else align="right" end
  File.open(in_file,'w') { |f|
    f.print s
  }
  cmd = "pango-view -q --align=#{align} --dpi=#{dpi} --margin 0 --font=\"#{pango_font}\" --width=200 -o #{out_file} #{in_file}"
  system(cmd)
  image = ChunkyPNG::Image.from_file(out_file)
  return image
end

def string_to_image_gd(s,dir,font,out_file,side,dpi)
  # quirks: if a character is missing from the font, it just silently doesn't output it, and instead outputs a little bit of whitespace
  # advantage: unlike pango-view, lets you really force a particular font
  # We ignore side, but crop the resulting image so that it's snug against both the left and the right.
  verbosity = 4
  temp_file_1 = temp_file_name()
  code = <<-"PERL"
    use strict;
    use GD;
    my $w = 1000;
    my $h = 300;
    my $image = new GD::Image($w,$h);
    my $black = $image->colorAllocate(0,0,0);
    my $white = $image->colorAllocate(255,255,255);
    $image->filledRectangle(0,0,$w-1,$h-1,$white);
    my $ttf_path = "#{escape_double_quotes(font.file_path)}";
    my $ptsize = #{font.size};
    my %options = {'resolution'=>"#{dpi},#{dpi}"};
    my @bounds = $image->stringFT($black,$ttf_path,$ptsize,0,10,$h*0.75,"#{escape_double_quotes(s)}",\%options);
    open(F, '>', "#{escape_double_quotes(temp_file_1)}") or die $!;
    binmode F;
    print F $image->png;
    close F;
    print "__output__",$bounds[0],",",$bounds[2],",",$bounds[5],",",$bounds[1],"\n" # left, right, top, bottom -- https://metacpan.org/pod/GD
  PERL
  if verbosity>=4 then print code; print "escaped s=#{escape_double_quotes(s)}\n" end
  output = run_perl_code(code)
  left,right,top,bottom = output.split(/,/).map {|x| x.to_i}
  if verbosity>=4 then print "output=#{output}, lrtb=#{[left,right,top,bottom]}\n" end
  image = ChunkyPNG::Image.from_file(temp_file_1)
  image.crop(left,top,right-left+1,bottom-top+1)
  image.save(out_file)
  if verbosity>=3 then print "saved to #{out_file}\n" end
  return image
end



