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
    @rtl = (s=='hebrew')
    @ltr = !@rtl
  end

  attr_reader :name,:rtl,:ltr

  def to_s()
    return "script: #{self.name}"
  end

  def alphabet_with_large_punctuation(c:"lowercase")
    return self.alphabet(c)+self.large_punctuation()
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

  def large_punctuation
    # Punctuation that's big enough that it makes sense to scan for it using the same algorithm as for letters of the alphabet -- not "minnows."
    if self.name=='latin' then result="?" end
    if self.name=='greek' then result="" end
    if self.name=='hebrew' then result="" end
    return result
  end

  def Script.remove_small_punctuation(x)
    # Get rid of punctuation marks that are "minnows" -- too small to scan for using the same algorithm as for letters of the alphabet.
    return x.gsub(/[.,'\";:-\[\]]/,'')
  end

  def common_punctuation
    if self.name=='latin' then result=".,'\";:-?" end
    if self.name=='greek' then result=".,';-" end # incomplete - fixme
    if self.name=='hebrew' then result=".," end # ? -- fixme
    return result
  end

  def has_case
    return !(@name=='hebrew')
  end

  def all_letters()
    if self.has_case then return self.alphabet(c:"lowercase")+self.alphabet(c:"uppercase") else return self.alphabet end
  end

  def Script.generate_table_for_char_to_short_name()
    h = {}
    ['latin','greek','hebrew'].each { |n|
      console "#{n}\n"
      script = Script.new(n)
      l = script.all_letters()
      if n=='latin' then l=l+'ÆæŒœ.,;:-?/<>[]{}_+=!#%^&~' end # fixme -- some characters have special significance to the shell and cause errors
      if n=='greek' then l=l+"ΆΈΊΌΐάέήίϊόύώỏἀἁἃἄἅἈἐἑἒἔἕἘἙἜἡἢἣἤἥἦἨἩἫἬἮἰἱἲἴἵἶἸὀὁὂὃὄὅὊὍὐὑὓὔὕὖὗὝὡὢὣὤὥὧὨὩὰὲὴὶὸὺὼᾐᾗᾳᾴᾶῂῆῇῖῥῦῳῶῷῸᾤᾷἂἷὌᾖὉἧἷἂῃἌὬὉἷὉἷῃὦἌἠἳᾔἉᾦἠἳᾔὠᾓὫἝὈἭἼϋὯῴἆῒῄΰῢἆὙὮᾧὮᾕὋἍἹῬἽᾕἓἯἾᾠἎῗἾῗἯἊὭἍᾑ" end
      # ... This includes every character occurring in the Project Gutenberg editions of Homer, except for some that seem to be
      #     mistakes (smooth rho, phi and theta in symbol font). Duplications and characters out of order in this list have no effect at run time.
      l.chars.uniq.each { |c|
        nn = char_to_short_name_slow(c)
        #console "  #{c} --> #{nn}\n"
        h[c] = nn
      }
    }
    print JSON.generate(h)
  end

  def alphabet_helper(include_lc_only_chars)
    if self.name=='latin'  then return 'abcdefghijklmnopqrstuvwxyz' end
    if self.name=='greek'  then 
      result = 'αβγδεζηθικλμνξοπρστυφχψω'
      if include_lc_only_chars then result = result+'ς' end
      return result.unicode_normalize(:nfc)
    end
    if self.name=='hebrew'  then return 'אבגדהוזחטילמנסעפצקרשתםןףץ'.unicode_normalize(:nfc) end
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
      if side==0 then guard = "AT1!H.,;:p'{_=|~?/" else guard="!]':?HTiXoj" end
    end
    if self.name=='greek' then
      # Don't add characters to the following that may not be covered in a Greek font. In particular, GFSPorson lacks Latin characters.
      if side==0 then guard = "ΠΩΔΥΗ.,'ρ" else guard="ΠΩΔΥΗ'" end
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

def likely_cross_script_confusion(c,other_script,threshold:5)
  # If we see the character c surrounded on both sides by characters that are in some other script, we
  # may ask ourselves, what could possibly go wrong?
  # Input is like ('ω','latin'). Output is a list of pairs like ['w',5], where the first
  # element is the character we could be confusing it for, and the second is a subjective
  # measure of how easily confused they are. This number is 10 for characters that are
  # virtually indistinguishable to a human without hints from context, 5 if you can usually
  # tell. The output is sorted in descending order by score, so we can just take the first if we wish.
  # Output is nil if we don't find any matches.
  n = char_to_short_name(c)
  confusions = {
    'omicron,latin'=>[['o',10]],    'o,greek'=>[['omicron',10]],
    'Zeta,latin'=>[['Z',10]],       'Z,greek'=>[['Zeta',10]],
    'nu,latin'=>[['v',10]],         'v,greek'=>[['nu',10]],
    'alpha,latin'=>[['a',5]],       'a,greek'=>[['alpha',5]],
    'iota,latin'=>[['i',5]],        'i,greek'=>[['iota',5]],
    'omega,latin'=>[['w',5]],       'w,greek'=>[['omega',5]],
    'gamma,latin'=>[['y',5]],       'y,greek'=>[['gamma',5]],
    'Lambda,latin'=>[['A',5]],      'A,greek'=>[['Lambda',5]],
  }
  result = confusions["#{n},#{other_script}"]
  if result.nil? then return result end
  result = result.select { |a| a[1]>=threshold }
  if result.length==0 then return nil end
  return result.sort { |p,q| q[1] <=> p[1]} # sort in descending order by score
end

