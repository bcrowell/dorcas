def ocr_one_page(job,page,report_dir)
  all_chars = job.all_characters
  f = job.fingerprint_pre_spatter + "_" + page.fingerprint
  cached_spatter_filename = dir_and_file_to_path(job.cache_dir,f+".spa")
  if File.exists?(cached_spatter_filename) then
    print "Reading previous partial results from #{cached_spatter_filename}. If this isn't what you want, do a `dorcas clean`.\n"
    spatter = nil
    File.open(cached_spatter_filename,"rb") { |file| spatter = Marshal.load(file) }
  else
    if all_chars.nil? then
      m = Match.new(scripts:['latin','greek'],meta_threshold:job.threshold)
    else
      m = Match.new(characters:all_chars,meta_threshold:job.threshold)
     end
    if job.set.nil? then die("job file doesn't contain a set parameter specifying a pattern set") end
    hits = m.execute(page,job.set,batch_code:Process.pid.to_s) # only result of doing this is currently that mon.png gets written
    spatter = Spatter.from_hits_page_and_set(hits,page,job.set)
    File.open(cached_spatter_filename,"wb") { |file| Marshal.dump(spatter,file) }
  end
  print "spatter:\n  #{spatter.report}\n"
  lines = spatter.plow()
  #lines.each { |l|      print "line:\n  #{l.report}\n"    }
  #lines.each { |l| print babble(l),"\n"  }
  lines.each { |l| print dumb_split(l,'mumble'),"\n"  }
  print "\n"
  lines.each { |l| print dumb_split(l,'dag'),"\n"  }
  return
end
