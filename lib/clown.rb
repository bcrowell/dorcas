def clown(x)
  # Call it something besides clone because otherwise it's hard to grep for use of clone, which I
  # should *never* use.
  return Marshal.load(Marshal.dump(x))
end
