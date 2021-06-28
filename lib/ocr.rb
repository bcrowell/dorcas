def ocr_one_page(job,page,report_dir,lingos,verbosity:1)
  if job.set.nil? then die("job file doesn't contain a set parameter specifying a pattern set") end
  all_chars = job.all_characters
  f = job.fingerprint_pre_spatter + "_" + page.fingerprint + "_" + job.set.fingerprint + "_" + job.page_number.to_s
  cached_spatter_filename = dir_and_file_to_path(job.cache_dir,f+".spa")
  if File.exists?(cached_spatter_filename) then
    if verbosity>=2 then console "Reading previous partial results from #{cached_spatter_filename}. If this isn't what you want, do a `dorcas clean`.\n" end
    spatter = nil
    File.open(cached_spatter_filename,"rb") { |file| spatter = Marshal.load(file) }
  else
    if all_chars.nil? then
      m = Match.new(scripts:['latin','greek'],meta_threshold:job.threshold)
    else
      m = Match.new(characters:all_chars,meta_threshold:job.threshold)
    end
    batch_code = Process.pid.to_s + "_" + job.page_number.to_s
    hits = m.execute(page,job.set,job.page_number.to_s,batch_code:batch_code) # only result of doing this is currently that mon.png gets written
    hits.each { |c,h| h.each { |a| Spot.bless(a,job.set,job.set.pat(c)) } }
    spatter = Spatter.from_hits_page_and_set(hits,page,job.set)
    File.open(cached_spatter_filename,"wb") { |file| Marshal.dump(spatter,file) }
  end
  if verbosity>=2 then console "spatter:\n  #{spatter.report}\n" end
  if verbosity>=1 then console "Splitting the page into lines.\n" end
  lines = spatter.plow()
  if job.page_number!=0 then outfile=sprintf("%03d.txt",job.page_number) else outfile=nil end
  if verbosity>=1 then
    if outfile.nil? then describe="stdout" else describe=outfile end
    console "Interpreting lines. Text will be printed to #{describe}\n"
  end
  if outfile.nil? then f=stdout else f=File.open(outfile,'w') end
  #lines.each { |l|      f.print "line:\n  #{l.report}\n"    }
  #lines.each { |l| f.print babble(l),"\n"  }
  if false # mumble algorithm actually gives surprisingly good results, given how simple it is
    lines.each { |l| f.print dumb_split(l,'mumble',lingos,threshold:job.threshold),"\n"  }
    print "\n"
  end
  lines.each { |l| f.print dumb_split(l,'dag',lingos,threshold:job.threshold),"\n"  }
  f.print "\n" # blank line at the end of every page
  if !(outfile.nil?) then f.close end
  return
end
