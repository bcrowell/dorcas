all:
	make homeric
	make bigrams

homeric:
	cat corpora/homer_*.txt | to_words.rb latin en >words_homeric_english.json
	cat corpora/ομηρου_*.txt | to_words.rb greek grc >words_homeric_greek.json

bigrams:
	to_bigrams.rb <words_homeric_english.json >bigrams_homeric_english.json
	to_bigrams.rb <words_homeric_greek.json >bigrams_homeric_greek.json



