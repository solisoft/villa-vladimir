# The one-page site in three languages, and the old site's addresses.

# Stores a fresh copy of every room calendar, so that no request goes to
# Google: each room is free for thirty nights from ten days ahead.
def home_spec_seed_calendars
  CalendarFeed.all.each do |feed|
    feed.delete
  end
  first = Availability.day_number(Availability.today) + 10
  events = range(first, first + 30).map do |day|
    date = Availability.date_of(day)
    "BEGIN:VEVENT\nDTSTART;VALUE=DATE:#{date}\nSUMMARY:150€ Libre Free\nEND:VEVENT"
  end
  prices = "BEGIN:VCALENDAR\n" + events.join("\n") + "\nEND:VCALENDAR"
  now = DateTime.utc.to_unix
  SiteContent.site["rooms"].each do |room|
    CalendarFeed.remember(nil, room["calendar"], prices, now)
    CalendarFeed.remember(nil, room["blocked_calendar"], "BEGIN:VCALENDAR\nEND:VCALENDAR", now)
  end
end

describe("HomeController") do
  before_each() do
    as_guest()
    clear_headers()
    home_spec_seed_calendars()
  end

  test("GET / sends a Spanish browser to /es") do
    set_header("Accept-Language", "es-ES,es;q=0.9")
    result = get("/")
    expect(res_status(result)).to_equal(302)
    expect(res_location(result).ends_with("/es")).to_equal(true)
  end

  test("GET / sends an unknown language to French") do
    set_header("Accept-Language", "de-DE")
    expect(res_location(get("/")).ends_with("/fr")).to_equal(true)
  end

  test("GET /fr renders the French page with the rooms and their prices") do
    result = get("/fr")
    expect(res_status(result)).to_equal(200)
    expect(view_path()).to_equal("home/index.html")
    body = res_body(result)
    assert_contains(body, "au-dessus de la cala Sant Francesc")
    assert_contains(body, "À partir de 150 € la nuit")
    assert_contains(body, "/fr/chambres/pinya-de-rosa")
    assert_contains(body, "hreflang=\"es\"")
    rooms = assigns()["rooms"]
    expect(rooms.length).to_equal(4)
    expect(rooms.map(&:name).join(", ")).to_equal("S'Agulla, Pinya de Rosa, Cala Bona, Cala Blanca")
  end

  test("GET /en and /es render in their language") do
    assert_contains(res_body(get("/en")), "Four rooms facing the Mediterranean")
    assert_contains(res_body(get("/es")), "Cuatro habitaciones frente al Mediterráneo")
    assert_contains(res_body(get("/es")), "/es/habitaciones/cala-blanca")
  end

  test("GET /fr lists the photos with their alt text, and the PDFs") do
    get("/fr")
    page = assigns()
    expect(page["spaces"].length).to_equal(5)
    expect(page["gallery"].all?(&{ |photo|
      photo["alt"].length > 0
    })).to_equal(true)
    expect(page["itineraries"].length).to_equal(3)
    expect(page["terms_href"]).to_equal("/docs/conditions-generales-de-vente.pdf")
  end

  test("GET /de is not a page") do
    expect(res_status(get("/de"))).to_equal(404)
  end

  test("the old site's addresses are moved for good") do
    villa = get("/fr/-/la-villa")
    expect(res_status(villa)).to_equal(301)
    expect(res_location(villa).ends_with("/fr#villa")).to_equal(true)
    room = get("/en/-/chambre-cala-bona")
    expect(res_location(room).ends_with("/en/rooms/cala-bona")).to_equal(true)
    expect(res_status(get("/it/-/la-villa"))).to_equal(404)
  end

  test("GET /health answers ok") do
    result = get("/health")
    expect(res_status(result)).to_equal(200)
    assert_contains(res_body(result), "ok")
  end
end
