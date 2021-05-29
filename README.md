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

optional debian packages: imagemagick qpdf

## Method of use

A series of passes, each with the possible need for human tweaking.

1. Trial fit: Run the software on an image, which can be small if desired for speed, but should include at least
five or six lines of text. The software estimates the line spacing, which the user should check; if it's
way off, put in a different value for guess_dpi or guess_font_size.
The software tries to find a particular character chosen by the user, say "e."
The user evaluates whether the seed font is a good match; fine-tunes spacing_multiple and fudge_size;
and fiddles with the threshold for matching.

2. Initial matching: Run the software on an image that's big enough to have most of the common letters of the
alphabet. The software tries to find swatches from the image that match as many as possible of the letters
of the alphabet in the seed font. The user can fiddle with cluster_threshold if desired. They
then delete any swatches that look wrong, and possibly hand edit any glitches or flyspecks.
If the wrong swatches are being matched to the seed font, this can be fixed on the next pass using prefer_cluster.
If matches aren't being found at all, use force_location and/or adjust_size.

3. Iteration: Continue the process. Any letter for which we already have a good-enough swatch is matched
to the swatch, not to the seed font.

### Editing data

To delete a bad pattern, simply remove the .pat file.

To edit a pattern:

1. `unzip -jo a.pat bw.png`

2. Use software such as GIMP to edit bw.png.

3. `zip -r a.pat bw.png`


# Format of input file

The input file is a JSON hash with keys and values described below. Comments are allowed using javascript syntax ("// ...").

* image - Name of a PNG file containing the text that we want to do OCR on. As a convenience feature, if this is
          specified in the form "foo.pdf[37]", then page q37 of the pdf file will be rendered at 500 dpi, converted to grayscale, saved
          in the current working directory as foo_037.png, and used as the input. (This feature requires imagemagick and qpdf.)

* prev - Name of a directory containing output from a previous run. Default: null.

* output - Name of a directory in which to place accumulated results after this run. Default: "output".
            If this directory already exists, it is removed and recreated.

* seed_fonts - An array of arrays, each of which is of the form [font name,script name,(lowercase|uppercase|both)].
          If the font name ends in .ttf, then it's taken to be an absolute path to a truetype font file; otherwise
          it's translated into such a filename using the Unix fontconfig utility fc-match.
          The script name is a string like latin, greek, or hebrew, and defaults to latin.
          The case argument defaults to both.

* characters - An array of arrays, each of which is of the form [script name,(lowercase|uppercase|both),string].
          If the third element is absent, then every character from this string is searched for in the text;
          otherwise the string is taken as a list of characters to search for.
          Default: [["latin","lowercase"]]

* spacing_multiple - Set to 2 if double-spaced. Default: 1. Setting this appropriately helps the software to guess the right scaling for the seed font.

* threshold - The lowest correlation between seed font and image that we consider to be of interest. Defaults to 0.62.

* cluster_threshold -  The lowest correlation between two characters in the image that we take as meaning that they're the same.
            Defaults to 0.85.

* adjust_size - An additional scaling factor to match the seed font to the image. Default: 1.

* guess_dpi - An initial estimate of the resolution in dots per inch. Default: 300.

* guess_font_size - An initial estimate of the font size in points. Default: 12.

* prefer_cluster - An array of arrays, each of which is of the form [character,n].
        The idea here is that on the previous run, we found that a certain character, say ψ, from the seed font was matched with the wrong
        cluster of swatches. We looked at the file matches_psi.svg, which showed the alternative clusters of swatches, and
        we decided that rather than the 1st swatch, what we wanted was the 3rd. Therefore, we add this to our job file:
        `"prefer_cluster":[["ψ",3]]`. Normally you would want to delete the incorrect pattern from the previous pass,
        since this feature is normally used when matching to a seed font.

* force_location - This is similar to prefer_cluster, but for example `"force_location":[["ψ",123,456]]` would
        force the software to match the character close to pixel coordinates (123,456). This is useful when the
        seed font has a particular character that is a very poor match to the image's font. Normally in such a
        case you will need to set the threshold to a very low value as well.

* no_matching - Doing `"no_matching":true` means that the necessary patterns will be created simply be rendering
        the seed font, not by looking for matches to the seed font in an actual image of text. This can be used if
        you simply can't find an example of a certain character in your text. An input image must still be provided
        in order to fix the size of the font.

# Portability

The following is a list of the things that would require work if porting this software to a non-Unix system.

We assume we have a working fontconfig, but if that fails,
then supplying an absolute pathname for the font should still work.
Fontconfig is mainly a Unix thing, but does exist on windows.
My current implementation uses fontconfig by shelling out to the
Unix fontconfig utilities fc-match and fc-query, which won't work on windows.
(See lib/fontconfig.rb.)

We assume we can invoke the Unix command-line utility "unicode" through a shell.
(See lib/string_util.rb.)

For parallel processing, we use gnu parallel. (See lib/correl.rb.)

For graphing, we shell out to the R language, although these functions are
not needed for operation of the software. R is also used for curve fitting.
(See lib/other_interpreters.rb.)

For rendering fonts, we shell out to a perl interpreter and use Perl's GD
library. (See lib/other_interpreters.rb.)

For pdf input, we need imagemagick and qpdf.
