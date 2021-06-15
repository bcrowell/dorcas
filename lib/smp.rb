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
