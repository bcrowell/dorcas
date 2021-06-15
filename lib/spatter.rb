class Spatter
  # Encapsulates a list of hits, with their spatial locations and scores, along with basic spatial
  # information such as estimated line spacing, maximum kerning, and interword spacing.
  # Putting this in a class is meant to make it easier to add functionality such as efficient searching.

  def initialize(hits,page,sets)
    # Hits should be a hash whose keys are characters and whose values are lists of hits in the format [score,x,y].
    # The page and sets inputs are used only for extracting geometrical information.
    # Sets is a list of sets, but I've been using only a single set to encapsulate all templates for a given book, so normally
    # there will only be a single set in the list.
    @line_spacing = page.stats['line_spacing']
    @max_w = sets.map { |set| set.max_w}.max
    @max_h = sets.map { |set| set.max_h}.max
    @em = find_median(sets.map { |set| set.estimate_em})
    # Bracket a reasonable range for interword spacing. Convention is 1/3 em to 1/2 em, but will obviously vary in justified text.
    @min_interword = (0.3*@em).round
    @max_interword = (0.53*@em).round
    @max_kern = (@em*0.15).round # https://en.wikipedia.org/wiki/Kerning
    @hits = hits.sort {|p, q| q[0] <=> p[0]} # sort in descending order by score; are probably sorted in decreasing order already, or approximately so
  end

  attr_reader :hits,:line_spacing,:max_w,:max_h,:em,:min_interword,:max_interword,:max_kern

  def report_geom
    return stats_to_string({'line_spacing':self.line_spacing,'max_w':self.max_w,'max_h':self.max_h,'em':self.em,
                 'min_interword':self.min_interword,'max_interword':self.max_interword,'max_kern':self.max_kern})
  end

  def plow
    # Return a list of new Spatter objects, each of which is estimated to be a line of text.
    # This is meant to be the dumbest algorithm that has any hope of working.
  end

end

