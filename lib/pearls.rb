# These functions are meant to input a single line of matched characters and string them together
# like a string of pearls, returning an OCR result.

def babble(s,threshold:0.5)
  # S is a spatter object that we hope is a single line of text.
  # Outputs a string that simply contains all hits with scores above the threshold, sorted from left to right.
  l = prebabble(s,threshold)
  return l.map { |x| x[0] }.join
end

def mumble(s,threshold:0.3)
  # S is a spatter object that we hope is a single line of text.
  # Outputs a string that contains the OCR'd text based on the simplest algorithm that could possibly output anything legible.
  # Simply splits the line wherever there's too much whitespace, then returns mumble_word() on each word.
  l = prebabble(s,threshold)
  inter = ((s.max_interword+s.min_interword)*0.5).round
  0.upto(l.length-2) { |i|
    if l[i+1][1]-l[i][1]-s.widths[l[i][0]]-s.max_kern>inter then
      x_split = ((l[i+1][1]+l[i][1])*0.5).round
      s1 = s.select(lambda { |a| a[1]<=x_split})
      s2 = s.select(lambda { |a| a[1]>x_split})
      return mumble(s1)+" "+mumble(s2) 
    end
  }
  # If we drop through to here, then this is putatively a single word.
  return mumble_word(s)
end

def mumble_word(s)
  # Find the highest-scoring letter in the word. Split the word at that letter, and recurse.
  if s.total_hits==0 then return "" end
  l = prebabble(s,-999.9)
  if l.length==0 then return "" end
  i,garbage = greatest(l.map { |x| x[1]}) # find index i of the highest-scoring letter
  c = l[i][0]
  xl = l[i][1]
  xr = xl + s.widths[c]
  s1 = s.select(lambda { |a| a[1]+s.widths[a[3]]-s.max_kern<=xl})
  s2 = s.select(lambda { |a| a[1]+s.max_kern>=xr})
  return mumble_word(s1)+c+mumble_word(s2)
end

def dag_word(s)
  # Treat the word as a directed acyclig graph, and find the longest path from left to right, where length is measured by sum (score-const).
  s = s.sort_by_x
  n = s.hits.length
  h = s.hits  # looks like a list of [score,x,y].
  wt = h.map { |a| a[0]-0.5 } # score of each letter, considered as an edge in the graph; 0.5 is the nominal threshold of my scoring scale
  # Build a graph e, which will be an array of edges; e[i] is a list of nodes j such that we have an edge from the right side
  # of character i-1 to the left side of character j. e[0] is a list of possible starting chars, e[n] a list of possible ending chars.
  e = word_to_dag(s)
end

def word_to_dag(s)
  # Converts an input Spatter object representing a word to a directed acyclic graph. Input should already be sorted by left x.
  n = s.hits.length
  # Build a bunch of arrays, all with the same indexing from 0 to n-1.
  h = s.hits  # looks like a list of [score,x,y].
  w = s.widths
  l = h.map { |a| a[1] } # x coord of left edge
  r = [];  0.upto(n-1) { |i| r.push( l[i]+w[i]) } # x coord of right edge
  mi = s.min_interword # any distance greater than this is impermissible within a word
  mk = s.max_kern # any distance less than this is impermissible
  leftmost = h[0][1] # x coord of leftmost char; we don't have to start with leftmost char if others line up with it reasonably well
  rightmost = r.max
  max_end_slop = mi*0.5 # not sure if this is optimal; allow for the possibility that leftmost is actually a bad match and a little too far left, ditto right
  # Build a graph e, which will be an array of edges; e[i] is a list of nodes j such that we have an edge from the right side
  # of character i-1 to the left side of character j. e[0] is a list of possible starting chars, e[n] a list of possible ending chars.
  e = []
  # List of possible starting characters:
  e.push([])
  0.upto(n-1) { |i|
    next if l[i]>leftmost+max_end_slop
    e[-1].push(i)
  }
  # Possible transitions from one character to another:
  0.upto(n-1) { |i|
    e.push([])
    xr = r[i]
    (i+1).upto(n-1) { |j|
      xl = l[j]
      next if xl>xr+mi
      if xl>xr-mk then e[-1].push(j) end
    }
  }
  # List of possible ending characters:
  (n-1).downto(0) { |i|
    if r[i]>rightmost-max_end_slop then e[-1].push(i) end # can't exit early from loop, because list is sorted by left x, not right x
  }
  return e
end

def prebabble(s,threshold)
  # Inputs a Spatter object and outputs a spatially sorted list of items of the form [score,x], eliminating all hits below threshold.
  s = s.you_have_to_have_standards(threshold)
  letters = []
  s.hits.each { |c,h|
    h.each { |hh|
      score,x,y = hh
      if score>threshold then letters.push([c,x]) end
    }
  }
  return letters.sort { |p,q| p[1] <=> q[1]}
end

