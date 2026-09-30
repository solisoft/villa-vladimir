# SiteContent: the three languages say the same things, and the helpers
# around them.

# The dotted paths of every key of a nested hash (arrays count as leaves).
def site_content_spec_paths(value, prefix)
  return [prefix] unless value.is_a?("hash")

  paths = []
  value.keys.each do |key|
    paths = paths + site_content_spec_paths(value[key], prefix + "." + key)
  end
  paths
end

describe("SiteContent") do
  test("English and Spanish have every key of French, and no other") do
    french = site_content_spec_paths(SiteContent.texts("fr"), "").sort()
    expect(site_content_spec_paths(SiteContent.texts("en"), "").sort()).to_equal(french)
    expect(site_content_spec_paths(SiteContent.texts("es"), "").sort()).to_equal(french)
  end

  test("lists run the same length in every language") do
    french = SiteContent.texts("fr")
    other_locales = ["en", "es"]
    other_locales.each do |locale|
      other = SiteContent.texts(locale)
      expect(other["hero"]["facts"].length).to_equal(french["hero"]["facts"].length)
      expect(other["table"]["dishes"].length).to_equal(french["table"]["dishes"].length)
      expect(other["access"]["transit"].length).to_equal(french["access"]["transit"].length)
      expect(other["months"].length).to_equal(12)
      expect(other["weekdays"].length).to_equal(7)
    end
  end

  test("every room of site.yml has its texts, and every photo its alt text") do
    site = SiteContent.site
    SiteContent.LOCALES.each do |locale|
      texts = SiteContent.texts(locale)
      rooms = SiteContent.rooms(site, texts)
      expect(rooms.length).to_equal(4)
      rooms.each do |room|
        expect(room["kind_label"].blank?).to_equal(false)
        expect(room["features"].length > 3).to_equal(true)
      end
      photos = site["spaces"].map do |space|
        space["photo"]
      end
      photos = photos + site["villa_gallery"] + site["table_photos"] + site["surroundings_photos"]
      photos.push(site["access_photo"])
      photos.each do |path|
        expect(SiteContent.photo_alt(texts, path).blank?).to_equal(false)
      end
    end
  end

  test("knows its languages") do
    expect(SiteContent.locale?("es")).to_equal(true)
    expect(SiteContent.locale?("de")).to_equal(false)
  end

  test("picks the first language of the browser we have, else French") do
    expect(SiteContent.negotiate("es-ES,es;q=0.9,en;q=0.8")).to_equal("es")
    expect(SiteContent.negotiate("de-DE,en-GB;q=0.8")).to_equal("en")
    expect(SiteContent.negotiate("de-DE")).to_equal("fr")
    expect(SiteContent.negotiate(nil)).to_equal("fr")
  end

  test("builds page paths per language") do
    expect(SiteContent.home_path("en")).to_equal("/en")
    expect(SiteContent.room_path("fr", "cala-bona")).to_equal("/fr/chambres/cala-bona")
    expect(SiteContent.room_path("es", "cala-bona")).to_equal("/es/habitaciones/cala-bona")
  end

  test("sends the old site's pages to their new place") do
    expect(SiteContent.legacy_path("fr", "la-villa")).to_equal("/fr#villa")
    expect(SiteContent.legacy_path("en", "contact-et-acces")).to_equal("/en#acces")
    expect(SiteContent.legacy_path("es", "suite-s-aguya")).to_equal("/es/habitaciones/s-agulla")
    expect(SiteContent.legacy_path("fr", "accueil")).to_equal("/fr")
  end

  test("fills placeholders and writes long dates") do
    expect(SiteContent.fill(
      "De {min} à {max} €",
      {"min": 140, "max": 180}
    )).to_equal("De 140 à 180 €")
    expect(SiteContent.long_date("20270430", SiteContent.texts("fr"))).to_equal("30 avril 2027")
    expect(SiteContent.long_date("20270501", SiteContent.texts("en"))).to_equal("1 May 2027")
  end

  test("has no alt text for an unknown photo") do
    expect(SiteContent.photo_alt(SiteContent.texts("fr"), "villa/inconnue.jpg")).to_equal("")
  end
end
