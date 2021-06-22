def char_to_code_block(c)
  # returns greek, latin, hebrew
  # for	punctuation or whitespace, returns latin
  # To test whether two characters are compatible with each other in terms of script, see compatible_scripts(), which handles punctuation.
  # For speed:
  cd = c.downcase
  if cd=~/[abcdefghijklmnopqrstuvwxyz]/ then return 'latin' end
  if cd=~/[αβγδεζηθικλμνξοπρστυφχψως]/ then return 'greek' end
  if c=~/[אבגדהוזחטילמנסעפצקרשתםןףץ]/ then return 'hebrew' end
  # For accented characters, we'll fall through to here:
  n = char_to_short_name(c)
  if is_name_of_greek_letter(n) then return 'greek' end
  if is_name_of_hebrew_letter(n) then return 'hebrew' end
  # If we fall through to here, then it will be really slow.
  b = char_unicode_property(c,'opt_unicode_block_desc')
  if b=~/(Latin|Greek|Hebrew)/ then return $1.downcase end
  return b
end

def compatible_scripts(c1,c2)
  if !(c1=~/[[:alpha:]]/) || !(c2=~/[[:alpha:]]/) then return true end
  return char_to_code_block(c1)==char_to_code_block(c2)
end

def common_script(c1,c2)
  if !compatible_scripts(c1,c2) then return nil end
  if !(c1=~/[[:alpha:]]/) then return char_to_code_block(c2) end
  return char_to_code_block(c1)
end

def char_to_script_and_case(c)
  # Returns, e.g., ['greek','uppercase'] or ['hebrew',''].
  script = char_to_code_block(c)
  if script=='hebrew' then return [script,''] end
  if c.downcase==c then the_case='lowercase' else the_case='uppercase' end
  return [script,the_case]
end

def select_script_and_case_from_string(s,script,the_case)
  # Script and case should be strings. If script is hebrew, case should be a null string.
  return s.chars.select { |c| char_to_script_and_case(c).eql?([script,the_case]) }.join('')
end

def char_to_name(c)
  # This is extremely slow. Avoid using it.
  # Returns the official unicode name of the character.
  # Although these names are officially case-insensitive, this routine always returns uppercase.
  # Examples of names returned:
  #   LATIN SMALL LETTER A
  #   GREEK SMALL LETTER BETA
  #   HEBREW LETTER ALEF
  # The official name of lambda is spelled LAMDA, so that's what we return.
  return char_unicode_property(c,'name').upcase
end

def matches_case(c,the_case)
  script = char_to_code_block(c)
  if script=='hebrew' then return true end
  if the_case=='both' then return true end
  is_lowercase = (c.downcase==c)
  if is_lowercase && the_case=='lowercase' then return true end
  if !is_lowercase && the_case=='uppercase' then return true end
  return false
end

def char_to_short_name(c)
  # This mapping is meant to be one-to-one. The short name is supposed to be pure ascii, easy to type, and will not contain any spaces,
  # so it's appropriate for a filename.
  # Examples of returned values: a, A, alpha, Alpha, alef
  # Since this is meant to be human-readable, we change the spelling of lamda to lambda.
  # To test this:
  #  ruby -e "require 'json'; load 'lib/string_util.rb'; load 'lib/script.rb'; print char_to_short_name('ϊ')"
  x = char_to_short_name_from_table(c)
  if !(x.nil?) then return x end
  x = char_to_short_name_slow(c)
  warn("Short name #{x} was inferred for #{c}. This will be slow and may give a wrong result. See comments in char_to_short_name_hash() on how to speed this up.")
  if short_name_to_long_name(x)!=char_to_name(c) then warn("The short name #{x} inferred for #{c} expands to #{short_name_to_long_name(x)}, which is not the same as #{char_to_name(c)}") end # Make sure it works reversibly.
  return x
end

def char_to_short_name_slow(c)
  # This is abysmally slow. We use it only once when we generate the hard-coded table used in char_to_short_name_from_table.
  name = char_to_short_name_helper(c)
  return name # Fallback if we can't make the round trip reliably.
end

def char_to_short_name_from_table(c)
  return char_to_short_name_hash()[c]
  end

def short_name_to_char(n)
  return char_to_short_name_hash().invert()[n]
end

def char_to_short_name_hash()
  # The following JSON string is generated by Script.generate_table_for_char_to_short_name().
  # To generate an updated version, edit that routine so that it includes additional characters, then:
  #   ruby -e "require 'json'; load 'lib/string_util.rb'; load 'lib/script.rb'; print Script.generate_table_for_char_to_short_name"
  json = <<-"JSON"
  JSON
  return JSON.parse(json)
end

def char_to_short_name_helper(c)
  # Don't call this directly. Call char_to_short_name() or char_to_short_name_slow().
  long = char_to_name(c).gsub(/LAMDA/,'LAMBDA')
  if long=~/LATIN SMALL LETTER (.)/ then return $1.downcase end
  if long=~/LATIN CAPITAL LETTER (.)/ then return $1.upcase end
  if long=~/GREEK SMALL LETTER (.*)/ then return clean_up_accent_name(lc_underbar($1)) end
  if long=~/GREEK CAPITAL LETTER (.*)/ then return clean_up_accent_name(lc_underbar($1).capitalize) end
  if long=~/HEBREW LETTER (.*)/ then return lc_underbar($1) end
  return lc_underbar(long)
end

def lc_underbar(s)
  return s.downcase.gsub(/ /,'_')
end

def clean_up_accent_name(x)
  # input is, e.g., RHO_with_dasia
  if !(x=~/(.*)_with_(.*)/) then return x end
  bare,y = $1,$2.downcase
  stuff = []
  stuff.push(bare)
  h = accent_long_to_short_hash
  y.split(/_/).each { |a|
    aa = accent_long_to_short_name(a)
    if aa.nil? then aa=a end
    stuff.push(aa)
  }
  return stuff.join("_")
end

def accent_long_to_short_name(x)
  return accent_long_to_short_hash()[x]
end

def accent_short_to_long_name(x)
  return accent_long_to_short_hash().invert()[x]
end

def accent_long_to_short_hash()
  # unicode names use obscure greek names for accents
  return {"psili"=>"smooth","dasia"=>"rough","tonos"=>"acute","oxia"=>"acute","varia"=>"grave","perispomeni"=>"circ","dialytika"=>"diar"}
end

def short_name_to_long_name(name_raw)
  name = name_raw.clone.gsub(/_/,' ')
  if name.length==1 then return char_to_name(name) end # Latin
  if is_name_of_hebrew_letter(name) then return "HEBREW LETTER #{name}".upcase end
  if is_name_of_greek_letter(name) then
    # example: iota diar -> GREEK SMALL LETTER IOTA WITH DIALYTIKA
    accent_long_to_short_hash().invert().keys.each { |short_accent|
      name.gsub!(/#{short_accent}/i) {accent_short_to_long_name(short_accent).upcase}
    }
    nn = name.gsub(/LAMBDA/i,'LAMDA') # accept either lamda or lambda as the spelling, but convert to the spelling used in the standard
    if nn=~/^(\w+) (.*)/ then nn="#{$1} WITH #{$2}" end
    if nn=~/^[a-z]/ then
      return "GREEK SMALL LETTER #{nn.upcase}"
    else
      return "GREEK CAPITAL LETTER #{nn.upcase}"
    end
  end
  return name.upcase
end

def is_name_of_greek_letter(s)
  # Note that it's only anchored at the front, so stuff like iota_grave will work.
  return s=~/^(Alpha|Beta|Gamma|Delta|Epsilon|Zeta|Eta|Theta|Iota|Kappa|Lambda|Mu|Nu|Xi|Omicron|Pi|Rho|Sigma|Tau|Upsilon|Phi|Chi|Psi|Omega)/i
end

def is_name_of_hebrew_letter(s)
  return s=~/^(Alef|Bet|Gimel|Dalet|He|Vav|Zayin|Het|Tet|Yod|Final_Kaf|Kaf|Lamed|Final_Mem|Mem|Final_Nun|Nun|Samekh|Ayin|Final_Pe|Pe|Final_Tsadi|Tsadi|Qof|Resh|Shin|Tav)/i
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

