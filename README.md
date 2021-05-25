dorcas
======

Dumb Optical Recognition using Correlation

## What I want to do

* Make a system that doesn't depend on a neural network as an unmodifiable, unfixable, and inscrutable black box.
     Instead, use some variant of old-school convolution methods.

* Handle text in a mixture of languages.

* Handle RTL alphabetic scripts.

* Take advantage of SMP.

## Intended limitations

* May be somewhat slow, but still usable on a book-length text if you let it run for a weekend.

* May need to look at a fairly large document in order to get an initial fix on the font.
     May need a certain amount of human involvement at this stage.

* Won't handle CJK, vertical scripts, or handwriting.

* I'm not making much of an effort to make it something that could run on Windows.

## Dependencies:

ruby

chapel

debian packages: parallel r-cran-minpack.lm unicode libgd-perl

## Method of use

A series of passes, each with the possible need for human tweaking.

1. Trial fit: Run the software on an image, which can be small if desired for speed, but should include at least
five or six lines of text. The software tries to find a particular character chosen by the user, say "e."
The user evaluates whether the seed font is a good match; fine-tunes spacing_multiple and fudge_size;
and fiddles with the threshold for matching.

2. Initial matching: Run the software on an image that's big enough to have most of the common letters of the
alphabet.