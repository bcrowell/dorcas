def char_to_code_block(c)
  # returns greek, latin, hebrew
  # for	punctuation or whitespace, returns latin
  b = char_unicode_property(c,'opt_unicode_block_desc')
  if b=~/(Latin|Greek|Hebrew)/ then return $1.downcase end
  return b
end

def char_unicode_property(c,property)
  # https://en.wikipedia.org/wiki/Unicode_character_property
  # Shells out to the linux command-line utility called	"unicode," which is installed as the debian packaged of	the same name.
  # list of properties: https://github.com/garabik/unicode/blob/master/README
  #   useful ones include opt_unicode_block_desc, category, name
  if c=='"' then c='\\"' end
  result	= `unicode --string "#{c}" --format "{#{property}}"`
  if $?!=0 then	die($?) end
  return result
end

def escape_double_quotes(s)
  return s.gsub(/"/,'\\"') # escape double quotes
end

