class Lingo
  def initialize(script_name,language)
    # fixme -- This needs to be cleaned up and generalized. The user should be able to supply their own dictionaries.
    words_dir = dir_and_file_to_path(HomeDir.home,"words")
    @script = Script.new(script_name)
    if script_name=='latin' then
      words,bigrams = ["words_homeric_english","bigrams_homeric_english"]
    end
    if script_name=='greek' then
      words,bigrams = ["words_homeric_greek","bigrams_homeric_greek"]
    end
    words_file = dir_and_file_to_path(words_dir,words+".json")
    bigrams_file = dir_and_file_to_path(words_dir,bigrams+".json")
    @words = json_from_file_or_die(words_file)
    @bigrams = json_from_file_or_die(bigrams_file)
    @threshold = -15
    # ... threshold as a log base 2; frequencies lower than this count as "never;" 2^(-15)=3 x 10^-5
    #     examples: uu=-19 (equus), sv=-18 (sudibusve, an error?), word-initial ct=-16 (Cteatus)
    #     Setting this to -20 is effectively setting it to -infinity for my Homeric corpus.
  end

  attr_reader :words,:bigrams,:script
  attr_accessor :threshold

  # {
  #  "word_initial_no_accents": {
  #    "μη": [
  #      -7,
  #      "Μῆνιν"
  #    ],
  # ...

  def is_word(s)
    return self.words.has_key?(remove_accents(s).downcase)
  end

  def word_log_freq(w)
    ww = remove_accents(w).downcase
    if self.words.has_key?(ww) then return self.words[ww] else return -9999 end
  end

  def bigram_can_be_word_initial?(bigram)
    return retrieve_bigram_boolean('word_initial_no_accents',bigram)
  end

  def bigram_can_exist?(bigram)
    return retrieve_bigram_boolean('no_accents',bigram)
  end

  def bigram_log_freq_word_initial(bigram)
    return retrieve_bigram_log_freq('word_initial_no_accents',bigram)
  end

  def bigram_log_freq(bigram)
    return retrieve_bigram_log_freq('no_accents',bigram)
  end

  def retrieve_bigram_boolean(k,bigram)
    if retrieve_bigram_log_freq(k,bigram)<self.threshold then return false end
    if self.script.has_case then
      # Don't allow stuff like OlymIan, where an uppercase letter pops up in the middle of a word:
      c1,c2 = bigram.chars
      if c1.downcase==c1 and c2.downcase!=c2 then return false end
    end
    return true
  end

  def retrieve_bigram_log_freq(k,bigram)
    b = remove_accents(bigram).downcase
    if self.bigrams[k].has_key?(b) then return self.bigrams[k][b][0] else return -9999 end
  end

end
