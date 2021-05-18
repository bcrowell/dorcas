def make_graph(pdf_file,x_values,y_values,x_label,y_label)
  x = x_values.join(",")
  y = y_values.join(",")
  r = <<-"R_CODE"
    pdf("#{pdf_file}")
    plot(c(#{x}),c(#{y}),xlab="#{x_label}",ylab="#{y_label}")
  R_CODE
  file = temp_file_name()
  File.open(file,'w') { |f|
    f.print r
  }
  print "file is #{file}\n"
  system("R --quiet --slave --no-save --no-restore-data <#{file}")
  FileUtils.remove_dir(file)
end
