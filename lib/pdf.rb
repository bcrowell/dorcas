def extract_pdf_page(text_file,dpi)
  if not text_file=~/((.*)\.pdf)\[(\d+)\]$/ then die("error parsing input pdf filename #{text_file}") end
  pdf,base,page = $1,$2,$3
  png = "#{base}_#{sprintf("%03d",page)}.png"
  if File.exists?(png) then return end
  print "Extracting page #{page} from #{pdf} to #{png}\n"
  temp_file = temp_file_name()
  shell_out("qpdf \"#{pdf}\" --pages . #{page} -- #{temp_file}")
  shell_out("convert -density #{dpi} #{temp_file} -set colorspace Gray -separate -average #{png}")
  File.rm_f(temp_file)
end
