default: chpl/correl
	./dorc.rb

chpl/correl: chpl/correl.chpl
	chpl -o chpl/correl chpl/correl.chpl
