# What every page shares: the layout, the language and the words of the
# site. No actions of its own.

class SiteController < Controller
  static {
    this.layout = "application"
  }

  private

  # Callers check the locale first and `return halt(...)`: on Soli 2.9.1,
  # which production runs, halt answers but does not stop the action.
  def _prepare(locale)
    @locale = locale
    @site = SiteContent.site
    @words = SiteContent.texts(locale)
    @rooms = SiteContent.rooms(@site, @words)
    @home_path = SiteContent.home_path(locale)
    @today = Availability.today
    @description = @words["meta"]["description"]
    @og_image = "/images/villa/piscine-debordante.jpg"
  end

  # The same page in each language, for the language switcher.
  def _alternates(path_for)
    SiteContent.LOCALES.map do |code|
      {
        "locale": code,
        "name": SiteContent.LANGUAGE_NAMES[code],
        "path": path_for(code),
        "current": code == @locale
      }
    end
  end

  # {"src", "alt"} of a photo under public/images/.
  def _photo(path)
    {
      "src": "/images/" + path,
      "alt": SiteContent.photo_alt(@words, path)
    }
  end

  # The night table of a room, or nil when its calendar cannot be read.
  def _nights(room)
    Availability.for_room(room) rescue nil
  end
end
