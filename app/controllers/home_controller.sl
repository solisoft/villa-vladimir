# The villa's one-page site, in French, English and Spanish.

class HomeController < SiteController
  # GET / — sends the visitor to the language their browser asks for
  def root(req)
    redirect(SiteContent.home_path(SiteContent.negotiate(req["headers"]["accept-language"])))
  end

  # GET /:locale — the villa, the rooms, dining, surroundings, getting here
  def index(req)
    @_prepare(params["locale"])
    @title = @words["meta"]["title"]
    @alternates = @_alternates(fn(code) { SiteContent.home_path(code) })
    @rooms = @rooms.map do |room|
      prices = Availability.price_range(@_nights(room) ?? {}, @today)
      from_price = prices.nil? ? nil : SiteContent.fill(@words["rooms"]["from_price"], {"price": prices["min"]})
      room.merge({
        "from_price": from_price,
        "path": SiteContent.room_path(@locale, room["slug"]),
        "photo": @_photo("chambres/" + room["photos"][0])
      })
    end
    @_load_photos
  end

  # GET /:locale/-/:page — an address of the old site, moved for good
  def legacy(req)
    locale = params["locale"]
    halt(404, "Not found") unless SiteContent.locale?(locale)

    {
      "status": 301,
      "headers": {"Location": SiteContent.legacy_path(locale, params["page"])},
      "body": ""
    }
  end

  # GET /health
  def health
    {
      "status": 200,
      "headers": {"Content-Type": "application/json"},
      "body": "{\"status\":\"ok\"}"
    }
  end

  private

  def _load_photos
    @hero_photo = @_photo("villa/piscine-debordante.jpg")
    @hero_photo["alt"] = @words["hero"]["photo_alt"]
    @spaces = @site["spaces"].map do |space|
      words = @words["villa"]["spaces"][space["key"]]
      @_photo(space["photo"]).merge({
        "name": words["name"],
        "text": words["text"]
      })
    end
    @gallery = @site["villa_gallery"].map do |path|
      @_photo(path)
    end
    @table_photos = @site["table_photos"].map do |path|
      @_photo(path)
    end
    @surroundings_photos = @site["surroundings_photos"].map do |path|
      @_photo(path)
    end
    @access_photo = @_photo(@site["access_photo"])
    @itineraries = @site["itineraries"].map do |itinerary|
      {
        "label": @words["access"]["itineraries"][itinerary["key"]],
        "href": "/" + itinerary["file"]
      }
    end
    @terms_href = "/" + @site["terms_file"]
  end
end
