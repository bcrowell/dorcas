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

