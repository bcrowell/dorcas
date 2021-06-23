#!/bin/ruby
# coding: utf-8

require 'json'
require_relative "../lib/string_util"

# Usage:
#   to_words.rb latin en <foo.txt
# Outputs a JSON string representing hash whose keys are words and whose values are the
# log base 2 of the word's frequency (rounded to the nearest integer).

# coding: utf-8
def main()
  script,language = ARGV[0],ARGV[1]
  if !(script=='greek' || script=='latin') then die("no script specified") end
  if language.nil? then die("no language specified") end
  words = {}
  $stdin.each_line {|line|
    to_words(clean_up_text(line,language)).each { |w|
      wrong_script = false
      w.chars.each { |c| if c=~/[[:alpha:]]/ and char_to_code_block(c)!=script then wrong_script=true end }
      next if wrong_script
      next if reject(w)
      if w==w.upcase then w=w.downcase end # e.g., THE ILIAD, but don't fiddle with Achilles
      if words.has_key?(w) then words[w] +=1 else words[w] = 1 end
    }
  }
  total = 0
  words.each { |w,n|
    total += n
  }
  total = total.to_f
  words.each { |w,n|
    words[w] = (Math::log(n.to_f/total)/Math::log(2.0)).round
    if blacklist().include?(w) then words.delete(w) end
  }
  #print JSON.pretty_generate(alphabetical_sort(words.keys).map { |w| [w,words[w]] })
  print JSON.pretty_generate(words)
end

def blacklist
  return ['gpongia','bk','bks','p','pp','vs','pg','pgs','s','cf','ie','eg','gk','bohn','albai','&c','e','ps','sv']
end

def reject(w)
  if is_roman_numeral(w) then return true end
  return false
end

def is_roman_numeral(w)
  return w=~/^M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$/i # https://stackoverflow.com/a/267405/1142217
end

def clean_up_text(t,language)
  # Greek punctuation:
  #   modern ano teleia, https://en.wikipedia.org/wiki/Interpunct#Greek , U+0387 · GREEK ANO TELEIA
  #   middle dot, · , unicode b7 (may appear in utf-8 as b7c2 or something)
  #   koronis, https://en.wiktionary.org/wiki/%E1%BE%BD
  t = t.clone.unicode_normalize(:nfc)
  if language=='en' then
    # In translations of Homer, we get lots of these characters with accents. I think it's better to strip the accents.
    t.gsub!(/[àáâãäå]/,'a')
    t.gsub!(/[èéêë]/,'e')
    t.gsub!(/[ìíîï]/,'i')
    t.gsub!(/[òóôõö]/,'o')
    t.gsub!(/[ùúûü]/,'u')
    t.gsub!(/[ýÿ]/,'y')
  end
  t.gsub!(/(᾽)(?=\p{Letter})/) {"#{$1} "} # e.g., Iliad has this: ποτ᾽Ἀθήνη , which causes wrong behavior by cltk lemmatizer.
  t.gsub!(/ ᾽/,'᾽ ')                      # μήτε σὺ Πηλείδη ᾽θελ᾽ ἐριζέμεναι βασιλῆϊ
  t.gsub!(/[—-]/,' ')
  t.gsub!(/’/,"'")
  # Eliminate punctuation that can't be part of a word:
  t.gsub!(/[\.\?;,·\!_\(\):=§”“\[\]‘]/,'')
  t.gsub!(/\d/,'') # numbers are footnotes, don't include them
  t.gsub!(/ϑ/,'θ')
  t.gsub!(/ϕ/,'φ')
  t.gsub!(/ϛ/,'ς')
  t.gsub!(/ϒ/,'Υ')
  t.gsub!(/ỏ/,'ὀ')
  t.gsub!(/ῤ/,'ῥ') # seems to be a typo in PG, rho can't be smooth
  return t
end

def to_words(line)
  # This assumes that we've already eliminated punctuation that can't be part of a word.
  return line.split(/\s+/).select { |w| w=~/[[:alpha:]]/}
end

def alphabetical_sort(l)
  # This doesn't quite work, sorts accented letters differently.
  return l.sort {|a,b| strip_accents(a.downcase) <=> strip_accents(b.downcase)}
end

def strip_accents(s)
  # This is slow, but I don't know a better way to do it. Strips stuff like apostrophes as well.
  result = ''
  s.unicode_normalize(:nfd).chars.each { |c|
    if c=~/[[:alpha:]]/ then result = result+c end
  }
  return result
end

def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

main()
