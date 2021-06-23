class Lingo
  def initialize(script,language)
    # fixme -- This needs to be cleaned up and generalized. The user should be able to supply their own dictionaries.
    words_dir = dir_and_file_to_path(HomeDir.home,"words")
    if script=='latin' then
      words,bigrams = ["words_homeric_english","bigrams_homeric_english"]
    end
    if script=='greek' then
      words,bigrams = ["words_homeric_greek","bigrams_homeric_greek"]
    end
    words_file = dir_and_file_to_path(words_dir,words+".json")
    bigrams_file = dir_and_file_to_path(words_dir,bigrams+".json")
    @words = json_from_file_or_die(words_file)
    @bigrams = json_from_file_or_die(bigrams_file)
  end

  # {
  #  "word_initial_no_accents": {
  #    "μη": [
  #      -7,
  #      "Μῆνιν"
  #    ],
  # ...

  def bigram_can_be_word_initial?(bigram)
    return self.bigrams['word_initial_no_accents'].has_key?(remove_accents(bigram).downcase)
  end

  attr_reader :words,:bigrams
end
