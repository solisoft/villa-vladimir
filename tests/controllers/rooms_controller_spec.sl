# A room page: photos, features, and the calendar of free nights.

# Every room free for thirty nights from ten days ahead, the eleventh
# booked, all stored fresh so that no request goes to Google.
def rooms_spec_seed_calendars
  CalendarFeed.all.each do |feed|
    feed.delete
  end
  first = Availability.day_number(Availability.today) + 10
  events = range(first, first + 30).map do |day|
    date = Availability.date_of(day)
    "BEGIN:VEVENT\nDTSTART;VALUE=DATE:#{date}\nSUMMARY:170€ Libre Free\nEND:VEVENT"
  end
  prices = "BEGIN:VCALENDAR\n" + events.join("\n") + "\nEND:VCALENDAR"
  booked_day = Availability.date_of(first + 1)
  blocked = "BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART;VALUE=DATE:#{booked_day}\nSUMMARY:Non dispo\n"
  + "END:VEVENT\nEND:VCALENDAR"
  now = DateTime.utc.to_unix
  SiteContent.site["rooms"].each do |room|
    CalendarFeed.remember(nil, room["calendar"], prices, now)
    CalendarFeed.remember(nil, room["blocked_calendar"], blocked, now)
  end
end

describe("RoomsController") do
  before_each() do
    as_guest()
    rooms_spec_seed_calendars()
  end

  test("GET /fr/chambres/:slug shows the room, its prices and its calendar") do
    result = get("/fr/chambres/cala-bona")
    expect(res_status(result)).to_equal(200)
    expect(view_path()).to_equal("rooms/show.html")
    body = res_body(result)
    assert_contains(body, "Cala Bona")
    assert_contains(body, "Terrasse partagée avec Cala Blanca")
    assert_contains(body, "De 170 à 170 € la nuit")
    assert_contains(body, "night-free")
    assert_contains(body, "night-taken")
    assert_contains(body, "mailto:villa-vladimir@outlook.com?subject=")
    page = assigns()
    expect(page["calendar_reachable"]).to_equal(true)
    expect(page["months"].length > 0).to_equal(true)
    expect(page["next_free"].starts_with("Prochaine nuit libre")).to_equal(true)
    expect(page["other_rooms"].length).to_equal(3)
    expect(page["photos"].length).to_equal(4)
    expect(page["see_photos"]).to_equal("Voir les 4 photos")
    assert_contains(body, "data-slideshow-index=\"3\"")
    assert_contains(body, "<dialog id=\"slideshow\"")
  end

  test("GET /en/rooms/:slug and /es/habitaciones/:slug speak their language") do
    assert_contains(res_body(get("/en/rooms/s-agulla")), "Availability and prices")
    assert_contains(res_body(get("/es/habitaciones/cala-blanca")), "Disponibilidad y precios")
    expect(assigns()["alternates"].map(&:path)).to_equal([
      "/fr/chambres/cala-blanca",
      "/en/rooms/cala-blanca",
      "/es/habitaciones/cala-blanca"
    ])
  end

  test("an unknown room is not a page") do
    expect(res_status(get("/fr/chambres/suite-royale"))).to_equal(404)
  end
end
