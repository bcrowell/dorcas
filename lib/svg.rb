def svg_view(image_info,dpi)
  images = []
  scale = 25.4/dpi # to convert from pixels to mm
  image_info.each { |i|
    filename,x,y,w,h,opacity = i
    images.push(svg_image(filename,x*scale,y*scale,w*scale,h*scale,opacity))
  }
  images_svg = images.join("\n")
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
  <sodipodi:namedview
     id="base"
     borderopacity="1.0"
     inkscape:document-units="mm"
     showgrid="false"
     inkscape:zoom="0.2102413"
     inkscape:cx="-430.77005"
     inkscape:cy="561.25984"
     inkscape:window-width="1280"
     inkscape:window-height="998"
     inkscape:window-x="0"
     inkscape:window-y="0"
     inkscape:window-maximized="1"
     inkscape:current-layer="layer1" />
  <metadata
     id="metadata5">
  </metadata>
  #{images_svg}
</svg>
SVG
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
