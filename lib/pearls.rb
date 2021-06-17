# These functions are meant to input a single line of matched characters and string them together
# like a string of pearls, returning an OCR result.

def babble(s,threshold:0.5)
  # S is a spatter object that we hope is a single line of text.
  # Outputs a string that simply contains all hits with scores above the threshold, sorted from left to right.
  l = prepearl(s,threshold)
  return l.map { |x| x[2] }.join
end

def dumb_split(s,algorithm,threshold:0.3)
  # S is a spatter object that we hope is a single line of text.
  # Does word splitting based on the simplest algorithm that could possibly output anything legible.
  # Simply splits the line wherever there's too much whitespace, then returns mumble_word() on each word.
  # On each word, then calls the specified algorithm, 'mumble' or 'dag'.
  l = prepearl(s,threshold)
  inter = ((s.max_interword+s.min_interword)*0.5).round
  0.upto(l.length-2) { |i|
    if l[i+1][1]-l[i][1]-s.widths[l[i][2]]-s.max_kern>inter then
      x_split = ((l[i+1][1]+l[i][1])*0.5).round
      s1 = s.select(lambda { |a| a[1]<=x_split})
      s2 = s.select(lambda { |a| a[1]>x_split})
      return dumb_split(s1,algorithm)+" "+dumb_split(s2,algorithm) 
    end
  }
  # If we drop through to here, then this is putatively a single word.
  if algorithm=='mumble' then
    return mumble_word(s)
  end
  if algorithm=='dag' then
    success,string = dag_word(s)
    return string
  end
end

def mumble_word(s)
  # Find the highest-scoring letter in the word. Split the word at that letter, and recurse.
  if s.total_hits==0 then return "" end
  l = prepearl(s,-999.9)
  if l.length==0 then return "" end
  i,garbage = greatest(l.map { |x| x[0]}) # find index i of the highest-scoring letter
  c = l[i][2]
  xl = l[i][1]
  xr = xl + s.widths[c]
  s1 = s.select(lambda { |a| a[1]+s.widths[a[3]]-s.max_kern<=xl})
  s2 = s.select(lambda { |a| a[1]+s.max_kern>=xr})
  return mumble_word(s1)+c+mumble_word(s2)
end

def dag_word(s)
  # Treat the word as a directed acyclic graph, and find the longest path from left to right, where length is measured by sum (score-const).
  # Returns [success,string].
  infinity = 1.0e9
  h = prepearl(s,-infinity)  # looks like a list of [score,x,c].
  n = h.length
  wt = h.map { |a| a[0]-0.5 } # score of each letter, considered as an edge in the graph; 0.5 is the nominal threshold of my scoring scale
  # Build a graph e, which will be an array of edges; e[i+1] is a list of nodes j such that we have an edge from the right side
  # of character i to the left side of character j. e[0] is a list of possible starting chars, e[n] a list of possible ending chars.
  # In other words, e[i+1] is a list of choices we can make after having chosen i. The array e has indices running from 0 to n.
  e = word_to_dag(s,h)
  success,path = longest_path(e,wt)
  string = path.map { |j| h[j][2] }.join('')
  return [success,string]
end

def longest_path(e,wt)
  # The longest-path problem on a DAG has a well-known solution, which involves first finding a topological order:
  #   https://en.wikipedia.org/wiki/Longest_path_problem
  # I get a topological order for free from from my x coordinates, so the problem is pretty easy. Just explore all paths from the left to the right.
  # These two arrays have indices running from 0 to n+1, which represent vertices. If we've already chosen character i, the index is [i+1].
  n = wt.length
  infinity = 1.0e9
  best_score = Array.new(n+2) { |i| -infinity }
  best_path =  Array.new(n+2) { |i| [] }
  # We start at the vertex i=-1, representing having already chosen character -1, i.e., the fake origin vertex where we've made no choices.
  best_score[0] = 0.0 # Score for getting to origin vertex -1 is zero. (offset index -1+1)
  best_path[0] = []
  (-1).upto(n-1) { |i| # we already know the best path in which we've chosen i
    best_score_to_i = best_score[i+1]
    e[i+1].each { |j|
      if j==n then this_wt=0.0 else this_wt=wt[j] end
      new_possible_score = best_score_to_i+this_wt
      if new_possible_score>best_score[j+1] then
        best_score[j+1]=new_possible_score
        best_path[j+1]=shallow_copy(best_path[i+1]) # an array of integers, so can be safely shallow-cloned
        best_path[j+1].push(j)
      end
    }
  }
  # We may not actually have a connection from left to right. If so, then return the path that gets us closest.
  n.downto(0) { |i|
    if best_score[i+1]>-infinity then
      path = best_path[i+1]
      success = (i==n)
      path = path.select {|j| j<n}
      return [success,path]
    end
  }
  die("I can't get started with you. This shouldn't happen, because best_score[0] is initialized to 0.")
end

def word_to_dag(s,h)
  # Converts an input representing some hits to a directed acyclic graph. Input s is a Spatter object.
  # Input h should be in the form output by prepearl(), a list of elements like [score,x,c].
  n = h.length
  # Build a bunch of arrays, all with the same indexing from 0 to n-1.
  w = h.map { |a| s.widths[a[2]] }
  l = h.map { |a| a[1] } # x coord of left edge
  r = [];  0.upto(n-1) { |i| r.push( l[i]+w[i]) } # x coord of right edge
  mi = s.min_interword # any distance greater than this is impermissible within a word
  mk = s.max_kern # any distance less than this is impermissible
  leftmost = h[0][1] # x coord of leftmost char; we don't have to start with leftmost char if others line up with it reasonably well
  rightmost = r.max
  max_end_slop = mi*0.5 # not sure if this is optimal; allow for the possibility that leftmost is actually a bad match and a little too far left, ditto right
  # Build a graph e, which will be an array of edges; e[i+1] is a list of nodes j such that we have an edge from the right side
  # of character i to the left side of character j. e[0] is a list of possible starting chars.
  # To mark an edge connecting to the final vertex, we use j=n.
  # The array e has indices running from 0 to n.
  e = []
  # List of possible starting characters:
  e.push([])
  0.upto(n-1) { |i|
    next if l[i]>leftmost+max_end_slop
    e[0].push(i)
  }
  # Possible transitions from one character to another, or from one character to the final vertex:
  0.upto(n-1) { |i|
    e.push([])
    xr = r[i]
    (i+1).upto(n-1) { |j|
      xl = l[j]
      next if xl>xr+mi
      if xl>xr-mk then e[-1].push(j) end
    }
    if r[i]>rightmost-max_end_slop then e[-1].push(n) end # transition to the final vertex
  }
  return e
end

def prepearl(s,threshold)
  # Inputs a Spatter object and outputs a spatially sorted list of items of the form [score,x,c], eliminating all hits below threshold.
  s = s.you_have_to_have_standards(threshold)
  letters = []
  s.hits.each { |c,h|
    h.each { |hh|
      score,x,y = hh
      if score>threshold then letters.push([score,x,c]) end
    }
  }
  return letters.sort { |p,q| p[1] <=> q[1]}
end

