# coding: utf-8
class Script
  def initialize(s)
    # s can either be a name ('latin','greek','hebrew') or a sample character in that script ('w','θ',...)
    if s=='latin' or s=='greek' or s=='hebrew' then
      @name = s
    else
      @name = char_to_code_block(s) # returns greek, latin, or hebrew
    end
    # Make sure the name instance variable uniquely identifies the script, so that memoization works in font.metrics().
  end

  attr_reader :name

  def to_s()
    return "script: #{self.name}"
  end

  def alphabet(c:"lowercase")
    # c can be lowercase, uppercase, or both
    # For scripts that don't have case, c is ignored.
    if !(self.has_case) then return self.alphabet_helper(nil) end
    if c=='both' then return self.alphabet(c:"lowercase")+self.alphabet(c:"uppercase") end
    # If we fall through to here, then we're doing a single case of an alphabet that has two cases.
    if c=='lowercase' then return self.alphabet_helper(true) end
    if c=='uppercase' then return self.alphabet_helper(false).upcase end
    die("illegal value of c=#{c}, must be both, lowercase, or uppercase")
  end

  def has_case
    return !(@name=='hebrew')
  end

  def alphabet_helper(include_lc_only_chars)
    if self.name=='latin'  then return 'abcdefghijklmnopqrstuvwxyz' end
    if self.name=='greek'  then 
      result = 'αβγδεζηθικλμνξοπρστυφχψω'
      if include_lc_only_chars then result = result+'ς' end
      return result
    end
    if self.name=='hebrew'  then return 'אבגדהוזחטילמנסעפצקרשתםןףץ' end
    # ... Word-final forms are all at the end.
    #     To edit the Hebrew list, use mg, not emacs. Emacs tries to be smart about RTL but freaks out and gets it wrong on a line that mixes RTL and LTR.
    die("no alphabet available for script #{self.name}")
  end

  def full_height_string()
    if self.name=='latin'  then return 'hp' end
    if self.name=='greek'  then return 'ζγμ' end
    if self.name=='hebrew' then return 'לץ' end
    return '1,' # likely to be rendered in any font; probably too short for any font that actually has descenders, but don't know what else to fall back on
  end

  def x_height_string()
    if self.name=='latin'  then return 'm' end
    if self.name=='greek'  then return 'ν' end
    if self.name=='hebrew' then return 'א' end
    return '1' # likely to be rendered in any font; probably too tall for any font that actually has ascenders, but don't know what else to fall back on
  end

  def m_width_string()
    # Wikipedia https://en.wikipedia.org/wiki/Em_(typography) says that the em unit is today defined simply as
    # the point size of the font. However, I want a way to find out how big characters are really, truly rendered.
    if self.name=='latin'  then return 'M' end
    if self.name=='greek'  then return 'Μ' end # capital mu
    if self.name=='hebrew' then return 'ש' end
    return '81' # likely to be rendered in any font; in most fonts its width is about the same as the width of M
  end

  def guard_rail_chars(side)
    # To find out how much white "personal space" the character has around it, we render various other "guard-rail" characters
    # to the right and left of it. The logical "or" of these is space that we know can be occupied by other characters. I visualize
    # this as red.
    # side=0 means guard-rail chars will be on the right of our character, 1 means left
    # Many fonts that contain one script don't contain coverage of other scripts. Rendering libraries may leave a blank or sub in some other font, but
    # this produces goofy results, such as unpredictable variations in line height. So use guard-rail characters
    # that are from the same script. This was an issue for GFSPorson, which lacks Latin characters.
    guard = nil
    if self.name=='latin' then
      if side==0 then guard = "AT1!H.,;:'{_=|~?/" else guard="!]':?HTiXo" end
    end
    if self.name=='greek' then
      # Don't add characters to the following that may not be covered in a Greek font. In particular, GFSPorson lacks Latin characters.
      if side==0 then guard = "ΠΩΔΥΗ.,'" else guard="ΠΩΔΥΗ'" end
    end
    if self.name=='hebrew' then
      # Don't add characters to the following that may not be covered in a Hebrew font.
      if side==0 then guard = "ח.,'" else guard="ר''" end
    end
    if guard.nil? then
      # provide some kind of fall-back
      if side==0 then guard = "1.,'" else guard="1''" end
    end
    return guard
  end

end

