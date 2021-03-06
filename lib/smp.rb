# coding: utf-8
require 'etc'

def guess_n_cores()
  n = Etc.nprocessors()
  # This may be less than the real number of cores if we don't have access to all of them, or more than
  # the true number if there's hyperthreading. (If I use the number available through hyperthreading,
  # testing showed that brute-force manipulation of an array in chapel got slower, while freak stayed
  # the same.)
  if n>4 then n=4 end # works better on my machine, which only has 4 physical cores
  return n
end

def lower_priority(pid)
  Process.setpriority(Process::PRIO_PROCESS, pid, 10) 
  # https://ruby-doc.org/core-2.6.3/Process.html#method-c-setpriority
  # not sure what this does on Windows
end

def lower_io_priority(pid)
  # The following only actually works on linux. On other systems it will cause an error, which we have to rescue.
  # To verify that this worked, do "ionice -p xxx", where xxx is the process ID.
  # This priority should be inherited by processes that we spawn as well.
  begin
    `ionice -c idle -p #{Process.pid} >/dev/null 2>&1`
  rescue
  end
end

def portion_out_characters(chars,n)
  # Take an input string of characters and make n strings containing subsets.
  μοῖραι = Array.new(n) { |i| "" }
  count = 0
  chars.chars.each { |c|
    μοῖραι[count%n] += c
    count += 1
  }
  return μοῖραι
end

def find_exe(subdir,file)
  # subdir can be nil, or can be the name of a subdirectory of the subdir of the dir in which the main ruby executable lives
  s = HomeDir.home
  if !(subdir.nil?) then
    s = dir_and_file_to_path(s,subdir)
  end
  return dir_and_file_to_path(s,file)
end
