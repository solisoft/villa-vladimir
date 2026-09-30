# The last ICS text read from one of Bernard's Google Calendars
# (see Availability.feed).
class CalendarFeed < Model
  validates("calendar_id", {"presence": true})

  # Stores a fresh download over the previous copy, or as the first one.
  static def remember(stored, calendar_id, body, fetched_at)
    feed = stored ?? CalendarFeed.new({"calendar_id": calendar_id})
    feed.body = body
    feed.fetched_at = fetched_at
    feed.save
    feed
  end
end
