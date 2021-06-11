# coding: utf-8

class Pat
  def initialize(bw,red,line_spacing,baseline,bbox,c)
    @bw,@red,@line_spacing,@bbox,@baseline,@c = bw,red,line_spacing,bbox,baseline,c
    # bw and red are ChunkyPNG objects
    # The bbox is typically the one from the original seed font, but can be modified. This is a raw array. To get a Box object, use bboxo().
    # There is not much point in storing the bbox of the actual swatch, since that is probably unreliable and in any case can
    # be found from bw and red if we need it. The only part of the bbox that we normally care about
    # is element 0, which is the x coordinate of the left side (and which differs from the origin by the left bearing).
    # The character itself, c, is only used as a convenience feature for storing in the metadata when writing to a file,
    # and is also used in the actual OCR'ing process.
    garbage,@pink=Pat.fix_red(bw,red,baseline,line_spacing,c)
  end

  attr_reader :bw,:red,:line_spacing,:baseline,:bbox,:c
  attr_accessor :pink

  def width()
    return bw.width
  end

  def height()
    return bw.height
  end

  def bboxo()
    return Box.from_a(bbox)
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

  def white()
    # A pattern where the part we conceptualize as white is set to black, and the red, pink, and white parts set to white.
    # That is, this is a boolean mask that says where the conceptual white is.
    w = ChunkyPNG::Image.new(self.width,self.height,bg_color = ChunkyPNG::Color::BLACK)
    white_color = ChunkyPNG::Color::WHITE
    0.upto(w.width-1) { |i|
      0.upto(w.height-1) { |j|
        if has_ink(@pink[i,j]) then w[i,j]=white_color end # Turn all the red to white.
        if has_ink(@bw[i,j]) then w[i,j]=white_color end # Turn all the black to white
      }
    }
    return w
  end

  def visual(black_color:ChunkyPNG::Color::rgb(0,0,0),red_color:ChunkyPNG::Color::rgb(255,0,0))
    # Either color can be nil.
    # Unlike most of our routines that return PNG images, this one returns a color image.
    v = ChunkyPNG::Image.new(@red.width,@red.height) # default is to initialize it as transparent, which is what we want
    0.upto(v.width-1) { |i|
      0.upto(v.height-1) { |j|
        if (not red_color.nil?) and has_ink(@red[i,j]) then v[i,j]=red_color end
        if (not black_color.nil?) and has_ink(@bw[i,j]) then v[i,j]=black_color end
      }
    }
    return v
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

  def Pat.from_file(filename,if_fix_red:true)
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
          content = image_from_file_to_grayscale(temp)
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
    if data.has_key?('line_spacing') then 
      line_spacing=data['line_spacing']
    else
      line_spacing=72; warn("using default line spacing for pink")
    end
    return Pat.new(bw,red,line_spacing,data['baseline'],data['bbox'],data['character'])
  end

  def Pat.fix_red(bw,red,baseline,line_spacing,c)
    # On the fly, fix two possible problems with red mask:
    # (1) It's hard to get an accurate red mask below the baseline using guard-rail characters. E.g., in my initial attempts,
    # I neglected to use ρ as a right-side guard character, so strings like ερ were causing problems, tail of ρ hanging
    # down into ε's whitespace. This operation is idempotent, so although could be done for once and for all, it's OK to do it every time.
    # (2) Fill in concavities in the shape of the red mask, and let it diffuse outward by a few pixels (variable pink_radius below).
    # This is something we want to do on the fly, because the amount of smearing is something we might want to adjust.
    # The argument c is used only for debugging.
    # Note that if there are flyspecks in bw, it will have an effect on this.
    # Returns chunkypng objects [red,pink].
    r = image_to_boolean_ink_array(red)
    #print array_ascii_art(r,fn:lambda {|x| {true=>'t',false=>' '}[x]}) 
    w,h = ink_array_dimensions(r)

    red_below_baseline = []
    0.upto(w-1) { |i|
      # Find the fraction of pixels above baseline that are red.
      n = 0
      nr = 0
      0.upto(baseline) { |j|
        n += 1
        if r[i][j] then nr +=1 end
      }
      red_below_baseline.push(n>0 && nr/n.to_f>0.25)
    }
    smear = (w*0.07).round
    smeared_red_below_baseline = red_below_baseline.clone
    0.upto(w-1) { |i|
      (i-smear).upto(i+smear) { |ii|
        if ii>=0 and ii<=w-1 and red_below_baseline[ii] then smeared_red_below_baseline[i]=true end
      }
    }
    red_below_baseline = smeared_red_below_baseline
    0.upto(w-1) { |i|
      if red_below_baseline[i] then
        baseline.upto(h-1) { |j|
          r[i][j] = true
        }
      end
    }
    r_with_baseline_fix = r.clone
    #if c=='ε' then print array_ascii_art(r,fn:lambda {|x| {true=>'t',false=>' '}[x]}) end

    pink_radius = (0.042*line_spacing).round  # the magic constant gives 3 pixels for Giles, which worked well
    r = pinkify(image_to_boolean_ink_array(bw),r,pink_radius,c)
    #if c=='ε' then print array_ascii_art(r,fn:lambda {|x| {true=>'t',false=>' '}[x]}) end

    return [boolean_ink_array_to_image(r_with_baseline_fix),boolean_ink_array_to_image(r)]
  end

end

def pinkify(b,r,x,c)
  # Return a new version of the red in which additional pixels are deemed honorary red pixels. See pinkify_right_side() for details.
  # b and r are boolean ink arrays; returns a modified version of r
  # c is used only for debugging
  m = pinkify_right_side(b,r,x,c)
  return flip_array(pinkify_right_side(flip_array(b),flip_array(m),x,''))
end

def pinkify_right_side(b,r,x,c)
  # c is used only for debugging
  w,h = ink_array_dimensions(r)
  center = w/2 # possibly inaccurate
  m = r.clone
  center.upto(w-1) { |i|
    0.upto(h-1) { |j|
      # Decide whether (i,j) deserves honorary red status according to criterion #1, which
      # is to remove concavities <=x in depth and <=2x in height.
      next if b[i][j] # Never actually make the read spread on top of a black pixel.
      if nearest_right(r,i,j)<=x and nearest_above(r,i,j)+nearest_below(r,i,j)<2*x then m[i][j]=true end
    }
  }
  m2 = m.clone
  center.upto(w-1) { |i|
    0.upto(h-1) { |j|
      # Now, cumulatively, apply criterion #2, which is to pinkify points whose horizontal distance from 
      # previously established red/pink is <=x and whose horizontal distance from black is >x.
      if nearest_right(m,i,j)<=x and nearest_left(b,i,j)>x then m2[i][j]=true end
    }
  }
  return m2
end

def nearest_left(a,i,j)
  w,h = ink_array_dimensions(a)
  i.downto(0) { |ii|
    if a[ii][j] then return i-ii end
  }
  return i
end

def nearest_right(a,i,j)
  w,h = ink_array_dimensions(a)
  i.upto(w-1) { |ii|
    if a[ii][j] then return ii-i end
  }
  return w-1-i
end

def nearest_below(a,i,j)
  w,h = ink_array_dimensions(a)
  j.upto(h-1) { |jj|
    if a[i][jj] then return jj-j end
  }
  return h-1-j
end

def nearest_above(a,i,j)
  w,h = ink_array_dimensions(a)
  j.downto(0) { |jj|
    if a[i][jj] then return j-jj end
  }
  return j
end

#---------- end of class Pat

def char_to_pat(c,output_dir,seed_font,dpi,script)
  if dpi<=0 or dpi>2000 then die("dpi=#{dpi} fails sanity check") end
  # Seed_font is a Font object.
  bw,red,line_spacing,baseline,bbox = char_to_pat_without_cropping(c,output_dir,seed_font,dpi.to_i,script)
  bw,red,line_spacing,bbox = crop_pat(bw,red,line_spacing,bbox)
  return Pat.new(bw,red,line_spacing,baseline,bbox,c)
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
  if bbox[0]-left<0 then left=bbox[0] end
  # ... Happens with Nimbus Sans, j. Make sure that after subtracting, left will still be >=0.
  #     Since bbox[1]>bbox[0], this should automatically keep bbox[1] from being negative either.
  bw2  = bw.crop(left,0,right-left+1,h)
  red2 = red.crop(left,0,right-left+1,h)
  bbox[0] -= left
  bbox[1] -= left
  if bbox[0]<0 then die("bbox=#{bbox} contains negative values") end
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
  w = red[0].width+red[1].width-image[0].width # (RL+I)+(RR+I)-I
  h = image[0].height
  image_final = pad_image_right(pad_image_left(image[0],red[0].width,h),w,h)
  red_left_full_width = pad_image_right(red[1],w,h)
  red_right_full_width = pad_image_left(red[0],w,h)
  red_final = image_or(red_left_full_width,red_right_full_width)
  final_bbox = bboxes[0].clone
  scoot = red[1].width-image[0].width
  final_bbox[0] += scoot  
  final_bbox[1] += scoot  
  pat_line_spacing = image_final.height # this may be wrong, but it seems like pango sets the height of the image to the line height
  return [image_final,red_final,pat_line_spacing,my_baseline,final_bbox]
end

def red_one_side(c,dir,font,side,image_orig,dpi,script)
  script = Script.new(c)
  # To find out how much white "personal space" the character has around it, we render various other "guard-rail" characters
  # to the right and left of it. The logical "or" of these is space that we know can be occupied by other characters. I visualize
  # this as red.
  # side=0 means guard-rail chars will be on the right of our character, 1 means left
  # As we go through the loop, the images can grow, but we don't mutate image_orig.
  red = image_empty_copy(image_orig)
  image = image_orig.clone
  other = script.guard_rail_chars(side)
  other.chars.each { |c2|
    if side==0 then s=c+c2 else s=c2+c end
    trash1,trash2,image2 = string_to_image(s,dir,font,side,dpi,script)
    image,image2,red = reconcile_widths([image,image2,red],side)
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

  # If a pixel is red, fill in everything farther away to the side with red as well.
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

  if point_size<=0 or point_size>200 then die("point size #{point_size} fails sanity check") end

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

  if side==1 then # right-aligned
    # Because GD doesn't support drawing right-aligned text, we have to scooch it over.
    # In the following, I'm afraid to use methods like crop! and replace! because in the past those have crashed.
    offset = image.width-right
    if offset<0 then die("negative offset; this can happen if the renderer overflows the size allocated for the image") end
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



