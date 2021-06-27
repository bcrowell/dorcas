dorcas
======

Dorcas is an OCR system that can handle text in a mixture of languages. My original
use case was a 19th century book containing Greek words mixed together with English.
On this book, I was not able to get usable results with Tesseract, the most widely
used open-source OCR system. Compared to Tesseract, Dorcas uses a completely different
approach that is fundamentally better suited to this type of problem. In fancy
terminology, it uses template matching and convolution rather than neural networks.
What this means is that you have to put some effort into training it on a specific
font, but once you've done that, it can interpret that font in contexts where Tesseract
fails.

## What the system is designed to do

* Handle text in any mixture of languages.

* Not depend on a neural network as an unmodifiable, unfixable, and inscrutable black box.
     Instead, use old-school methods such as convolution and template matching.

* Handle RTL alphabetic scripts such as Hebrew, and bidirectional texts.

* Take advantage of symmetrical multiprocessing.

## Intended limitations

* May be somewhat slow, but still usable on a book-length text if you let it run for a weekend.

* May need to look at a fairly large document in order to get an initial fix on the font.
     May need considerable human involvement at this stage. Will probably never be a turn-key system like Tesseract.

* Won't handle CJK, vertical scripts, or handwriting.

* It runs on Linux. I've made an effort to make it fairly portable, but actually porting it to Windows would require some effort, and
    is not something I would work on myself.

# General description of how the software works

Broadly speaking, there are two stages to the process, a training part and then the actual processing of text that you want to OCR.
During the training part, you build up a set of templates, one for each letter of the alphabet(s), that are based on the actual
document. A limitation this software is that it must be trained on the same font that wll be used on the actual document. Currently,
this even has to be the same size and resolution. For example, if you're trying to OCR

## Usage

`dorcas foo.job` ... reads parameters from a json file

`dorcas -` ... reads from stdin

`dorcas extract help`

`dorcas insert help`

`dorcas clean` ... removes any scratch files left behind in /tmp and ~/.dorcas

`dorcas view foo.set reports` ... write a visual report on the pattern set foo.set to report/foo.svg; also works with a set in directory form

## Dependencies:

debian packages: ruby python3 r-cran-minpack.lm unicode libgd-perl ruby-zip python3-numpy python3-pil

optional debian packages: imagemagick qpdf

## Method of use

A series of passes, each with the possible need for human tweaking.

1. Trial fit: Run the software on an image, which can be small if desired for speed, but should include at least
five or six lines of text. The software estimates the line spacing, which the user should check; if it's
way off, put in a different value for guess_dpi or guess_font_size.
The software tries to find a particular character chosen by the user, say "e."
The user evaluates whether the seed font is a good match; fine-tunes spacing_multiple and adjust_size;
and fiddles with the threshold for matching.

2. Initial matching: Run the software on an image that's big enough to have most of the common letters of the
alphabet. The software tries to find swatches from the image that match as many as possible of the letters
of the alphabet in the seed font. The user can fiddle with cluster_threshold if desired. They
then delete any swatches that look wrong, and possibly hand edit any glitches or flyspecks.
If the wrong swatches are being matched to the seed font, this can be fixed on the next pass using prefer_cluster.
If matches aren't being found at all, use force_location and/or adjust_size.

3. Iteration: Continue the process. Any letter for which we already have a good-enough swatch is matched
to the swatch, not to the seed font. Once the patterns are in good shape, it works better to use a high
value for the threshold (~0.6) and a lower value for the cluster_threshold (~0.7).

### Editing .set files

These can exist either as directories or as files with the .set extension, which are zip files. They
contain one .pat file for each character, plus a file  _data.json that looks like this: 
`{"size":12,"dpi":300}`. The size is in points, and dpi is the resolution.

Linux systems have a GUI utility called file-roller for working with zip files.

To delete a bad pattern from a .set file: `zip -d foo.set alpha.pat`

To pack a directory up into a .set file: `zip -q -r -j foo.set foo/*.pat foo/_data.json`

To unpack a .set file into a directory: `unzip -q -d foo foo.set`

To see the contents of a set: `zipinfo foo.set`

# Editing a single character from a .set file:

Utilities for making this easier:

dorcas extract old.set ρ bw.png

... edit bw.png

dorcas insert old.set ρ bw.png new.set

For a reminder of usage on these utilities, do "dorcas insert help", etc.

### Editing pattern templates

Each letter of the alphabet(s) is represented by a template created as a composite from sample swatches
taken from page scans. That template can be stored on disk either as a single file or as a directory containing
several files. In the former case, the single file is just a container in the zip format.

To delete a bad pattern, simply remove the .pat file or directory.

If the .pat file is inside a .set file, use dorcas extract and dorcas insert (see above).

If the .pat file is not inside a .set file:

1. `unzip -jo a.pat bw.png` (unzips the file into the current working directory)

2. Use software such as GIMP to edit bw.png.

3. `jar -uf a.pat bw.png` (jar is packaged as part of openjdk)


# Format of input file

The input file is a JSON hash with keys and values described below. Comments are allowed using javascript syntax ("// ...").

* verb - To do the initial learning of the set of character shapes for a certain font, use "seed" or "learn." The former generates
          patterns from a seed font and generates a set of templates for the first time. The latter takes the preexisting set and
          uses it to search a scanned text, creating new versions of the templates from that text.  To use an existing set
          to OCR text, use "ocr."
          Even when using the seed verb, an input image must still be provided in order to fix the size of the font.

* image - Name of a PNG file containing the text that we want to do OCR on. As a convenience feature, if this is
          specified in the form "foo.pdf[37]", then page q37 of the pdf file will be rendered at 500 dpi, converted to grayscale, saved
          in the current working directory as foo_037.png, and used as the input. (This feature requires imagemagick and qpdf.)

* set - Name of a directory or .set file containing output from a previous run. When running with the seed verb, this
          parameter is optional. If it is supplied, then preexisting templates are copied over at the start. Default: null.

* output - Name of a directory in which to place accumulated results after this run. Default: "output".
            If this directory already exists, it is removed and recreated.

* seed_fonts - An array of arrays, each of which is of the form [font name,script name,(lowercase|uppercase|both)].
          If the font name ends in .ttf, then it's taken to be an absolute path to a truetype font file; otherwise
          it's translated into such a filename using the Unix fontconfig utility fc-match.
          The script name is a string like latin, greek, or hebrew, and defaults to latin.
          The case argument defaults to both.

* characters - An array of arrays, each of which is of the form [script name,(lowercase|uppercase|both),string].
          If the third element is present, it is taken as a list of characters to search for.
          If the list is not specified and the verb is ocr, then
          we search for every letter of the alphabet that is in this script and case and is included in the given .set file.
          If the list is not specified and the verb is seed, then we do the entire alphabet.
          In the case of Greek, a short list of
          accented characters is automatically included as well, but most such characters need to be specified by hand in a separate run.
          Default: [["latin","lowercase"]]

* spacing_multiple - Set to 2 if double-spaced. Default: 1. Setting this appropriately helps the software to guess the right scaling for the seed font.

* threshold - The worst match between seed font or pattern and the image that we consider to be of interest. Defaults to 0.5.
         Reasonable values range from 0.0 (very sloppy, many false positives) to 1.0 (very stringent, many false negatives).

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
        case you will need to set the threshold to a very low value as well. The need to do these things may
        actually indicate a problem with a red mask that is not close enough to the character, i.e., the kerning
        in the real document is tighter than estimated by the software.

# Temporary files and cache

Results of expensive calculations are stored in ~/.dorcas/cache. 

Scratch files are stored in /tmp with names following the pattern /tmp/dorcas*. They should be deleted automatically,
unless the program dies with an error. 

All of these files can be deleted by doing a `dorcas clean`.

If you OCR a page from scratch, there are two stages. In the first stage, the program scans the page for all the
letters of the alphabet and writes a .spa ("spatter") file containing a list of every possible detection of a letter,
including those that have low scores indicating they aren't very good matches. In the second stage, it reads the
.spa file and tries to string everything together. If you rerun the job without changing any of the parameters that
would have affected the spatter file, then the program will just read the .spa file back in and avoid the time-consuming
step of scanning the original page image.

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

For graphing, we shell out to the R language, although these functions are
not needed for operation of the software. R is also used for curve fitting.
(See lib/other_interpreters.rb.)

For rendering fonts, we shell out to a perl interpreter and use Perl's GD
library. (See lib/other_interpreters.rb.)

For pdf input, we need imagemagick and qpdf.

In convolve.py, we open the output file to append, and we write lines of under ~4k characters.
On linux, this should work when there are multiple processes. On windows, opening probably
locks the file.

In temp_file_name() and verb_clean(), we assume temporary files can be created with the filename pattern /tmp/dorcas*.

