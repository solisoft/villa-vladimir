# The site's words and facts: config/content/site.yml for what does not
# change with the language, and one file per language for the texts.

class SiteContent
  static LOCALES: Array = [
    "fr",
    "en",
    "es"
  ]
  static DEFAULT_LOCALE: String = "fr"
  static LANGUAGE_NAMES: Hash = {
    "fr": "Français",
    "en": "English",
    "es": "Español"
  }

  # The path segment of a room page, per language.
  static ROOM_SEGMENTS: Hash = {
    "fr": "chambres",
    "en": "rooms",
    "es": "habitaciones"
  }

  static def locale?(locale)
    SiteContent.LOCALES.includes?(locale)
  end

  static def site
    Yaml.parse(File.read("config/content/site.yml"))
  end

  static def texts(locale)
    Yaml.parse(File.read("config/content/#{locale}.yml"))[locale]
  end

  # The best of our languages for an Accept-Language header.
  static def negotiate(accept_language)
    wanted = accept_language.to_s.downcase.split(",").map do |part|
      part.split(";")[0].trim.substring(0, 2)
    end
    wanted.find do |code|
      SiteContent.locale?(code)
    end ?? SiteContent.DEFAULT_LOCALE
  end

  static def home_path(locale)
    "/#{locale}"
  end

  static def room_path(locale, slug)
    "/#{locale}/#{SiteContent.ROOM_SEGMENTS[locale]}/#{slug}"
  end

  # Rooms with their texts in `locale`, in the order of site.yml.
  static def rooms(site, texts)
    site["rooms"].map do |room|
      words = texts["rooms"][room["slug"]]
      room.merge({
        "kind_label": texts["rooms"]["kinds"][words["kind"]],
        "tagline": words["tagline"],
        "text": words["text"],
        "features": words["features"]
      })
    end
  end

  # Fills "{name}" placeholders.
  static def fill(template, values)
    text = template.to_s
    values.keys.each do |key|
      text = text.replace("{#{key}}", values[key].to_s)
    end
    text
  end

  # "30 avril 2027" / "30 April 2027" / "30 abril 2027" for a "YYYYMMDD" date.
  static def long_date(date, texts)
    month_name = texts["months"][date.substring(4, 6).to_i - 1]
    "#{date.substring(6, 8).to_i} #{month_name} #{date.substring(0, 4)}"
  end

  # The alt text of a photo, from its file name.
  static def photo_alt(texts, path)
    stem = path.split("/").last.replace(".jpg", "")
    texts["photos"][stem].to_s
  end

  # Where the page reached by the old site's /<locale>/-/<page> lives now.
  static def legacy_path(locale, page)
    anchors = {
      "la-villa": "#villa",
      "les-chambres-d-hotes": "#chambres",
      "disponibilite-et-tarifs": "#chambres",
      "la-table-d-hotes": "#table",
      "les-environs": "#environs",
      "contact-et-acces": "#acces"
    }
    rooms = {
      "suite-s-aguya": "s-agulla",
      "suite-pinya-de-rosa": "pinya-de-rosa",
      "chambre-cala-bona": "cala-bona",
      "chambre-cala-blanca": "cala-blanca"
    }
    return SiteContent.room_path(locale, rooms[page]) unless rooms[page].nil?

    SiteContent.home_path(locale) + anchors[page].to_s
  end
end
