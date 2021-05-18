require 'etc'

def guess_n_cores()
  n = Etc.nprocessors()
  # This may be less than the real number of cores if we don't have access to all of them, or more than
  # the true number if there's hyperthreading. (Testing shows that the correlation method gets slower,
  # not faster, if I use the number available through hyperthreading.)
  if n>4 then n=8 end # works better on my machine, which only has 4 physical cores
  return n
end

