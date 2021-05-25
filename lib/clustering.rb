def find_clusters(c,cluster_threshold,used:[])
  # For more ideas on how to do this, see Hartigan, Clustering algorithms.
  # c is a symmetric square matrix of correlation values.
  # Items are assumed to be sorted in decreasing order of interest.
  # If items have a correlation lower than cluster_threshold, then we assume they're not in the same category, i.e., the cluster is limited in radius.
  # The argument used is for internal use in recursion.
  # Returns a list of clusters, each described as a list of indices.
  if used.length==c.length then return [] end
  n = c.length
  model = nil
  0.upto(n-1) { |i|
    if not used.include?(i) then model=i; break end
  }
  if model.nil? then die("coding error, used.length!=c.length, but nothing is unused") end
  results = [model]
  0.upto(n-1) { |i|
    if i==model or used.include?(i) then next end
    not_like_us = false
    results.each { |already_a_member|
      if c[already_a_member][i]<cluster_threshold then not_like_us=true; break end
    }
    if not_like_us then next end
    results.push(i)
  }
  others = find_clusters(c,cluster_threshold,used:used.union(results))
  return [results].concat(others)
end
