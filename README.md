# CarlosAssist

CarlosAssist is a community-driven ride coordination platform built to help people who need transportation connect with volunteers willing to give them a ride. Whether it's getting to medical appointments, grocery stores, or other essential destinations, CarlosAssist makes it easy to request and offer rides.

## How It Works

**For Riders:**
1. Create an account and request a ride by entering your pickup and destination addresses
2. Volunteers in your area can see your request and offer to help
3. Choose from available volunteers and confirm your ride
4. Chat directly with your volunteer to coordinate pickup details
5. Track your ride status from pending to completed

**For Volunteers:**
1. Sign up as a volunteer and browse available ride requests in your area
2. Submit a request to help a rider who needs transportation
3. Once the rider accepts, use the built-in chat to coordinate details
4. Complete the ride and help someone in your community

## Features

- **User Authentication** - Email/password and magic link login
- **Role-Based Dashboards** - Separate interfaces for riders and volunteers
- **Ride Management** - Request rides, accept volunteer requests, track ride status
- **Real-Time Chat** - LiveView-powered messaging between riders and volunteers
- **Location Services** - Mapbox integration for addresses and mapping
- **Profile Management** - User profiles with photo uploads

## Requirements

- Elixir 1.14+
- Erlang/OTP 25+
- SQLite3
- Node.js (for asset compilation)

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

5. Visit [`localhost:4000`](http://localhost:4000) in your browser

## Development Commands

| Command | Description |
|---------|-------------|
| `mix setup` | Install deps, setup database, build assets |
| `mix phx.server` | Start the development server |
| `iex -S mix phx.server` | Start server with interactive shell |
| `mix test` | Run the test suite |
| `mix ecto.reset` | Reset the database |
| `mix assets.build` | Build CSS/JS assets |

## Project Structure

```
lib/
├── carlosassist/           # Business logic (contexts)
│   ├── accounts.ex         # User management
│   ├── rides.ex            # Ride requests & matching
│   └── messages.ex         # Chat system
└── carlosassist_web/       # Web layer
    ├── live/               # LiveView modules
    ├── controllers/        # HTTP controllers
    └── components/         # Reusable UI components
```

## Production Deployment

For production, set these environment variables:
- `SECRET_KEY_BASE` - Phoenix secret key
- `DATABASE_PATH` - Path to SQLite database file
- `PHX_HOST` - Production hostname
- `MAPBOX_PUBLIC_KEY` - Mapbox API public key
- `MAPBOX_PRIVATE_KEY` - Mapbox API private key

See [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html) for more details.

## License

Private project.
