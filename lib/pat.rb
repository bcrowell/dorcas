# coding: utf-8

class Pat
  def initialize(bw,red,line_spacing,baseline,bbox,c)
    @bw,@red,@line_spacing,@bbox,@baseline,@c = bw,red,line_spacing,bbox,baseline,c
    # bw and red are ChunkyPNG objects
    # The bbox is typically the one from the original seed font, but can be modified.
    # There is not much point in storing the bbox of the actual swatch, since that is probably unreliable and in any case can
    # be found from bw and red if we need it. The only part of the bbox that we normally care about
    # is element 0, which is the x coordinate of the left side (and which differs from the origin by the left bearing).
    # The character itself, c, is only used as a convenience feature for storing in the metadata when writing to a file.
  end

  attr_reader :bw,:red,:line_spacing,:baseline,:bbox,:c

  def width()
    return bw.width
  end

  def height()
    return bw.height
  end

  def transplant_from_file(filename)
    my new_pat = Pat.from_file(filename)
    self.transplant(new_pat.bw)
  end

  def transplant(new_bw)
    if new_bw.width!=self.width or new_bw.height!=self.height then die("error transplanting swatch into pattern, not the same dimensions") end
    @bw = new_bw
  end

  def Pat.char_to_filename(dir,c)
    # Generate the conventional filename we would expect for this unicode character.
    name = char_to_short_name(c)
    return dir_and_file_to_path(dir,name+".pat")
  end

  def save(filename)
    # My convention is that the filename has extension .pat.
    data = {'baseline'=>self.baseline,'bbox'=>self.bbox,'character'=>self.c,'unicode_name'=>char_to_name(self.c),'line_spacing'=>self.line_spacing}
    # ...the call to char_to_name() is currently pretty slow
    temp_files = []
    write_as_name = ["bw.png","red.png","data.json"]
    n_pieces = write_as_name.length
    0.upto(n_pieces-1) { |i|
      temp_files.push(temp_file_name())
    }
    0.upto(n_pieces-1) { |i|
      n = temp_files[i]
      if i==0 then self.bw.save(n) end
      if i==1 then self.red.save(n) end
      if i==2 then create_text_file(n,JSON.pretty_generate(data)) end
    }
    # rubyzip, https://github.com/rubyzip
    FileUtils.rm_f(filename)
    Zip::File.open(filename, Zip::File::CREATE) do |zipfile|
      0.upto(n_pieces-1) { |i|
        zipfile.add(write_as_name[i],temp_files[i])
      }
    end
    temp_files.each { |n| FileUtils.rm_f(n) }
  end

  def Pat.from_file(filename)
    temp_files = []
    read_as_name = ["bw.png","red.png","data.json"]
    name_to_index = {}
    n_pieces = read_as_name.length
    0.upto(n_pieces-1) { |i|
      temp_files.push(temp_file_name())
      name_to_index[read_as_name[i]] = i
    }
    bw,red,data = nil,nil,nil
    # https://github.com/rubyzip/rubyzip
    Zip::File.open(filename) do |zipfile|
      zipfile.each do |entry|
        # Their sample code has sanity check on entry.size here.
        # Extract to file or directory based on name in the archive
        name_in_archive = entry.name
        if not (name_to_index.has_key?(name_in_archive)) then die("illegal filename in archive, #{name_in_archive}") end
        i = name_to_index[name_in_archive]
        temp = temp_files[i]
        entry.extract(temp) # read into temp file
        if i==0 or i==1 then
          content = ChunkyPNG::Image.from_file(temp)
        else
          content = JSON.parse(entry.get_input_stream.read)
        end
        if i==0 then bw=content end
        if i==1 then red=content end
        if i==2 then data=content end
      end
    end
    temp_files.each { |n| FileUtils.rm_f(n) }
    if bw.nil? or red.nil? or data.nil? then die("error reading #{filename}, didn't find all required parts") end
    if data.has_key?('line_spacing') then line_spacing=data['line_spacing'] end
    return Pat.new(bw,red,line_spacing,data['baseline'],data['bbox'],data['character'])
  end
end

#---------- end of class Pat

def char_to_pat(c,dir,font,dpi,script,char)
  bw,red,line_spacing,baseline,bbox = char_to_pat_without_cropping(c,dir,font,dpi,script)
  bw,red,line_spacing,bbox = crop_pat(bw,red,line_spacing,bbox)
  return Pat.new(bw,red,line_spacing,baseline,bbox,char)
end

def crop_pat(bw,red,line_spacing,bbox)
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

def char_to_pat_without_cropping(c,dir,font,dpi,script)
  image = []
  bboxes = []
  red = []
  my_baseline = nil
  0.upto(1) { |side|
    baseline,bbox,im = string_to_image(c,dir,font,side,dpi,script)
    my_baseline = baseline # should be the same both times through the loop
    image.push(im)
    bboxes.push(bbox)
    red.push(red_one_side(c,dir,font,side,image[side],dpi,script))
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
  return [image_final,red_final,pat_line_spacing,my_baseline,final_bbox]
end

def red_one_side(c,dir,font,side,image,dpi,script)
  red = image_empty_copy(image)
  script = Script.new(c)
  # To find out how much white "personal space" the character has around it, we render various other "guard-rail" characters
  # to the right and left of it. The logical "or" of these is space that we know can be occupied by other characters. I visualize
  # this as red.
  # side=0 means guard-rail chars will be on the right of our character, 1 means left
  other = script.guard_rail_chars(side)
  other.chars.each { |c2|
    if side==0 then s=c+c2 else s=c2+c end
    trash1,trash2,image2 = string_to_image(s,dir,font,side,dpi,script)
    red = image_or(red,image_minus(image2,image))
  }
  bbox = bounding_box(image)

  # When side=1, it seems like the main character is not aligned in precisely the same spot every time, varies by ~1 pixel. 
  # I'm not sure if this is a +-1 bug in GD or in my code. Kerning shouldn't actually cause this to happen, since by definition,
  # right-alignment should be right-alignment. The effect is in fact quite small compared to a big kerning correction, seems to
  # be only 1 pixel. But it does happen, and this causes the red pattern to contain glitches at the left and right edges of
  # the main character. Remove these glitches.
  if side==1 then
    bigger_bbox = bbox.clone
    max_kern = font.metrics(dpi,script)['max_kern'] # efficient because memoized
    bigger_bbox[0] -= 1
    bigger_bbox[1] += 1
    erase_inside_box(red,bigger_bbox) 
  end

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


def string_to_image(s,dir,font,side,dpi,script)
  verbosity = 2
  temp_file = temp_file_name()
  line_spacing = font.line_spacing_pixels(dpi,script)
  point_size = font_size_and_dpi_to_size_for_gd(font.size,dpi)
  ttf_file_path = font.file_path

  # The following is not inefficient, because font.metrics() is memoized.
  metrics = font.metrics(dpi,script)
  hpheight = metrics['hpheight']
  descent = metrics['descent']
  em = metrics['em']
  margin = 1
  
  baseline,left,right,top,bottom = ttf_render_string(s,temp_file,ttf_file_path,dpi,point_size,hpheight,descent,margin,em)
  if verbosity>=3 then print "lrtb=#{[left,right,top,bottom]}\n" end
  image = ChunkyPNG::Image.from_file(temp_file)
  FileUtils.rm_f(temp_file)

  if side==1 then
    # Because GD doesn't support drawing right-aligned text, we have to scooch it over.
    # In the following, I'm afraid to use methods like crop! and replace! because in the past those have crashed.
    offset = image.width-right
    image4 = image.crop(0,0,image.width-offset,image.height) # make it narrower, otherwise the replace method complains
    image2 = ChunkyPNG::Image.new(image.width,image.height,ChunkyPNG::Color::WHITE)
    image3 = image2.replace(image4,offset_x=offset)
    image = image3
    left += offset
    right += offset
  end
  
  bbox = [left,right,top,bottom]

  return [baseline,bbox,image]
end



