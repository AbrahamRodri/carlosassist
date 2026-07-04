# max_cases: 1 — SQLite allows a single writer; concurrent async test cases
# fail with "Database busy". The suite is small, so serial runs stay fast.
ExUnit.start(max_cases: 1)
Ecto.Adapters.SQL.Sandbox.mode(Carlosassist.Repo, :manual)
