# The following assumes we're on a Unix system and can invoke fontconfig's command-line interface by shelling out.
# Fontconfig does exist on windows, but I haven't looked for any way to make this cross-platform.
# See README under Portability.

class Fontconfig
  def Fontconfig.name_to_path(font_name)
    return `fc-match -f "%{file}" "#{font_name}"`
  end

  def Fontconfig.path_to_name(file_path)
    return `fc-query -f "%{family}" #{file_path}`
  end
end
