# Migration: create_calendar_feeds
# Created: 2026-09-30 18:39:57
#
# The last copy read of each room calendar, so that a page does not wait on
# Google more than once an hour and still shows prices when Google is down.

def up(db)
  db.create_collection("calendar_feeds")
  db.create_index("calendar_feeds", "idx_calendar_id", ["calendar_id"], {"unique": true})
end

def down(db)
  db.drop_index("calendar_feeds", "idx_calendar_id")
  db.drop_collection("calendar_feeds")
end
