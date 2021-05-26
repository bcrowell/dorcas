def char_to_code_block(c)
  # returns greek, latin, hebrew
  # for	punctuation or whitespace, returns latin
  b = char_unicode_property(c,'opt_unicode_block_desc')
  if b=~/(Latin|Greek|Hebrew)/ then return $1.downcase end
  return b
end

def char_to_name(c)
  # Returns the official unicode name of the character.
  # Although these names are officially case-insensitive, this routine always returns uppercase.
  # Examples of names returned:
  #   LATIN SMALL LETTER A
  #   GREEK SMALL LETTER BETA
  #   HEBREW LETTER ALEF
  return char_unicode_property(c,'name').upcase
end

def char_to_short_name(c)
  # This mapping is meant to be one-to-one. The short name is supposed to be pure ascii, easy to type, and will not contain any spaces,
  # so it's appropriate for a filename.
  # Examples of returned values: a, A, alpha, Alpha, alef
  name = char_to_short_name_helper(c)
  if short_name_to_long_name(name)==char_to_name(c) then return name end # Make sure it works reversibly.
  return name # Fallback if we can't make the round trip reliably.
end

def char_to_short_name_helper(c)
  # Don't call this directly. Call char_to_short_name(), which follows up by verifying that we can reverse the mapping.
  long = char_to_name(c)
  if long=~/LATIN SMALL LETTER (.)/ then return $1.downcase end
  if long=~/LATIN CAPITAL LETTER (.)/ then return $1.upcase end
  if long=~/GREEK SMALL LETTER (.*)/ then return lc_underbar($1) end
  if long=~/GREEK CAPITAL LETTER (.*)/ then return lc_underbar($1).capitalize end
  if long=~/HEBREW LETTER (.*)/ then return lc_underbar($1) end
  return lc_underbar(long)
end

def lc_underbar(s)
  return s.downcase.gsub(/' '/,'_')
end

def short_name_to_long_name(name)
  if name.length==1 then return char_to_name(name) end # Latin
  if name=~/_/ then return name.gsub(/_/,' ').upcase end
  if is_name_of_hebrew_letter(name) then return "HEBREW LETTER #{name}".upcase end
  if is_name_of_greek_letter(name) then
    if name==name.downcase then
      return "GREEK SMALL LETTER #{name}".upcase
    else
      return "GREEK CAPITAL LETTER #{name}".upcase
    end
  end
  return nil
end

def is_name_of_greek_letter(s)
  return s=~/^(Alpha|Beta|Gamma|Delta|Epsilon|Zeta|Eta|Theta|Iota|Kappa|Lambda|Mu|Nu|Xi|Omicron|Pi|Rho|Sigma|Tau|Upsilon|Phi|Chi|Psi|Omega)$/i
end

def is_name_of_hebrew_letter(s)
  return s=~/^(Alef|Bet|Gimel|Dalet|He|Vav|Zayin|Het|Tet|Yod|Final_Kaf|Kaf|Lamed|Final_Mem|Mem|Final_Nun|Nun|Samekh|Ayin|Final_Pe|Pe|Final_Tsadi|Tsadi|Qof|Resh|Shin|Tav)$/i
end


def char_unicode_property(c,property)
  # https://en.wikipedia.org/wiki/Unicode_character_property
  # Shells out to the linux command-line utility called	"unicode," which is installed as the debian packaged of	the same name.
  # list of properties: https://github.com/garabik/unicode/blob/master/README
  #   useful ones include opt_unicode_block_desc, category, name
  # This is only going to work on Unix, and is also rather slow.
  # A platform-independent way to do this, without linking to C code, might be to use python's unicodedata module, but that would still be slow.
  # Probably better to write out a memoization table and then cut and paste it back into the code.
  if c=='"' then c='\\"' end
  result	= `unicode --string "#{c}" --format "{#{property}}"`
  if $?!=0 then	die($?) end
  return result
end

def escape_double_quotes(s)
  return s.gsub(/"/,'\\"') # escape double quotes
end

