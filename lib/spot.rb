module Spot
  # Provides mixins that give precise positioning and kerning information.
  # We want the data structure not to get too unwieldy when we serialize it, so all we store is 17 integers: ref_x plus the 16 numbers in the snowman.
  # These mixins are normally applied to an array of the form [score,x,y] (Spatter hit) or [score,x,c] (used in pearls).

  def Spot.bless(a,set,pat)
    a.extend(Spot)
    a.ref_x = pat.ref_x
    a.snowman = clown(pat.snowman(set:set))
  end

  attr_accessor :snowman,:ref_x

  def tension(spot2,em)
    # Measures how much tension exists when spot2 is assumed to be immediately to our right.
    # Positive tension means that the space is too large for these to be two characters in a row of the same word.
    # Negative means too close. The tension is scaled by 60/em, where em is the estimated m width. With this
    # scaling, tension within a word seems to usually be in the range from -10 to +10, mean of about 0 or slightly negative,
    # most values no bigger than +-3. The output is an integer.
    # Also returns what it thinks is an equilibrium position for spot2, where its estimate of tension would vanish.
    # Equilibrium is a value of ref_x(2)-ref_x(1)
    # --
    # The x values in the spots are locations of the reference points on the page.
    # The x values in the snowmen are relative to the left side of the template image.
    x1 = self[1] # [score,x,y]
    x2 = spot2[1]
    r1 = self.ref_x
    r2 = spot2.ref_x
    # Look for overlaps of 1's black with 2's white, or vice versa. There is a total of 6 such overlaps.
    l = []
    0.upto(1) { |color1| # 0=black, 1=white
      color2 = 1-color1
      0.upto(2) { |slab| # 0=top, 1=waist, 2=descender
        s1 = (self.snowman)[1][1][color1][slab] # indices are [horiz=1][left/right][color][slab]
        s2 = (spot2.snowman)[1][0][color2][slab]
        l.push(x2-x1+s2-s1-(r2-r1)) # amount of air, in units of pixels, between these two slabs of the snowmen
      }
    }
    minus_overlap = l.min
    tension = minus_overlap
    equilibrium = x2-x1-minus_overlap
    tension_scaled = (tension*(60.0/em)).round
    return [tension_scaled,equilibrium]
  end
end

def tension_to_strain(t)
  # An ad hoc function meant to represent how much pain it should cause us to have a certain amount of tension.
  a = t.abs
  slope1,slope2,knee = 0.01,0.05,10
  if a<knee then 
    return a*slope1
  else
    return knee*slope1+(a-knee)*slope2
  end
end
