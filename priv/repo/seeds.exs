# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Carlosassist.Repo.insert!(%Carlosassist.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Carlosassist.Accounts
alias Carlosassist.Rides

# Create test users
rider_attrs = %{
  email: "rider@example.com",
  role: "rider"
}

volunteer_attrs = %{
  email: "volunteer@example.com",
  role: "volunteer",
  volunteer_license_plate: "ABC123",
  volunteer_car: "Red Toyota Camry 2018",
  volunteer_bio:
    "Friendly volunteer driver with 5 years of experience. Safe driver, non-smoker, and happy to help!"
}

admin_attrs = %{
  email: "admin@example.com",
  role: "admin"
}

# Create additional volunteer for demo
volunteer2_attrs = %{
  email: "volunteer2@example.com",
  role: "volunteer",
  volunteer_license_plate: "XYZ789",
  volunteer_car: "Blue Honda Civic 2020",
  volunteer_bio: "College student volunteer. Available evenings and weekends. Very reliable!"
}

# Create the users
{:ok, rider} = Accounts.register_user(rider_attrs)
{:ok, _volunteer} = Accounts.register_user(volunteer_attrs)
{:ok, _volunteer2} = Accounts.register_user(volunteer2_attrs)
{:ok, _admin} = Accounts.register_user(admin_attrs)

# Create some test rides for the rider
rider_scope = Carlosassist.Accounts.Scope.for_user(rider)

ride1_attrs = %{
  pickup_location: "Downtown Library",
  destination: "Airport Terminal 1",
  description: "Need a ride to catch my 2 PM flight. Can help with gas money.",
  # Tomorrow
  ride_date: DateTime.add(DateTime.utc_now(), 86400, :second)
}

ride2_attrs = %{
  pickup_location: "University Campus",
  destination: "Shopping Mall",
  description: "Going shopping after classes. Would appreciate a ride!",
  # Day after tomorrow
  ride_date: DateTime.add(DateTime.utc_now(), 172_800, :second)
}

ride3_attrs = %{
  pickup_location: "Home (123 Main St)",
  destination: "Hospital",
  description: "Medical appointment. Need reliable transportation.",
  # 3 days from now
  ride_date: DateTime.add(DateTime.utc_now(), 259_200, :second)
}

# Create the rides
{:ok, _ride1} = Rides.create_ride(ride1_attrs, rider_scope)
{:ok, _ride2} = Rides.create_ride(ride2_attrs, rider_scope)
{:ok, _ride3} = Rides.create_ride(ride3_attrs, rider_scope)

IO.puts("Seeds created successfully!")
IO.puts("Test users:")
IO.puts("  Rider: rider@example.com")
IO.puts("  Volunteer 1: volunteer@example.com")
IO.puts("  Volunteer 2: volunteer2@example.com")
IO.puts("  Admin: admin@example.com")
IO.puts("  (Login using magic link functionality)")
IO.puts("\nSample rides created for the rider user.")
IO.puts("Volunteers have sample car/license plate info for demo purposes.")
