def patterns_as_svg(svg_filename,unsorted_pats)
  pats = {}
  unsorted_pats.each { |pat|
    pats[char_to_short_name(pat.c)] = pat
  }
  pats.each { |name,pat|
    c = pat.c
    print "character: #{name}\n"
  }
end

def matches_as_svg(svg_filename,text_file,text,pat,hits)
  print "Writing svg file #{svg_filename}\n"
  images = []
  hits.each { |hit|
    c,i,j = hit
    images.push(["bw.png",i,j,pat.bw.width,pat.bw.height,1.0])
  }
  images.push([text_file,0,0,text.width,text.height,0.25])
  svg = svg_code_matches(images,300.0)
  File.open(svg_filename,'w') { |f| f.print svg }
end

def svg_code_matches(image_info,dpi)
  images = []
  scale = 25.4/dpi # to convert from pixels to mm
  image_info.each { |i|
    filename,x,y,w,h,opacity = i
    images.push(svg_image(filename,x*scale,y*scale,w*scale,h*scale,opacity))
  }
  images_svg = images.join("\n")
  svg = "#{svg_header()}  #{images_svg} </svg>"
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
