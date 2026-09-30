# Nightly availability and prices of a room, read from Bernard's public
# Google Calendars.
#
# He keeps one all-day event per open night, titled with its price
# ("160€ Libre Free"). A night titled "Non dispo", "Busy" or "Not available"
# is taken. Any other event (the long "Apertura Ouverture 30/04/2027" that
# covers the winter) says nothing about a single night and is ignored: a
# night with no priced event is closed.
#
# Dates travel as "YYYYMMDD" strings, the calendar's own format, and day
# arithmetic goes through a day number (days since 1970-01-01) so that no
# timezone ever shifts a night.

class Availability
  static TTL_SECONDS: Int = 3600
  static FEED_URL: String = "https://calendar.google.com/calendar/ical/{id}%40group.calendar.google.com/public/"
  + "basic.ics"

  # -> [{"start": "20270525", "end": "20270526", "summary": "140€ Libre Free"}]
  static def parse_events(ics_text)
    events = []
    current = nil
    unfolded = ics_text.to_s.replace("\r\n", "\n").replace("\n ", "")
    unfolded.split("\n").each do |line|
      if line == "BEGIN:VEVENT"
        current = {}
      elsif line == "END:VEVENT"
        events.push(current) unless current.nil? || current["start"].nil?
        current = nil
      elsif !current.nil? && line.contains(":")
        Availability._read_property(current, line)
      end
    end
    events
  end

  static def _read_property(event, line)
    parts = line.split(":")
    name = parts[0].split(";")[0]
    value = parts.slice(1, parts.length).join(":").trim
    event["start"] = value.substring(0, 8) if name == "DTSTART"
    event["end"] = value.substring(0, 8) if name == "DTEND"
    event["summary"] = value if name == "SUMMARY"
    event
  end

  # "free" with its price, "taken", or nil for an event that is not about
  # single nights.
  static def classify(summary)
    text = summary.to_s.downcase
    return {"state": "taken"} if [
      "non dispo",
      "not available",
      "busy",
      "complet",
      "reserv"
    ].any?(&{ |word|
      text.contains(word)
    })
    return nil unless text.contains("€") || text.contains("libre") || text.contains("free")

    digits = Regex.find("[0-9]+", text)
    {"state": "free", "price": digits.nil? ? nil : digits["match"].to_i}
  end

  # Merges the price calendar and the blocked calendar into one night table:
  # {"20270525": {"state": "free", "price": 140}, "20270526": {"state": "taken"}}.
  # A taken night wins over a price set on the same night.
  static def nights(events)
    table = {}
    events.each do |event|
      night = Availability.classify(event["summary"])
      next if night.nil?

      first = Availability.day_number(event["start"])
      last = event["end"].nil? ? first + 1 : Availability.day_number(event["end"])
      last = first + 1 if last <= first
      range(first, last).each do |day|
        date = Availability.date_of(day)
        known = table[date]
        table[date] = night if known.nil? || known["state"] != "taken"
      end
    end
    table
  end

  # Days since 1970-01-01 of a "YYYYMMDD" date (H. Hinnant's days_from_civil).
  static def day_number(date)
    year = date.substring(0, 4).to_i
    month = date.substring(4, 6).to_i
    day = date.substring(6, 8).to_i
    year = year - 1 if month <= 2
    era = year / 400
    year_of_era = year - era * 400
    shifted_month = month > 2 ? month - 3 : month + 9
    day_of_year = (153 * shifted_month + 2) / 5 + day - 1
    day_of_era = year_of_era * 365 + year_of_era / 4 - year_of_era / 100 + day_of_year
    era * 146097 + day_of_era - 719468
  end

  # The "YYYYMMDD" date of a day number (civil_from_days).
  static def date_of(day)
    shifted = day + 719468
    era = shifted / 146097
    day_of_era = shifted - era * 146097
    year_of_era = (day_of_era - day_of_era / 1460 + day_of_era / 36524 - day_of_era / 146096) / 365
    day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100)
    shifted_month = (5 * day_of_year + 2) / 153
    day_of_month = day_of_year - (153 * shifted_month + 2) / 5 + 1
    month = shifted_month < 10 ? shifted_month + 3 : shifted_month - 9
    year = year_of_era + era * 400
    year = year + 1 if month <= 2
    year.to_s + month.to_s.rjust(2, "0") + day_of_month.to_s.rjust(2, "0")
  end

  # 0 for Monday … 6 for Sunday (1970-01-01 was a Thursday).
  static def weekday(day)
    shifted = day + 3
    shifted % 7
  end

  # Month grids from the month of the first free night to the last month
  # holding a night, at most `limit` of them: a stray booked night in winter
  # does not open six empty months. Each week is seven cells, Monday
  # first; padding cells are nil, others are
  # {"day": 25, "state": "free"|"taken"|"closed"|"past", "price": 140}.
  static def months(table, today, limit: Int = 12)
    first_free = Availability.next_free(table, today)
    return [] if first_free.nil?

    year = first_free.substring(0, 4).to_i
    month = first_free.substring(4, 6).to_i
    last_month = table.keys.sort().last.substring(0, 6)
    grids = []
    while grids.length < limit
      key = year.to_s + month.to_s.rjust(2, "0")
      break if key > last_month

      grids.push(Availability.month_grid(table, today, year, month))
      month = month + 1
      if month > 12
        month = 1
        year = year + 1
      end
    end
    grids
  end

  static def month_grid(table, today, year, month)
    prefix = year.to_s + month.to_s.rjust(2, "0")
    first_day = Availability.day_number(prefix + "01")
    next_prefix = month == 12 ? (year + 1).to_s + "01" : year.to_s + (month + 1).to_s.rjust(2, "0")
    length = Availability.day_number(next_prefix + "01") - first_day
    cells = range(0, Availability.weekday(first_day)).map do |i|
      nil
    end
    range(0, length).each do |offset|
      date = Availability.date_of(first_day + offset)
      cells.push(Availability.cell(table, today, date, offset + 1))
    end
    while cells.length % 7 != 0
      cells.push(nil)
    end
    weeks = range(0, cells.length / 7).map do |week|
      cells.slice(week * 7, week * 7 + 7)
    end
    {
      "year": year,
      "month": month,
      "weeks": weeks
    }
  end

  static def cell(table, today, date, day)
    if date < today
      return {
        "day": day,
        "state": "past",
        "price": nil
      }
    end

    night = table[date]
    if night.nil?
      return {
        "day": day,
        "state": "closed",
        "price": nil
      }
    end

    {
      "day": day,
      "state": night["state"],
      "price": night["price"]
    }
  end

  # -> {"min": 140, "max": 180} over the free nights from `today`, or nil.
  static def price_range(table, today)
    prices = Availability.free_dates(table, today).map do |date|
      table[date]["price"]
    end.filter do |price|
      !price.nil?
    end
    return nil if prices.length == 0

    {"min": prices.min(), "max": prices.max()}
  end

  # The first free night from `today`, or nil.
  static def next_free(table, today)
    dates = Availability.free_dates(table, today)
    dates.length > 0 ? dates[0] : nil
  end

  static def free_dates(table, today)
    table.keys.filter do |date|
      date >= today && table[date]["state"] == "free"
    end.sort()
  end

  # Today in Spain, as "YYYYMMDD". Madrid is UTC+1 or +2; two hours ahead
  # is right all summer, when it matters, and at worst one hour early in
  # winter, when the villa is closed.
  static def today
    DateTime.utc.add_hours(2).format("%Y%m%d")
  end

  # The night table of a room, merged from its two calendars, or nil when
  # no copy of the price calendar could be read at all.
  static def for_room(room)
    prices = Availability.feed(room["calendar"])
    return nil if prices.nil?

    blocked = Availability.feed(room["blocked_calendar"]).to_s
    Availability.nights(Availability.parse_events(prices) + Availability.parse_events(blocked))
  end

  # The calendar's ICS text: the stored copy while it is fresh, otherwise a
  # new download, falling back on the stale copy when Google does not answer.
  static def feed(calendar_id)
    return nil if calendar_id.blank?

    stored = CalendarFeed.find_by("calendar_id", calendar_id)
    now = DateTime.utc.to_unix
    return stored.body if !stored.nil? && now - stored.fetched_at < Availability.TTL_SECONDS

    body = Availability.download(calendar_id)
    return stored&.body if body.nil?

    CalendarFeed.remember(stored, calendar_id, body, now)
    body
  end

  # The public ICS of a calendar, or nil on any failure.
  static def download(calendar_id)
    url = Availability.FEED_URL.replace("{id}", calendar_id)
    answer = HTTP.request("GET", url, {"timeout": 5}) rescue nil
    Availability.ics_body(answer)
  end

  static def ics_body(answer)
    return nil if answer.nil? || answer["status"] != 200

    body = answer["body"].to_s
    body.starts_with("BEGIN:VCALENDAR") ? body : nil
  end
end
