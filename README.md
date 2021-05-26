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

debian packages: parallel r-cran-minpack.lm unicode libgd-perl ruby-zip

## Method of use

A series of passes, each with the possible need for human tweaking.

1. Trial fit: Run the software on an image, which can be small if desired for speed, but should include at least
five or six lines of text. The software tries to find a particular character chosen by the user, say "e."
The user evaluates whether the seed font is a good match; fine-tunes spacing_multiple and fudge_size;
and fiddles with the threshold for matching.

2. Initial matching: Run the software on an image that's big enough to have most of the common letters of the
alphabet. The software tries to find swatches from the image that match as many as possible of the letters
of the alphabet in the seed font. The user can fiddle with cluster_threshold if desired. They
then delete any swatches that look wrong, and possibly hand edit any glitches or flyspecks.

3. Iteration: Continue the process. Any letter for which we already have a good-enough swatch is matched
to the swatch, not to the seed font.

### Editing data

To delete a bad pattern, simply remove the .pat file.

To edit a pattern:

1. `unzip -jo a.pat bw.png`

2. Use software such as GIMP to edit bw.png.

3. `zip -r a.pat bw.png`


# Format of input file

The input file is a JSON hash with the following keys.

* image - Name of a PNG file containing the text that we want to do OCR on.

* seed_fonts - An array of arrays, each of which is of the form [font name,script name,(lowercase|uppercase|both)].
          If the font name ends in .ttf, then it's taken to be an absolute path to a truetype font file; otherwise
          it's translated into such a filename using the Unix fontconfig utility fc-match.
          The script name is a string like latin, greek, or hebrew, and defaults to latin.
          The case argument defaults to both.

* spacing_multiple - Set to 2 if double-spaced. Default: 1. Setting this appropriately helps the software to guess the right scaling for the seed font.

* threshold - The lowest correlation between seed font and image that we consider to be of interest. Defaults to something reasonable.

* cluster_threshold -  The lowest correlation between two characters in the image that we take as meaning that they're the same.
            Defaults to something reasonable.

* adjust_size - An additional scaling factor to match the seed font to the image. Default: 1.

# Portability

The following is a list of the things that would require work if porting this software to a non-Unix system.

We assume we can run the Unix fontconfig utilities fc-match and fc-query through a shell, but if that fails,
then supplying an absolute pathname for the font should still work. (See class Font in the source code.)

We assume we can invoke the Unix command-line utility "unicode" through a shell.
(See lib/string_util.rb.)

