# Availability: reading Bernard's calendars into nights, month grids and prices.

def availability_spec_ics(events)
  lines = ["BEGIN:VCALENDAR", "VERSION:2.0"]
  events.each do |event|
    lines = lines + [
      "BEGIN:VEVENT",
      "DTSTART;VALUE=DATE:" + event[0],
      "DTEND;VALUE=DATE:" + event[1],
      "SUMMARY:" + event[2],
      "END:VEVENT"
    ]
  end
  lines.push("END:VCALENDAR")
  lines.join("\r\n")
end

describe("Availability") do
  describe("parse_events") do
    test("reads dates and titles, with CRLF and folded lines") do
      text = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20270525\r\nDTEND;VALUE=DATE:20270526\r\n"
      + "SUMMARY:140€ Libre\r\n  Free\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
      events = Availability.parse_events(text)
      expect(events.length).to_equal(1)
      expect(events[0]["start"]).to_equal("20270525")
      expect(events[0]["end"]).to_equal("20270526")
      expect(events[0]["summary"]).to_equal("140€ Libre Free")
    end

    test("keeps a colon inside a title and skips events without a start") do
      text = "BEGIN:VEVENT\nSUMMARY:Ouverture: 30/04\nEND:VEVENT\n"
      + "BEGIN:VEVENT\nDTSTART:20270601T100000Z\nSUMMARY:a:b\nEND:VEVENT\n"
      events = Availability.parse_events(text)
      expect(events.length).to_equal(1)
      expect(events[0]["start"]).to_equal("20270601")
      expect(events[0]["summary"]).to_equal("a:b")
    end

    test("reads nothing from an empty text") do
      expect(Availability.parse_events(nil).length).to_equal(0)
    end
  end

  describe("classify") do
    test("a priced night is free, with its price") do
      night = Availability.classify("160€ Libre Free")
      expect(night["state"]).to_equal("free")
      expect(night["price"]).to_equal(160)
    end

    test("a free night without price has none") do
      expect(Availability.classify("Libre")["price"]).to_equal(nil)
    end

    test("booked titles are taken") do
      expect(Availability.classify("Non dispo Not available")["state"]).to_equal("taken")
      expect(Availability.classify("Busy")["state"]).to_equal("taken")
    end

    test("other titles say nothing about a night") do
      expect(Availability.classify("Apertura Ouverture 30/04/2027")).to_equal(nil)
    end
  end

  describe("dates") do
    test("counts days from 1970-01-01 and back") do
      expect(Availability.day_number("19700101")).to_equal(0)
      expect(Availability.date_of(Availability.day_number("20270525"))).to_equal("20270525")
      expect(Availability.date_of(Availability.day_number("20240228") + 1)).to_equal("20240229")
      expect(Availability.date_of(Availability.day_number("20261231") + 1)).to_equal("20270101")
      expect(Availability.date_of(Availability.day_number("20270228") + 1)).to_equal("20270301")
    end

    test("weekday is 0 on Monday") do
      expect(Availability.weekday(Availability.day_number("20260928"))).to_equal(0)
      expect(Availability.weekday(Availability.day_number("20261004"))).to_equal(6)
    end

    test("today is a YYYYMMDD date") do
      expect(Availability.today.length).to_equal(8)
    end
  end

  describe("nights") do
    test("spreads a long event over each night and lets a booking win") do
      events = Availability.parse_events(availability_spec_ics([
        ["20270601", "20270604", "140€ Libre Free"],
        ["20270602", "20270603", "Non dispo"],
        ["20270603", "20270603", "Busy"],
        ["20270101", "20270401", "Apertura Ouverture 30/04/2027"]
      ]))
      table = Availability.nights(events)
      expect(table.keys.sort()).to_equal([
        "20270601",
        "20270602",
        "20270603"
      ])
      expect(table["20270601"]["price"]).to_equal(140)
      expect(table["20270602"]["state"]).to_equal("taken")
      expect(table["20270603"]["state"]).to_equal("taken")
    end

    test("a booking read first is not overwritten by a price") do
      events = [
        {
          "start": "20270601",
          "end": "20270602",
          "summary": "Non dispo"
        },
        {"start": "20270601", "summary": "150€ Libre"}
      ]
      expect(Availability.nights(events)["20270601"]["state"]).to_equal("taken")
    end
  end

  describe("months, prices and the next free night") do
    test("starts at the month of the first free night, Monday first") do
      table = {
        "20261003": {"state": "taken"},
        "20270430": {"state": "free", "price": 160},
        "20270502": {"state": "taken"},
        "20270601": {"state": "free", "price": 180}
      }
      grids = Availability.months(table, "20260930")
      expect(grids.map(&{ |grid|
        grid["month"]
      })).to_equal([4, 5, 6])
      april = grids[0]
      expect(april["year"]).to_equal(2027)
      first_week = april["weeks"][0]
      expect(first_week.length).to_equal(7)
      expect(first_week[2]).to_equal(nil)
      expect(first_week[3]["day"]).to_equal(1)
      expect(first_week[3]["state"]).to_equal("closed")
      last_week = april["weeks"].last
      expect(last_week[4]["day"]).to_equal(30)
      expect(last_week[4]["price"]).to_equal(160)
      expect(last_week[6]).to_equal(nil)
      expect(grids[1]["weeks"][0][6]["state"]).to_equal("taken")
    end

    test("marks nights before today as past") do
      table = {"20270601": {"state": "free", "price": 150}, "20270610": {
        "state": "free",
        "price": 150
      }}
      june = Availability.months(table, "20270605")[0]
      expect(june["weeks"][0][1]["state"]).to_equal("past")
    end

    test("stops at the limit and crosses the year") do
      table = {"20271201": {"state": "free", "price": 100}, "20280301": {
        "state": "free",
        "price": 100
      }}
      expect(Availability.months(table, "20271101").length).to_equal(4)
      expect(Availability.months(table, "20271101", limit: 2).length).to_equal(2)
      expect(Availability.months(table, "20271101")[1]["year"]).to_equal(2028)
    end

    test("has nothing to show without a free night") do
      expect(Availability.months({"20270601": {"state": "taken"}}, "20260930").length).to_equal(0)
      expect(Availability.price_range({}, "20260930")).to_equal(nil)
      expect(Availability.next_free({}, "20260930")).to_equal(nil)
    end

    test("gives the price range and next free night from today") do
      table = {
        "20260901": {"state": "free", "price": 90},
        "20270510": {"state": "free", "price": 140},
        "20270512": {"state": "free", "price": 180},
        "20270513": {"state": "free", "price": nil},
        "20270511": {"state": "taken"}
      }
      range_found = Availability.price_range(table, "20260930")
      expect(range_found["min"]).to_equal(140)
      expect(range_found["max"]).to_equal(180)
      expect(Availability.next_free(table, "20260930")).to_equal("20270510")
    end
  end

  describe("reading the calendars") do
    before_each() do
      CalendarFeed.all.each do |feed|
        feed.delete
      end
    end

    test("accepts only a 200 answer carrying a calendar") do
      expect(Availability.ics_body({
        "status": 200,
        "body": "BEGIN:VCALENDAR\nEND:VCALENDAR"
      }).length > 0).to_equal(true)
      expect(Availability.ics_body({
        "status": 404,
        "body": "BEGIN:VCALENDAR"
      })).to_equal(nil)
      expect(Availability.ics_body({
        "status": 200,
        "body": "<html>"
      })).to_equal(nil)
      expect(Availability.ics_body(nil)).to_equal(nil)
    end

    test("uses a fresh stored copy without downloading") do
      CalendarFeed.remember(nil, "spec-fresh", "BEGIN:VCALENDAR stored", DateTime.utc.to_unix)
      download = Mock.stub_class(Availability, "download", "BEGIN:VCALENDAR new")
      expect(Availability.feed("spec-fresh")).to_equal("BEGIN:VCALENDAR stored")
      download.assert_not_received("download")
    end

    test("downloads over a stale copy and stores the new one") do
      CalendarFeed.remember(nil, "spec-stale", "BEGIN:VCALENDAR old", 0)
      Mock.stub_class(Availability, "download", "BEGIN:VCALENDAR new")
      expect(Availability.feed("spec-stale")).to_equal("BEGIN:VCALENDAR new")
      expect(CalendarFeed.find_by("calendar_id", "spec-stale").body).to_equal("BEGIN:VCALENDAR new")
    end

    test("falls back on the stale copy when Google does not answer") do
      CalendarFeed.remember(nil, "spec-down", "BEGIN:VCALENDAR old", 0)
      Mock.stub_class(Availability, "download", nil)
      expect(Availability.feed("spec-down")).to_equal("BEGIN:VCALENDAR old")
      expect(Availability.feed("spec-never-read")).to_equal(nil)
      expect(Availability.feed("")).to_equal(nil)
    end

    test("merges a room's price and blocked calendars") do
      now = DateTime.utc.to_unix
      prices = availability_spec_ics([[
        "20270601",
        "20270603",
        "150€ Libre Free"
      ]])
      blocked = availability_spec_ics([[
        "20270602",
        "20270603",
        "Non dispo"
      ]])
      CalendarFeed.remember(nil, "spec-prices", prices, now)
      CalendarFeed.remember(nil, "spec-blocked", blocked, now)
      table = Availability.for_room({
        "calendar": "spec-prices",
        "blocked_calendar": "spec-blocked"
      })
      expect(table["20270601"]["state"]).to_equal("free")
      expect(table["20270602"]["state"]).to_equal("taken")
    end

    test("has no table when the price calendar was never read") do
      Mock.stub_class(Availability, "download", nil)
      expect(Availability.for_room({
        "calendar": "spec-missing",
        "blocked_calendar": ""
      })).to_equal(nil)
    end
  end
end
