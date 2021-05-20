def make_graph(pdf_file,x_values,y_values,x_label,y_label)
  if x_values.nil? then
    y = y_values.join(",")
    data = "c(#{y})"
  else
    x = x_values.join(",")
    y = y_values.join(",")
    data = "c(#{x}),c(#{y})"
  end
  r = <<-"R_CODE"
    pdf("#{pdf_file}")
    plot(#{data},xlab="#{x_label}",ylab="#{y_label}",type="l")
  R_CODE
  file = temp_file_name()
  File.open(file,'w') { |f|
    f.print r
  }
  #print "file is #{file}\n"
  system("R --quiet --slave --no-save --no-restore-data <#{file}")
  FileUtils.remove_dir(file)
  print "Graph written to file #{pdf_file}\n"
end
