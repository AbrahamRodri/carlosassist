# CarlosAssist

CarlosAssist is a community ride-coordination platform: people who need transportation
(medical appointments, groceries, Mass) post ride requests, and vetted volunteers in
their community offer to drive them. Riders choose their volunteer and coordinate
through built-in chat.

The long-term goal is for a **church/parish to run this as an official ministry tool** —
including letting homebound and elderly members sign up to receive Holy Communion at
home, with Eucharistic ministers signing up to bring it to them. See
[docs/CHURCH_READINESS_CHECKLIST.md](docs/CHURCH_READINESS_CHECKLIST.md) for the full
roadmap and current gaps.

## How It Works

**For Riders:**
1. Create an account and request a ride through a 4-step wizard (pickup, destination, date, review)
2. Volunteers see your request — only location nicknames, never your exact address
3. Browse the volunteers who offered and accept one; your address is revealed only to them
4. Chat directly with your volunteer to coordinate details

**For Volunteers:**
1. Sign up as a volunteer (car + license plate required) and browse open ride requests
2. Send an offer with a short message to the rider
3. Once accepted, the exact addresses unlock and a chat opens with the rider

## Features

- **Authentication** — email/password and magic-link login (Phoenix 1.8 scope-based auth)
- **Role-based dashboards** — separate rider and volunteer interfaces; admin role passes both gates
- **Ride lifecycle** — pending → confirmed → completed/cancelled, with volunteer offer/accept flow
- **Location privacy** — exact addresses hidden behind friendly names until a match is made
- **Real-time chat** — one conversation per ride, PubSub-backed
- **Mapbox integration** — address autocomplete and geocoding
- **Profile management** — phone, volunteer details, photo upload

## Current Status

Deployed to Fly.io (`carlosassist.fly.dev`). All P0 blockers from the
[checklist](docs/CHURCH_READINESS_CHECKLIST.md) are fixed in code (prod mailer via
Brevo, authorization checks, persistent uploads, ride completion/cancellation). Before
the next deploy you must set the mail secrets — the app intentionally refuses to boot
in prod without them:

```bash
fly secrets set BREVO_API_KEY=xkeysib-... MAIL_FROM_ADDRESS=you@example.com
```

(Free Brevo account → verify the sender address under Senders & Domains → create an
API key under SMTP & API.)

## Requirements

- Elixir 1.14+ / Erlang OTP 25+
- SQLite3
- Node.js (asset compilation)

## Setup

1. Clone the repository

2. Create a `.env` file with required environment variables:
   ```bash
   export MAPBOX_PUBLIC_KEY=your_mapbox_public_key
   export MAPBOX_PRIVATE_KEY=your_mapbox_private_key
   ```

3. Source the environment and install dependencies:
   ```bash
   source .env
   mix setup
   ```

4. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

5. Visit [`localhost:4000`](http://localhost:4000)

Seed demo users (rider@example.com / volunteer@example.com, password `password123`) with
`mix run priv/repo/seeds.exs`. **Warning:** seeding deletes all existing users and rides.

## Development Commands

| Command | Description |
|---------|-------------|
| `mix setup` | Install deps, setup database, build assets |
| `mix phx.server` | Start the development server |
| `iex -S mix phx.server` | Start server with interactive shell |
| `mix test` | Run the test suite |
| `mix ecto.reset` | Reset the database |
| `mix assets.build` | Build CSS/JS assets |

In dev, sent emails are viewable at [`/dev/mailbox`](http://localhost:4000/dev/mailbox).

## Project Structure

```
lib/
├── carlosassist/            # Business logic (contexts)
│   ├── accounts.ex          # Users, auth, roles (rider/volunteer/admin)
│   ├── rides.ex             # Ride requests, volunteer offers, matching
│   ├── messages.ex          # Chat (one conversation per ride)
│   └── location_privacy.ex  # Address-hiding rules pre/post match
└── carlosassist_web/        # Web layer
    ├── live/                # LiveViews (dashboards, chat, auth)
    ├── controllers/         # Static pages, session controller
    └── components/          # Core + UI components (map, volunteer, message)
docs/                        # Roadmap & design docs
```

## Deployment (Fly.io)

`fly.toml` targets the `carlosassist` app with a mounted volume for the SQLite database.
Required secrets/env:

- `SECRET_KEY_BASE` — `mix phx.gen.secret`
- `DATABASE_PATH` — SQLite file path on the mounted volume
- `PHX_HOST` — production hostname
- `MAPBOX_PUBLIC_KEY` / `MAPBOX_PRIVATE_KEY`
- Mail adapter credentials — **not yet configured; see checklist P0**

Release commands live in `rel/overlays/bin/`. `server` runs pending migrations on boot
(the SQLite volume is only mounted on app machines, so a Fly `release_command` can't).
`seed` is destructive (wipes users and rides) and refuses to run in a release unless
`ALLOW_DESTRUCTIVE_SEED=true` is set.

## License

Private project.
