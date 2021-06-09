def write_svg_reports(job,dir,pats)
  output_dir = job.output
  write_svg_reports_helper(dir,output_dir,"swatches.svg","Writing a summary of new swatches to %s\n",pats)

  job.characters.each { |x|
    script_name,c,chars = x
    file_base = "#{script_name}_#{c}.svg"
    chars = Script.new(script_name).alphabet(c:c) # do all characters, not just the ones worked on in this job
    write_svg_reports_helper(dir,output_dir,file_base,"Writing a summary of #{script_name} #{c} to %s\n",chars)
  }
end

def write_svg_reports_helper(dir,output_dir,file_base,info,data)
  if data.class==String then
    pats = []
    data.chars.each { |c|
      filename = Pat.char_to_filename(output_dir,c)
      if File.exists?(filename) then
        pats.push([true,Pat.from_file(filename)])
      else
        pats.push([false,c])
      end
    }
  else
    pats = data
  end
  err,message,filename = patset_as_svg(dir,file_base,pats)
  print sprintf(info,filename)
  if err!=0 then warn(message) end
end

def patset_as_svg(dir,basic_svg_filename,unsorted_pats)
  if unsorted_pats.length==0 then return [1,"no patterns to write to #{basic_svg_filename}, file not written",nil] end
  if not File.exists?(dir) then Dir.mkdir(dir) end
  svg_filename = dir_and_file_to_path(dir,basic_svg_filename)
  pats = {}
  unsorted_pats.each { |x|
    matched,match = x
    if matched then
      pat = match
      pats[char_to_short_name(pat.c)] = [pat.c,matched,pat]
    else
      c = match
      pats[char_to_short_name(c)] = [c,matched,nil]
    end
  }
  heights = []
  pats.each { |name,x|
    if x[1] then heights.push(x[2].bw.height) end
  }
  if heights.length==0 then return [2,"no matched patterns to write to #{basic_svg_filename}, file not written",nil] end
  max_height = greatest(heights)[1]
  row_height = max_height*1.3
  col_width = max_height*1.5
  images = []
  labels = []
  bw_filename = {}
  count = 0
  pats.keys.sort {|a,b| pats[a][0] <=> pats[b][0]}.each { |name|
    c,matched,pat = pats[name]
    y = count*row_height
    if matched then
      basic_png_filename = "patterns_"+name+"_bw.png" # the prefix is because we share a directory with other svg files and their images
      bw_filename[name] = basic_png_filename
      pat.bw.save(dir_and_file_to_path(dir,basic_png_filename))
      images.push([basic_png_filename,0,y,pat.bw.width,pat.bw.height,1.0])
    end
    rough_font_size = max_height*0.27
    labels.push([c,   col_width,  y,rough_font_size])
    labels.push([name,col_width*2,y,rough_font_size]) if name!=c
    count += 1
  }
  svg = svg_code_patset(images,labels,300.0)
  File.open(svg_filename,'w') { |f| f.print svg }
  return [0,nil,svg_filename]
end

def svg_code_patset(image_info,label_info,dpi)
  x_offset = 10 # in mm
  y_offset = 10
  images = []
  scale = 25.4/dpi # to convert from pixels to mm
  image_info.each { |i|
    filename,x,y,w,h,opacity = i
    images.push(svg_image(filename,x*scale+x_offset,y*scale+y_offset,w*scale,h*scale,opacity))
  }
  images_svg = images.join("\n")
  labels = []
  label_info.each { |i|
    text,x,y,h = i
    fudge_y_pos = 2.8 # why is this necessary?
    labels.push(svg_text(text,x*scale+x_offset,(y+fudge_y_pos*h)*scale+y_offset,h*scale))
  }
  labels_svg = labels.join("\n")
  svg = "#{svg_header()}  #{images_svg} #{labels_svg} </svg>"
  return svg
end

def svg_text(text,x,y,size_mm)
  # size_mm is the font's point size, expressed in mm; fonts' sizes are normally the em width
svg = 
<<-"SVG"
  <text x="#{x}" y="#{y}" style="font-size:#{mm_to_pt(size_mm)}"><tspan>#{text}</tspan></text>
SVG
end

def matches_as_svg(dir,svg_filename,char_name,text_file,text,pat,hits,composites)
  print "Writing svg file #{svg_filename}\n"
  images = []
  filename = dir_and_file_to_path(dir,"matches_#{char_name}.png")
  pat.visual.save(filename)
  images.push([text_file,0,0,text.width,text.height,0.4])
  dpi = 300.0 # fixme
  scale = 25.4/dpi # to convert from pixels to mm
  labels = []
  x_offset,y_offset = 0,9.7 # mm
  h = 0.7 # mm
  hits.each { |hit|
    c,x,y = hit
    images.push([filename,x,y,pat.bw.width,pat.bw.height,0.8])
    score_string = (c*100).round.to_s
    labels.push(svg_text(score_string,x*scale+x_offset,y*scale+y_offset,h))
  }
  labels_svg = labels.join("\n")
  svg = svg_code_matches(char_name,dir,images,dpi,composites,labels_svg)
  File.open(svg_filename,'w') { |f| f.print svg }
end

def svg_code_matches(char_name,dir,image_info,dpi,composites,labels_svg)
  images = []
  labels = []
  scale = 25.4/dpi # to convert from pixels to mm
  y_bottom_list = []
  image_info.each { |i|
    filename,x,y,w,h,opacity = i
    y_bottom_list.push(y+h)
    images.push(svg_image(filename,x*scale,y*scale,w*scale,h*scale,opacity))
  }
  highest_y = greatest(y_bottom_list)[1]
  count = 0
  composites.each { |image|
    filename = dir_and_file_to_path(dir,"matches_#{char_name}_composite_#{count}.png")
    image.save(filename)
    count += 1
    y = highest_y+75*count # shouldn't be hardcoded
    images.push(svg_image(filename,0,y*scale,image.width*scale,image.height*scale,1.0))
    font_size = 16 # mm
    text = "cluster #{count}"
    x = image.width*2
    labels.push(svg_text(text,x*scale,(y+image.height*0.7)*scale,font_size*scale))
  }
  images_svg = images.join("\n")
  text_svg = labels.join("\n")
  svg = "#{svg_header()}  #{images_svg} #{text_svg} #{labels_svg} </svg>"
  return svg
end

def svg_image(filename,x,y,w,h,opacity)
svg = 
<<-"SVG"
    <image
       xlink:href="#{filename}"
       x="#{x}"
       y="#{y}"
       preserveAspectRatio="none"
       height="#{h}"
       width="#{w}"
       style="opacity:#{opacity}" />
SVG
  return svg
end

def svg_header()
svg = 
<<-"SVG"
<?xml version="1.0" encoding="UTF-8" standalone="no"?>

<svg
   xmlns:xlink="http://www.w3.org/1999/xlink"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   width="210mm"
   height="297mm"
   viewBox="0 0 210 297" >
  <defs
     id="defs2" />
  <metadata
     id="metadata5">
  </metadata>
  SVG
  return svg
end

def mm_to_pt(mm)
  return mm/(25.4/72.0) # https://en.wikipedia.org/wiki/Point_(typography)
end

def png_report(monitor_file,text,hits,chars,set,verbosity:2)
  if monitor_file.nil? then die("no filename set for monitor file") end
  monitor_image = text.clone.grayscale
  overlays = {}
  v = {}
  chars.chars.each { |c|
    v[char_to_short_name(c)] = set.pat(c).visual(black_color:ChunkyPNG::Color::rgba(255,0,0,130),red_color:nil) # semitransparent red
  }
  hits.each { |x|
    score,i,j,misc = x
    short_name = misc['label']
    if verbosity>=3 then print "    ",x,"\n" end
    vv = v[short_name]
    monitor_image = compose_safe(monitor_image,v[short_name],i,j)
  }
  monitor_image.save(monitor_file)
end
