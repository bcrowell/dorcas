def clown(x)
  # Call it something besides clone because otherwise it's hard to grep for use of clone, which I
  # should *never* use.
  return Marshal.load(Marshal.dump(x))
end

def shallow_copy(x)
  # The purpose of having this here is so that I can easily tell when looking through my code that I haven't
  # thoughtlessly done shallow copying using clone.
  return x.clone
end
