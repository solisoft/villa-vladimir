# villa-vladimir

A Soli MVC application.

## Getting Started

### Development Server

Start the development server with hot reload:

```bash
soli serve . --dev
```

Your app will be available at [http://localhost:5011](http://localhost:5011)

### Production Server

Start the production server:

```bash
soli serve . --port 5011
```

Or run as a daemon:

```bash
soli serve . -d
```

## Content and calendars

- Texts live in `config/content/fr.yml`, `en.yml` and `es.yml` (same keys in
  all three — `tests/site_content_spec.sl` checks it). Language-independent
  facts (phones, email, rooms, photo lists) are in `config/content/site.yml`.
- Each room reads Bernard's public Google Calendars: one event per open night
  titled with its price (`160€ Libre Free`), `Non dispo` / `Busy` for a booked
  night. A copy is kept in the `calendar_feeds` collection for an hour, and the
  last copy is shown if Google does not answer (`app/services/availability.sl`).
- Pages: `/fr`, `/en`, `/es`, and one page per room (`/fr/chambres/<slug>`,
  `/en/rooms/<slug>`, `/es/habitaciones/<slug>`). The old site's
  `/<lang>/-/<page>` addresses redirect (301) to their new place.
- Run `bin/verifier` before shipping (fmt, lint, tests at 90 % coverage).

## Project Structure

```
villa-vladimir/
├── app/
│   ├── assets/
│   │   └── css/
│   │       └── application.css  # Source CSS with Tailwind directives
│   ├── controllers/     # Request handlers
│   ├── models/          # Data models
│   └── views/           # HTML templates
│       ├── home/        # Home page views
│       └── layouts/     # Layout templates
├── config/
│   └── routes.sl      # Route definitions
├── db/
│   ├── migrations/      # Database migrations
│   ├── seeds/           # Additional seed files (soli db:seed generate)
│   └── seeds.sl         # Database seeds (soli db:seed)
├── public/              # Static assets (compiled output)
│   ├── css/
│   │   └── application.css  # Compiled CSS (generated)
│   ├── js/
│   └── images/
├── tests/               # Test files
└── soli.toml            # Project manifest
```

## CSS

Tailwind is compiled by `soli` itself — there is no `package.json` and no
`node_modules`. `soli serve . --dev` rebuilds `public/css/application.css`
from `app/assets/css/application.css` on every change, using a standalone
Tailwind binary cached in `~/.soli/bin/`. Tailwind's configuration is
CSS-first (`@theme` in `application.css`), so there is no `tailwind.config.js`
either.

## Database Migrations

Generate a new migration:

```bash
soli db:migrate generate create_users
```

Run pending migrations:

```bash
soli db:migrate up
```

Rollback last migration:

```bash
soli db:migrate down
```

Check migration status:

```bash
soli db:migrate status
```

## Database Seeds

Populate the database with sample or initial data. Edit `db/seeds.sl` (and add ordered
files under `db/seeds/`), then run:

```bash
soli db:seed
```

Seeds are not tracked and re-run every time, so keep them idempotent (guard inserts with
`first_by` / `find_by`). Generate an additional ordered seed file:

```bash
soli db:seed generate demo_users
```

## Documentation

- [Soli MVC Documentation](https://soli.solisoft.net/docs)
- [Soli Language Reference](https://soli.solisoft.net/docs/soli-language)
- [Authorization & Policies](https://soli.solisoft.test/docs/security/authorization)
- [Tailwind CSS](https://tailwindcss.com/docs)

## License

MIT
