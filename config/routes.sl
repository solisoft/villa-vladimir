# Routes configuration

get("/health", "home#health")
get("/", "home#root")

# One page per language, then one page per room. The room segment is
# translated; RoomsController reads the language from the path.
get("/fr/chambres/:slug", "rooms#show")
get("/en/rooms/:slug", "rooms#show")
get("/es/habitaciones/:slug", "rooms#show")

# The old site's addresses (/fr/-/la-villa…), redirected for good.
get("/:locale/-/:page", "home#legacy")

get("/:locale", "home#index")
