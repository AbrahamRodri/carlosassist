# Church Readiness Checklist

Everything CarlosAssist needs before a parish can rely on it day-to-day. Ordered by
priority: P0 items block *anyone* from using the deployed app, P1 items block a church
from adopting it, P2 is the Eucharist home-visit ministry extension, P3 is hardening.

Last audited: 2026-07-04 (full codebase review).

---

## P0 — Broken in production today (fix before anything else)

**Status: all P0 code fixes landed 2026-07-04.** One manual step remains before the
next deploy: create a free Brevo account, verify a sender address, and set the two
Fly secrets (see the mailer item below) — the app now refuses to boot in prod
without them, by design.

- [x] **Configure a real mail adapter for prod.** Done — Swoosh's Brevo adapter (free
  tier: 300 emails/day, single verified sender, no custom domain needed) is configured
  in `config/runtime.exs`. Prod boot now requires `BREVO_API_KEY` and
  `MAIL_FROM_ADDRESS` (fail-loud instead of silently not sending). Manual step:
  sign up at brevo.com → verify your sender email under Senders & Domains → create an
  API key under SMTP & API → `fly secrets set BREVO_API_KEY=... MAIL_FROM_ADDRESS=...`.
- [x] **Replace the placeholder sender.** Done — sender name/address come from the
  `:mail_from` config (`MAIL_FROM_NAME`/`MAIL_FROM_ADDRESS` env in prod).
- [x] **Close the admin self-registration hole.** Done — user-facing changesets only
  accept `rider`/`volunteer`; admin is granted via console only (documented in
  `User` moduledoc). Regression test added.
- [x] **Add ownership checks to rider dashboard actions.** Done — `delete_ride/2`,
  `accept_volunteer_request/3`, `reject_volunteer_request/2`, `complete_ride/2`, and
  `cancel_ride/2` all verify the caller owns the ride (and that the request belongs to
  that ride). Covered by `test/carlosassist/rides_test.exs`.
- [x] **Make profile-picture uploads survive deploys.** Done — uploads write to the
  runtime-configured `:uploads_dir` (`/mnt/name/uploads` on the Fly volume, set in
  `fly.toml`) and are served by `UploadsController` with filename sanitization. The old
  code wrote to a relative `priv/static` path that wasn't even served in releases.
- [x] **Guard the prod seed script.** Done — `seeds.exs` raises inside a release unless
  `ALLOW_DESTRUCTIVE_SEED=true`.
- [x] **Wire up ride completion.** Done — rider marks confirmed rides completed from the
  dashboard card or details modal; the conversation closes.
- [x] **Add a cancellation flow.** Done — riders cancel pending/confirmed rides
  (outstanding volunteer offers are rejected, the conversation closes, the ride stays as
  history). Delete is now only offered for pending rides. Note: the volunteer isn't
  actively notified yet — that's the P1 notifications work.
- [x] **(Found during fixes) Case-insensitive emails.** SQLite has no `citext`, so
  `Bob@x.com` and `bob@x.com` were two different accounts and login was case-sensitive.
  Fixed with a `COLLATE NOCASE` unique index migration plus downcasing at the changeset
  and lookup level.

## P1 — Needed before a parish can adopt it

### Notifications (the single biggest adoption gap)
- [ ] Email (and ideally SMS via Twilio) notifications for: new volunteer offer on your
  ride, offer accepted, new chat message, ride reminder day-of, ride cancelled.
  Dashboards also don't live-update (PubSub was removed from them; only chat is
  real-time), so today nobody finds anything out unless they manually refresh.
- [ ] Restore PubSub broadcasts on ride/request changes so open dashboards update live.

### Parish / organization model
- [ ] `Organization` (parish) schema; users belong to a parish; requests scoped to the
  parish community. Without this, one deployment = one implicit community and no church
  has its own space.
- [ ] Coordinator role per parish (distinct from global admin) — church staff who manage
  members and requests.

### Admin & coordinator tooling
- [ ] Admin dashboard (routes exist for `require_admin` but zero admin pages): list/search
  users, deactivate accounts, see all requests, resolve stuck states, basic metrics.
- [ ] Volunteer vetting workflow: volunteers are unusable-by-default until a coordinator
  approves them. Churches require this — Catholic dioceses typically mandate safe-
  environment training (e.g. VIRTUS) and background checks before volunteers serve
  vulnerable adults. Track approval status + expiry date on the volunteer.
- [ ] Manual assignment: coordinator can attach a volunteer to a request directly
  (elderly members will phone the parish office; staff act on their behalf).

### Elderly-first UX
- [ ] Coordinator-created accounts / caregiver-assisted signup — many homebound elderly
  have no email, and magic-link login assumes email fluency. Consider phone-number OTP
  login or long-lived sessions for this population.
- [ ] Accessibility pass: larger default type, high contrast, big touch targets, minimal
  steps. Test the 4-step ride wizard with real seniors — it may need a "call the office
  instead" escape hatch prominently displayed.
- [ ] Spanish localization (gettext is already wired; add `es` translations) — many
  parishes are bilingual.
- [ ] Recurring rides (e.g. Mass every Sunday, dialysis every Tue/Thu) — one-off requests
  only today.

### Trust, safety & liability
- [ ] Terms of service, privacy policy, and a volunteer-driver liability waiver — a
  parish's insurance/diocese will ask before endorsing the platform.
- [ ] Report/block a user; audit log of who saw whose address (the location-privacy
  module hides addresses pre-match but nothing logs access).
- [ ] Emergency contact field on rider profiles.

## P2 — Eucharist home-visit ministry (planned feature)

Let a parish use the platform as the official way for homebound/elderly members to sign
up to **receive Holy Communion at home**, and for **Eucharistic ministers (Extraordinary
Ministers of Holy Communion, EMHCs)** to sign up to bring it to them.

- [ ] **Generalize the request model.** Either add `type` to rides
  (`ride | communion_visit`) or introduce a `visits` table alongside rides sharing the
  location/privacy machinery. A visit has no destination — only the home address.
- [ ] **Homebound signup flow.** Elderly member (or caregiver / parish staff on their
  behalf) requests Communion visits with a recurring schedule (e.g. every Sunday,
  first Friday), preferred time window, and pastoral notes.
- [ ] **EMHC volunteer type.** Ministers must be commissioned by the parish —
  coordinator approval is mandatory before they can see or claim visits (builds on the
  P1 vetting workflow).
- [ ] **Assignment.** Both modes: coordinator assigns ministers to communicants
  (typical parish practice), and an open "visits board" where approved ministers claim
  unassigned visits (mirrors today's volunteer ride board).
- [ ] **Route view for ministers.** A minister serving several homes after Sunday Mass
  sees their assigned visits as an ordered list/map for the day; exact addresses reveal
  only after assignment (reuse `LocationPrivacy`).
- [ ] **Visit lifecycle + log.** requested → scheduled → completed / missed, with a
  visit history the coordinator can review (parishes track who was visited and when).
- [ ] **Pastoral details on the profile.** Low-gluten host required, wants to receive
  Confession or Anointing of the Sick (flags a priest, not an EMHC), mobility/entry
  instructions ("side door, ring twice"), caregiver contact. Treat as sensitive data —
  visible only to coordinator + assigned minister.
- [ ] **Reminders.** Notify minister and communicant the day before; notify coordinator
  when a visit is missed so nobody silently drops off the list.

## P3 — Production hardening

- [ ] SQLite backups: Litestream (or Fly volume snapshots + tested restore). One volume,
  no replication = one bad disk loses the parish's data.
- [ ] Error tracking (Sentry/AppSignal/Honeybadger) + uptime monitoring.
- [ ] Rate-limit login, magic-link requests, and registration.
- [ ] CI: GitHub Actions running `mix format --check-formatted`, `mix test`, Credo.
  The suite is green as of 2026-07-04 (126 tests; runs serially — SQLite is
  single-writer, see `test/test_helper.exs`).
- [ ] Tests for `Messages`, `LocationPrivacy`, and dashboard LiveViews — the `Rides`
  context (ownership/lifecycle) is covered now; the rest still isn't.
- [ ] `LocationPrivacy.get_general_area_name/2` returns hardcoded `"Austin Area"` —
  implement reverse geocoding or drop the label.
- [ ] Enforce privacy filtering in the context layer (`list_pending_rides_for_volunteers`
  returns full addresses; only the template omits them today).
- [ ] Remove duplicate `{:bcrypt_elixir, "~> 3.0"}` line in `mix.exs`.
- [ ] Untrack the committed dev database (`git rm --cached carlosassist_dev.db*`) —
  `.gitignore` now covers `*.db`, but the already-tracked files stay in git history
  until removed.
- [ ] `fly.toml`: rename the `name` volume/database path to something meaningful;
  consider `min_machines_running = 1` once real users depend on it (avoids cold starts
  and LiveView disconnects on scale-to-zero).
- [ ] Decide on custom domain + branding for the church-facing deployment.
