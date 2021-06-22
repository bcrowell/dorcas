#!/bin/ruby
# coding: utf-8

require 'json'
require_relative "../lib/string_util"

# Usage:
#   bigrams.rb <foo.json >foo_bigrams.json
# Inputs a JSON data structure in the format output by to_words.rb.
# Outputs a list of bigrams in a similar format.

# coding: utf-8
def main()
  words = JSON.parse($stdin.gets(nil))
  result = {}
  words.each { |w,log_freq|
    if w=~/^([[:alpha:]])([[:alpha:]])/ then
      a,b = remove_accents($1),remove_accents($2)
      bigram = a+b
      k = 'word_initial_no_accents'
      if !(result.has_key?(k)) then result[k]={} end
      if result[k].has_key?(bigram) then result[k][bigram][0]+=1 else result[k][bigram]=[1,w] end # each item is stored as [count,witness]
    end
  }
  print JSON.pretty_generate(result)
end

def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

main()
