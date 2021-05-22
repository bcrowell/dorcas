# coding: utf-8
class Script
  def initialize(s)
    # s can either be a name ('latin','greek','hebrew') or a sample character in that script ('w','θ',...)
    if s=='latin' or s=='greek' or s=='hebrew' then
      @name = s
    else
      @name = char_to_code_block(s) # returns greek, latin, or hebrew
    end
  end

  attr_reader :name

  def to_s()
    return "Script: #{self.name}"
  end

  def full_height_string()
    if self.name=='latin'  then return 'hp' end
    if self.name=='greek'  then return 'ζγμ' end
    if self.name=='hebrew' then return 'לץ' end
    return '1,' # likely to be rendered in any font
  end

  def guard_rail_chars(side)
    # To find out how much white "personal space" the character has around it, we render various other "guard-rail" characters
    # to the right and left of it. The logical "or" of these is space that we know can be occupied by other characters. I visualize
    # this as red.
    # side=0 means guard-rail chars will be on the right of our character, 1 means left
    # Many fonts that contain one script don't contain coverage of other scripts. Rendering libraries may leave a blank or sub in some other font, but
    # this produces goofy results, such as unpredictable variations in line height. So use guard-rail characters
    # that are from the same script. This was an issue for GFSPorson, which lacks Latin characters.
    guard = nil
    if self.name=='latin' then
      if side==0 then guard = "AT1!H.,;:'{_=|~?/" else guard="!]':?HTiXo" end
    end
    if self.name=='greek' then
      # Don't add characters to the following that may not be covered in a Greek font. In particular, GFSPorson lacks Latin characters.
      if side==0 then guard = "ΠΩΔΥΗ.,'" else guard="ΠΩΔΥΗ'" end
    end
    if self.name=='hebrew' then
      # Don't add characters to the following that may not be covered in a Hebrew font.
      if side==0 then guard = "ח.,'" else guard="ר''" end
    end
    if guard.nil? then
      # provide some kind of fall-back
      if side==0 then guard = "1.,'" else guard="1''" end
    end
    return guard
  end

end

