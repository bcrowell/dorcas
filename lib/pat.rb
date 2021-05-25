# coding: utf-8

class Pat
  def initialize(bw,red,line_spacing,bbox)
    @bw,@red,@line_spacing,@bbox = bw,red,line_spacing,bbox
    # bw and red are ChunkyPNG objects
  end

  attr_reader :bw,:red,:line_spacing,:bbox

  def width()
    return bw.width
  end

  def height()
    return bw.height
  end
end

def char_to_pat(c,dir,font,dpi,script)
  bw,red,line_spacing,bbox = char_to_pat_without_cropping(c,dir,font,dpi,script)
  bw,red,line_spacing,bbox = crop_pat(bw,red,line_spacing,bbox)
  return Pat.new(bw,red,line_spacing,bbox)
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
  out_file = dir+"/"+"temp2.png"
  image = []
  bboxes = []
  red = []
  0.upto(1) { |side|
    image.push(string_to_image(c,dir,font,out_file,side,dpi,script))
    bboxes.push(bounding_box(image[side]))
    red.push(red_one_side(c,dir,font,out_file,side,image[side],dpi,script))
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

def red_one_side(c,dir,font,out_file,side,image,dpi,script)
  red = image_empty_copy(image)
  script = Script.new(c)
  # To find out how much white "personal space" the character has around it, we render various other "guard-rail" characters
  # to the right and left of it. The logical "or" of these is space that we know can be occupied by other characters. I visualize
  # this as red.
  # side=0 means guard-rail chars will be on the right of our character, 1 means left
  other = script.guard_rail_chars(side)
  other.chars.each { |c2|
    if side==0 then s=c+c2 else s=c2+c end
    image2 = string_to_image(s,dir,font,out_file,side,dpi,script)
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


def string_to_image(s,dir,font,out_file,side,dpi,script)
  verbosity = 2
  temp_file = temp_file_name()
  line_spacing = font.line_spacing_pixels(dpi,script)
  point_size = font_size_and_dpi_to_size_for_gd(font.size,dpi)
  ttf_file_path = font.file_path

  # The following is not inefficient, because font.metrics() is memoized.
  metrics = font.metrics(dpi,script)
  hpheight = metrics['hpheight']
  descent = metrics['descent']
  margin = 1
  
  baseline,left,right,top,bottom = ttf_render_string(s,temp_file,ttf_file_path,dpi,point_size,hpheight,descent,margin)
  if verbosity>=3 then print "lrtb=#{[left,right,top,bottom]}\n" end
  image = ChunkyPNG::Image.from_file(temp_file)
  FileUtils.rm(temp_file)

  if side==1 then
    # Because GD doesn't support drawing right-aligned text, we have to scooch it over.
    # In the following, I'm afraid to use methods like crop! and replace! because in the past those have crashed.
    offset = image.width-right
    image4 = image.crop(0,0,image.width-offset,image.height) # make it narrower, otherwise the replace method complains
    image2 = ChunkyPNG::Image.new(image.width,image.height,ChunkyPNG::Color::WHITE)
    image3 = image2.replace(image4,offset_x=offset)
    image = image3
  end

  image.save(out_file)
  if verbosity>=3 then print "saved to #{out_file}\n" end
  return image
end



