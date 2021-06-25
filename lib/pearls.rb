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

def dumb_split(s,algorithm,lingos,threshold:0.3)
  # S is a spatter object that we hope is a single line of text.
  # Does word splitting based on the simplest algorithm that could possibly output anything legible.
  # Simply splits the line wherever there's too much whitespace, then returns an interpretation of on each word.
  # On each word, then calls the specified algorithm, 'mumble' or 'dag'.
  # Lingos is a hash that maps script name to Lingo object.
  l = prepearl(s,threshold)
  inter = s.min_interword
  inter = (inter*0.8).round
  # ... min_interword is set based on general typographic practice; the 0.8 is tuned to give best balance between lumping and splitting on sample text
  0.upto(l.length-2) { |i|
    spot1,spot2 = l[i],l[i+1]
    tension,equilibrium = spot1.tension(spot2,s.em)
    if spot2.ref_x-spot1.ref_x>equilibrium+inter then
      x_split = ((l[i+1][1]+l[i][1])*0.5).round
      s1 = s.select(lambda { |a| a[1]<=x_split})
      s2 = s.select(lambda { |a| a[1]>x_split})
      return dumb_split(s1,algorithm,lingos)+" "+dumb_split(s2,algorithm,lingos) 
    end
  }
  # If we drop through to here, then this is putatively a single word.
  if algorithm=='mumble' then
    return mumble_word(s)
  end
  if algorithm=='dag' then
    return dag_word(s,lingos).join(' ')
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
    #debug=(word=~/muon/)
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

def dag_word(s,lingos)
  # Returns a list of strings. In the nominal case, this list only has one word, but sometimes we have to split it into multiple words.
  success,string,hits,remainder = dag_word_one(s,lingos)
  result = [string]
  if !success then result.concat(dag_word(remainder,lingos)) end
  return split_by_scripts(result)
end

def dag_word_one(s,lingos)
  # Treat the word as a directed acyclic graph, and find the longest path from left to right, where length is measured by sum (score-const).
  # Returns [success,string,hits,remainder], where hits is the list of hits, in the format output by prepearl, that formed the string.
  # If we weren't able to get all the way through the word, then success is set to false, and remainder is a Spatter object containing
  # the remaining hits that we weren't able to process.
  debug = false
  #debug = (mumble_word(s)=='ταυρωντε')
  infinity = 1.0e9
  h = prepearl(s,-infinity)  # looks like a list of [score,x,c].
  n = h.length
  if n==0 then return [true,'',nil] end
  template_scores = h.map { |a| template_score_to_additive(a[0]) }
  # Build a graph e, which will be an array of edges; e[i+1] is a list of [j,weight], where j is such that we have an edge from the right side
  # of character i to the left side of character j. e[0] is a list of possible starting chars, e[n] a list of possible ending chars.
  # In other words, e[i+1] is a list of choices we can make after having chosen i, along with their scores. The array e has indices running from 0 to n.
  e = word_to_dag(s,h,template_scores,lingos)
  string,remainder,success,path,score,if_error,error_message = longest_path_fancy(s,h,e,debug:debug)
  path,string,remainder = consider_more_paths(path,remainder,e,h,lingos,s)
  hits = path.map { |j| h[j] }
  return [success,string,hits,remainder]
end

def consider_more_paths(path,remainder,e,h,lingos,s)
  infinity = 1.0e8
  debug = false
  choices = [path]
  remainders = [remainder]
  xr = h.map { |a| a[1]+s.widths[a[2]] } # approx right-hand edge of each character
  target_x = clown(xr[-1])
  # Try knocking out each letter of the longest path to get other possibilities.
  path.each { |i|
    ee,hh = knock_out_spot(e,h,i,infinity)
    string2,remainder2,success,path2,score,if_error,error_message = longest_path_fancy(s,hh,ee,target_x:target_x)
    if !if_error then choices.push(path2); remainders.push(remainder2) end
  }
  scores = []
  choices.each { |path2|
    total_score,template_score,tension_score,lingo_score = score_path_fancy(s,path2,e,h,lingos,s.em,target_x:target_x)
    scores.push(total_score)
  }
  i,garbage = greatest(scores)
  path2 = choices[i]
  return [path2,path_to_string(h,path2),remainders[i]]
end

def knock_out_spot(e,h,i,infinity)
  ee = clown(e)
  hh = clown(h)
  (-1).upto(ee.length-2) { |j|
    ee[j+1] = ee[j+1].map { |a| if a[0]==i then [i,-infinity] else a end}
  }
  hh[i][0] = -infinity
  return [ee,hh]
end

def score_path_fancy(s,path,e,h,lingos,em,target_x:nil)
  template_score = 0.0
  path.each { |i| template_score += template_score_to_additive(h[i][0]) }
  # --
  tension_score = 0.0
  0.upto(path.length-2) { |m|
    spot1,spot2 = h[path[m]],h[path[m+1]]
    strain = tension_to_strain(spot1.tension(spot2,em)[0])
    tension_score += (-stiffness()*strain)
  }
  # --
  lingo_score = 0.0
  script = char_to_script_and_case(h[0][2])[0]
  if !(lingos.nil?) and lingos.has_key?(script) then
    string = path_to_string(h,path)
    if lingos[script].is_word(string) then lingo_score=1.0 end
  end
  # --
  length_score = 0.0
  if !target_x.nil? then a=h[path[-1]]; xr=a[1]+s.widths[a[2]]; length_score=(xr-target_x)*keep_goingness()/em.to_f end
  # --
  total = template_score+tension_score+lingo_score+length_score
  return [total,template_score,tension_score,lingo_score]
end

def template_score_to_additive(score)
  return score-1.0
  # ...Results don't seem super sensitive to the choice of the constant 1.0. Choosing 0.5 makes it do more stuff like reading μ as ιι.
  #    Since 1.0 is the nominal high end of my scale, this choice means that we can only lose, not gain, by including a character.
  #    If we imagine that the probability of error P is proportional to 1.0-s, then the independent probability that every letter is right
  #    is Π s = exp Σ ln s, which, using the Taylor series, is approximately exp Σ (s-1).
end

def stiffness()
  return 1.0 # a constant used in scoring; it controls the importance of the tension (plausibility of the spacing/kerning)
end

def keep_goingness()
  return 5.0   # If considering a shorter path through a dag, this is how much we're penalized, per em width.
end

def longest_path_fancy(s,h,e,target_x:nil,debug:false)
  em = s.em
  if target_x.nil? then
    early_quitting_penalty = nil
  else
    xr = h.map { |a| a[1]+s.widths[a[2]] } # approx right-hand edge of each character
    early_quitting_penalty = xr.map { |r| (r-target_x)/em.to_f*keep_goingness() } 
  end
  success,path,best_score,if_error,error_message = longest_path(e,early_quitting_penalty:early_quitting_penalty,debug:debug)
  if if_error then return ['',nil,success,path,best_score,if_error,error_message] end
  string = path_to_string(h,path)
  remainder = get_remainder(success,s,h,path,em/5.0)
  return [string,remainder,success,path,best_score,if_error,error_message]
end

def get_remainder(success,s,h,path,slop)
  if success then return nil end
  i = path[-1] # index of the rightmost character we were able to get to
  xr = h[i][1]+s.widths[h[i][2]] # x coord of right edge of that character
  remainder = s.select(lambda { |a| a[1]>xr+slop })
  # ... all chars whose left edge lies to the right of that; typically there's a big gap, which is why we failed
  return remainder  
end

def path_to_string(h,path)
  return reverse_if_rtl(path.map { |j| h[j][2] }.join('')) # fixme: won't handle punctuation in bidi text (weak and neutral characters)
end

def longest_path(e,early_quitting_penalty:nil,debug:false)
  # The longest-path problem on a DAG has a well-known solution, which involves first finding a topological order:
  #   https://en.wikipedia.org/wiki/Longest_path_problem
  # I get a topological order for free from from my x coordinates, so the problem is pretty easy. Just explore all paths from the left to the right.
  # E is a list of lists of edges, with e[i+1] being the list of elements in the form [j,w], where
  # The array e has indices running from 0 to n+1, which represent vertices. If we've already chosen character i, the index is [i+1].
  # J is a choice we can make after having already chosen i, and w is the associated weight of that edge.
  # There are fake vertices -1 and n representing the start and end of the graph.
  # The vertex i=-1 represents the idea that we've "chosen" to start. The choice n represents choosing to reach the end of the graph.
  # It's pretty common that we don't get to the end, which just means that we actually need to split into multiple words, so the algorithm
  # needs permission to quit early, and some criterion for doing that.
  # This algorithm is written to prefer depth over score, i.e., we prefer to include all characters, even if the resulting score is low.
  # Test.rb has unit tests for this routine.
  # Returns [success,best_path,best_score,if_error,error_message]
  n = e.length-1
  if n==0 then return [true,[],0.0,false,nil] end
  infinity = 1.0e9
  best_score = Array.new(n+2) { |i| -infinity }
  best_path =  Array.new(n+2) { |i| nil }
  # We start at the vertex i=-1, representing having already chosen character -1, i.e., the fake origin vertex where we've made no choices.
  best_score[0] = 0.0 # Score for getting to origin vertex -1 is zero. (offset index -1+1)
  best_path[0] = []
  (-1).upto(n-1) { |i| # we already know the best path in which we've chosen i
    next if best_path[i+1].nil?
    best_score_to_i = best_score[i+1]
    e[i+1].each { |edge|
      j,w = edge
      if j>n then return  [false,[],-infinity,true,"Graph refers to vertex #{j}, which is greater than #{n}."] end
      if j==n then w=0.0 end
      if j<=i then return [false,[],-infinity,true,"Graph is not topologically ordered."] end
      new_possible_score = best_score_to_i+w
      if new_possible_score>best_score[j+1] then
        best_score[j+1]=new_possible_score
        best_path[j+1]=shallow_copy(best_path[i+1]) # an array of integers, so can be safely shallow-cloned
        best_path[j+1].push(j)
      end
    }
  }
  # We may not actually have a connection from left to right. If so, then pick something shorter. 
  options_scores = []
  options_data = []
  n.downto(0) { |i|
    if best_score[i+1]>-infinity then
      path = best_path[i+1]
      success = (i==n)
      path = path.select {|j| j<n}
      this_score = best_score[i+1]
      data = [success,path,this_score,false,nil]
      if early_quitting_penalty.nil? then return data end
      # ... If it's the classical problem, then just return the deepest path, regardless of score. This is used in unit tests.
      if i<=n-1 then this_score += early_quitting_penalty[i] end
      options_scores.push(this_score)
      options_data.push(clown(data))
    end
  }
  if options_scores.length==0 then die("I can't get started with you. This shouldn't happen, because best_score[0] is initialized to 0.") end
  m,garbage = greatest(options_scores)
  return options_data[m]
end

def word_to_dag(s,h,template_scores,lingos,slop:0)
  # Converts an input representing some hits to a directed acyclic graph. Input s is a Spatter object.
  # Input h should be in the form output by prepearl(), a list of elements like [score,x,c].
  # It's OK if lingos is nil or missing an entry for a given script.
  # The graph is directed from left to right. A successful traversal of the graph in the case of an RTL script
  # will have the letters in backwards order, which it's up to the calling routine to handle once it's decided that
  # that's the traversal it wants. In the code below, we do handle RTL properly when we drill down to the level
  # of bigrams, but I haven't tested that code at all.
  n = h.length
  em = s.em # estimate of em width, used only to provide the proper scaling invariance for tension
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
  would_be_starting_char = {}
  e.push([])
  0.upto(n-1) { |i|
    break if l[i]>leftmost+max_end_slop
    e[0].push([i,template_scores[0]])
    if char_is_ltr(h[i][2]) then would_be_starting_char[i] = 1 end # completely different logic below for RTL case
  }
  if e[0].length==0 then e[0]=[0,0] end # can happen if max_end_slop<0
  # Possible transitions from one character to another, or from one character to the final vertex:
  0.upto(n-1) { |i|
    e.push([])
    xr = r[i]
    (i+1).upto(n-1) { |j|
      spot1,spot2 = h[i],h[j]
      strain = tension_to_strain(spot1.tension(spot2,s.em)[0])
      score = template_scores[j] - stiffness()*strain
      xl = l[j]
      next unless xl<xr+max_sp && xl>xr+min_sp
      reject_bigram = false
      if !(lingos.nil?) then
        c1,c2 = h[i][2],h[j][2]
        script = char_to_script_and_case(c1)[0]
        if lingos.has_key?(script) then
          lingo = lingos[script]
          if char_is_ltr(c1) then
            if would_be_starting_char.has_key?(i) && !(lingo.bigram_can_be_word_initial?(c1+c2)) then reject_bigram=true end
            # ... also has the effect of rejecting stuff like τo, where the o is a latin o rather than an omicron
            if !(lingo.bigram_can_exist?(c1+c2)) then reject_bigram=true end
          else
            if !(lingo.bigram_can_exist?(c2+c1)) then reject_bigram=true end
          end
        end
      end
      #if reject_bigram then print "rejecting word-initial bigram #{c1+c2}\n" end
      next if reject_bigram
      e[i+1].push([j,score])
    }
    if r[i]>rightmost-max_end_slop then # transition to the final vertex
      e[i+1].push([n,0.0])
      # --- Handle word-initial bigrams for RTL scripts:
      #     The following is completely untested.
      c1 = h[i][2]
      if char_is_rtl(c1) then
        if !(lingos.nil?) then
          script = char_to_script_and_case(c1)[0]
          if lingos.has_key?(script) then
            lingo = lingos[script]
            0.upto(i-1) { |j|
              e[j+1] = e[j+1].select { |a| ii,score=a; ii!=i || lingo.bigram_can_be_word_initial?(c1+h[j][2]) }
            }
          end
        end
      end
    end
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

def debug_print_graph(e,h)
  (-1).upto(e.length-2) { |i|
    x = e[i+1].map { |edge| "[#{edge[0]} #{debug_print_graph_helper(edge[0],h)},#{sprintf('%4.2f',edge[1])}]" }
    print "  #{sprintf('%4d',i)}  #{debug_print_graph_helper(i,h)}  |  #{x.join(' ')}\n"
    if i>=20 then print "cutting off after 20 lines\n"; return end
  }
end

def debug_print_graph_helper(i,h)
  if i==-1 || i>h.length-1 then return ' ' end
  return h[i][2]
end
