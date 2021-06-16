def extract_pdf_page(text_file,dpi,cache_dir)
  if not text_file=~/(.*\.pdf)\[(\d+)\]$/ then die("error parsing input pdf filename #{text_file}") end
  pdf,page = $1,$2
  base = File.basename(pdf)
  base =~ /(.*)\.pdf/
  stem = $1
  png = dir_and_file_to_path(cache_dir,"#{stem}_#{sprintf("%03d",page)}.png")
  if File.exists?(png) then return png end
  print "Extracting page #{page} from #{pdf} to #{png}\n"
  temp_file = temp_file_name()
  shell_out("qpdf \"#{pdf}\" --pages . #{page} -- #{temp_file}")
  shell_out("convert -density #{dpi} #{temp_file} -set colorspace Gray -separate -average #{png}")
  # ... checked that output has no alpha channel; will be 8-bit or 16-bit, depending on the input file
  FileUtils.rm_f(temp_file)
  return png
end
