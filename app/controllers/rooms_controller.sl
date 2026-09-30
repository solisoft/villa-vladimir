# One guest room: its photos, what it has, and its free nights with prices.

class RoomsController < SiteController
  # GET /fr/chambres/:slug
  # GET /en/rooms/:slug
  # GET /es/habitaciones/:slug — the room page, in the language of its path
  def show(req)
    @_prepare(req.path.split("/")[1])
    matching = @rooms.filter do |room|
      room["slug"] == params["slug"]
    end
    halt(404, "Not found") if matching.length == 0

    @room = matching[0]

    page = @words["room_page"]
    @title = SiteContent.fill(
      page["title"],
      {"kind": @room["kind_label"], "name": @room["name"]}
    )
    @description = @room["tagline"] + ". " + @words["rooms"]["price_includes"]
    @og_image = "/images/chambres/" + @room["photos"][0]
    slug = @room["slug"]
    @alternates = @_alternates(fn(code) { SiteContent.room_path(code, slug) })
    @other_rooms = @rooms.filter do |room|
      room["slug"] != slug
    end.map do |room|
      room.merge({
        "path": SiteContent.room_path(@locale, room["slug"]),
        "photo": "/images/chambres/" + room["photos"][0]
      })
    end
    photo_files = @room["photos"]
    @photos = range(0, photo_files.length).map do |index|
      alt = SiteContent.fill(
        page["photo_alt"],
        {
          "name": @room["name"],
          "number": index + 1
        }
      )
      {
        "src": "/images/chambres/" + photo_files[index],
        "alt": alt
      }
    end
    @_load_availability(page)
  end

  private

  def _load_availability(page)
    nights = @_nights(@room)
    @calendar_reachable = !nights.nil?
    table = nights ?? {}
    @months = Availability.months(table, @today).map do |month|
      month.merge({"label": "#{this.words["months"][month["month"] - 1]} #{month["year"]}"})
    end
    price_span = Availability.price_range(table, @today)
    @price_range = price_span.nil? ? nil : SiteContent.fill(page["price_range"], price_span)
    first_free = Availability.next_free(table, @today)
    @next_free = first_free.nil? ? nil : SiteContent.fill(page["next_free"], {"date": SiteContent.long_date(
      first_free,
      @words
    )})
    subject = SiteContent.fill(page["mail_subject"], {"name": @room["name"]})
    @mail_href = "mailto:#{this.site["email"]}?subject=#{url_encode(subject)}"
  end
end
