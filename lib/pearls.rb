# These functions are meant to input a single line of matched characters and string them together
# like a string of pearls, returning an OCR result. It might seem more logical to split this up
# into a module that breaks lines into words and another that handles individual words. However,
# it often happens that when we try to analyze a word, we find that it's better analyzed as
# two words.

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
  inter = s.min_interword
  inter = (inter*0.8).round
  # ... min_interword is set based on general typographic practice; the 0.8 is tuned to give best balance between lumping and splitting on sample text
  0.upto(l.length-2) { |i|
    if l[i+1][1]-l[i][1]-s.widths[l[i][2]]>inter then
      x_split = ((l[i+1][1]+l[i][1])*0.5).round
      s1 = s.select(lambda { |a| a[1]<=x_split})
      s2 = s.select(lambda { |a| a[1]>x_split})
      return dumb_split(s1,algorithm)+" "+dumb_split(s2,algorithm) 
    end
  }
  # If we drop through to here, then this is putatively a single word.
  if true then # test print tension, qwe
    0.upto(l.length-2) { |i|
      spot1,spot2 = l[i],l[i+1]
      print "  #{spot1[2]}#{spot2[2]} t=#{spot1.tension(spot2)}   "
    }
    print "\n"
  end
  if algorithm=='mumble' then
    return mumble_word(s)
  end
  if algorithm=='dag' then
    return dag_word(s).join(' ')
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

def split_by_scripts(words_raw)
  # Inputs a list of strings.
  # If we have a word like ηρχεbeganμυθων, split it into multiple words by detecting that the scripts don't match.
  # If we have a word like flγing, where the latin y has been mistakenly read as a gamma, we try to correct that first.
  words = clown(words_raw)
  n = words.length
  # Switch easily mistaken characters surrounded by other script.
  0.upto(n-1) { |i|
    word = words[i]
    if word.length>1 then
      loop do # Loop until it stops changing. But I think the way the algorithm currently works, it's not possible for it to take >1 iteration.
        did_anything = false
        0.upto(word.length-1) { |j|
          compat1 = (j==0 || compatible_scripts(word[j-1],word[j]))
          compat2 = (j==word.length-1 || compatible_scripts(word[j],word[j+1]))
          if (!compat1 && !compat2) || (j==0 && !compat2) || (j==word.length-1 && !compat1) then
            if j==0 || j==word.length-1 || compatible_scripts(word[j-1],word[j+1]) then
              if j==0 then other_script = char_to_code_block(word[j+1]) end
              if j==word.length-1 then other_script = char_to_code_block(word[j-1]) end
              if j!=0 && j!=word.length-1 then other_script=common_script(word[j-1],word[j+1]) end
              alternatives = likely_cross_script_confusion(word[j],other_script)
              if !(alternatives.nil?) then
                n=alternatives[0][0] # if there's more than one, just try the highest-scoring one; mutates words, which is a clone of input
                words[i][j] = short_name_to_char(n)
                did_anything = true
              end
            end
          end
        }
        break if !did_anything
      end
    end
    # Split word where script changes.
    0.upto(word.length-2) { |j|
      if !compatible_scripts(word[j],word[j+1]) then
        result = clown(words)
        result[i] = [word[0..j],word[(j+1)..(word.length-1)]]
        return split_by_scripts(result.flatten)
      end
    }
  }
  return words
end

def dag_word(s)
  # Returns a list of strings. In the nominal case, this list only has one word, but sometimes we have to split it into multiple words.
  success,string,remainder = dag_word_one(s)
  result = [string]
  if !success then result.concat(dag_word(remainder)) end
  return split_by_scripts(result)
end

def dag_word_one(s)
  # Treat the word as a directed acyclic graph, and find the longest path from left to right, where length is measured by sum (score-const).
  # Returns [success,string].
  debug = false
  #debug = (mumble_word(s)=='ταυρωντε')
  #debug = (mumble_word(s)=='hecatoub') 
  #debug = (mumble_word(s)=='Zηνς') 
  infinity = 1.0e9
  h = prepearl(s,-infinity)  # looks like a list of [score,x,c].
  n = h.length
  if n==0 then return [true,'',nil] end
  wt = h.map { |a| a[0]-0.5 }
  # ...score of each letter, considered as an edge in the graph. It doesn't actually seem to matter much whether I subtract 0.5 (the
  #    nominal threshold of my scoring scale) or 1.0 (which makes sense if you figure that a score of 1-epsilon means a probability
  #    epsilon of error, and ln(1-epsilon)~-epsilon). The latter does cause "halls" to be read as "hals."
  #wt = h.map { |a| if a[2]=='u' then -100.0 else a[0]-1.0 end }
  # Build a graph e, which will be an array of edges; e[i+1] is a list of nodes j such that we have an edge from the right side
  # of character i to the left side of character j. e[0] is a list of possible starting chars, e[n] a list of possible ending chars.
  # In other words, e[i+1] is a list of choices we can make after having chosen i. The array e has indices running from 0 to n.
  e = word_to_dag(s,h)
  success,path,score,if_error_error_message = longest_path(e,wt,debug:debug)
  string = path.map { |j| h[j][2] }.join('')
  if !success then
    # We didn't make it all the way to the end. Interpret this as multiple words.
    i = path[-1] # index of the rightmost character we were able to get to
    xr = h[i][1]+s.widths[h[i][2]] # x coord of right edge of that character
    remainder = s.select(lambda { |a| a[1]>xr })
    # ... all chars whose left edge lies to the right of that; typically there's a big gap, which is why we failed
  else
    remainder = nil
  end

  if debug then print "n=#{n}\nh=[[score,x,c],...]=#{h}\nwt=#{wt}\nsuccess=#{success}, path=#{path}\ne=#{e}\n" end

  return [success,string,remainder]
end

def longest_path(e,wt,debug:false)
  # The longest-path problem on a DAG has a well-known solution, which involves first finding a topological order:
  #   https://en.wikipedia.org/wiki/Longest_path_problem
  # I get a topological order for free from from my x coordinates, so the problem is pretty easy. Just explore all paths from the left to the right.
  # The two-dimensional array e contains lists of edges, with e[i+1] being the list of choices we can make after having already chosen i.
  # There are fake vertices -1 and n representing the start and end of the graph.
  # The vertex i=-1 represents the idea that we've "chosen" to start. The choice n represents choosing to reach the end of the graph.
  # The list wt contains the weights of the edges.
  # This algorithm is written to prefer depth over score, i.e., we prefer to include all characters, even if the resulting score is low.
  # These two arrays have indices running from 0 to n+1, which represent vertices. If we've already chosen character i, the index is [i+1].
  # Test.rb has unit tests for this routine.
  # Returns [success,best_path,best_score,if_error,error_message]
  n = wt.length
  if n==0 then return [true,[],0.0,false,nil] end
  infinity = 1.0e9
  if e.length!=n+1 then return [false,[],-infinity,true,"Edge matrix has the wrong length, #{e.length} instead of n+1=#{n+1}"] end
  best_score = Array.new(n+2) { |i| -infinity }
  best_path =  Array.new(n+2) { |i| nil }
  # We start at the vertex i=-1, representing having already chosen character -1, i.e., the fake origin vertex where we've made no choices.
  best_score[0] = 0.0 # Score for getting to origin vertex -1 is zero. (offset index -1+1)
  best_path[0] = []
  (-1).upto(n-1) { |i| # we already know the best path in which we've chosen i
    next if best_path[i+1].nil?
    #if debug then print "i=#{i}, best_path=#{best_path}\n" end
    best_score_to_i = best_score[i+1]
    e[i+1].each { |j|
      if j==n then this_wt=0.0 else this_wt=wt[j] end
      if j<=i then return [false,[],-infinity,true,"Graph is not topologically ordered."] end
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
      return [success,path,best_score[i+1],false,nil]
    end
  }
  die("I can't get started with you. This shouldn't happen, because best_score[0] is initialized to 0.")
end

def word_to_dag(s,h,slop:0)
  # Converts an input representing some hits to a directed acyclic graph. Input s is a Spatter object.
  # Input h should be in the form output by prepearl(), a list of elements like [score,x,c].
  n = h.length
  # Build a bunch of arrays, all with the same indexing from 0 to n-1.
  w = h.map { |a| s.widths[a[2]] }
  l = h.map { |a| a[1] } # x coord of left edge
  r = [];  0.upto(n-1) { |i| r.push( l[i]+w[i]) } # x coord of right edge
  leftmost = h[0][1] # x coord of leftmost char; we don't have to start with leftmost char if others line up with it reasonably well
  rightmost = r.max
  max_sp = s.min_interword+slop # any spacing greater than this is impermissible within a word
  min_sp = -s.max_kern-slop # any spacing less than this is impermissible; this is normally negative, because kerning allows overlap
  max_end_slop = s.min_interword*0.5
  # ... maybe not optimal; allow for the possibility that leftmost is actually a bad match and a little too far left, ditto right
  if slop>0 then max_end_slop+= slop end # making max_end_slop negative produces goofy results
  # Build a graph e, which will be an array of edges; e[i+1] is a list of nodes j such that we have an edge from the right side
  # of character i to the left side of character j. e[0] is a list of possible starting chars.
  # To mark an edge connecting to the final vertex, we use j=n.
  # The array e has indices running from 0 to n.
  e = []
  # List of possible starting characters:
  e.push([])
  0.upto(n-1) { |i|
    break if l[i]>leftmost+max_end_slop
    e[0].push(i)
  }
  if e[0].length==0 then e[0]=[0] end # can happen if max_end_slop<0
  # Possible transitions from one character to another, or from one character to the final vertex:
  0.upto(n-1) { |i|
    e.push([])
    xr = r[i]
    (i+1).upto(n-1) { |j|
      xl = l[j]
      if xl<xr+max_sp && xl>xr+min_sp then e[i+1].push(j) end
    }
    if r[i]>rightmost-max_end_slop then e[i+1].push(n) end # transition to the final vertex
  }
  return e
end

def prepearl(s,threshold)
  # Inputs a Spatter object and outputs a spatially sorted list of items of the form [score,x,c], eliminating all hits below threshold.
  # If the input hits are blessed with the Spot mixins, then the output will have the same blessing.
  s = s.you_have_to_have_standards(threshold)
  letters = []
  s.hits.each { |c,h|
    h.each { |hh|
      score,x,y = hh
      if score>threshold then
        hh = clown(hh) # deep copy to preserve Spot mixins
        hh[2] = c
        letters.push(hh)
      end
    }
  }
  return letters.sort { |p,q| p[1] <=> q[1]}
end

