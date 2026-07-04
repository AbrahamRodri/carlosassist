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

alias Carlosassist.{Accounts, Rides, Repo}

# DESTRUCTIVE demo seed: wipes all users and rides, then creates test accounts with
# known passwords. RELEASE_NAME is only set inside a release (i.e. prod), so the
# guard below blocks accidental `bin/seed` runs against real data.
if System.get_env("RELEASE_NAME") && System.get_env("ALLOW_DESTRUCTIVE_SEED") != "true" do
  raise """
  Refusing to run the destructive demo seed inside a release: it deletes ALL
  users and rides. If you really mean to reset this environment, run it with
  ALLOW_DESTRUCTIVE_SEED=true.
  """
end

Repo.delete_all(Rides.Ride)
Repo.delete_all(Accounts.User)

# Create simple test users
{:ok, simple_rider} =
  Accounts.register_user(%{
    email: "rider@example.com",
    phone: "5155550100",
    role: "rider",
    password: "password123",
    password_confirmation: "password123"
  })

{:ok, simple_volunteer} =
  Accounts.register_user(%{
    email: "volunteer@example.com",
    phone: "5155550101",
    role: "volunteer",
    volunteer_car: "2022 Honda Accord",
    volunteer_license_plate: "HELP123",
    volunteer_bio: "Happy to help with rides around town!",
    password: "password123",
    password_confirmation: "password123"
  })

# Create test users
{:ok, rider1} =
  Accounts.register_user(%{
    email: "sarah@example.com",
    phone: "5155550123",
    role: "rider",
    password: "password123",
    password_confirmation: "password123"
  })

{:ok, rider2} =
  Accounts.register_user(%{
    email: "michael@example.com",
    phone: "5155550124",
    role: "rider",
    password: "password123",
    password_confirmation: "password123"
  })

{:ok, volunteer1} =
  Accounts.register_user(%{
    email: "emily@example.com",
    phone: "5155550125",
    role: "volunteer",
    volunteer_car: "2020 Toyota Camry",
    volunteer_license_plate: "ABC123",
    volunteer_bio:
      "Friendly volunteer with 5 years of experience helping seniors with transportation.",
    password: "password123",
    password_confirmation: "password123"
  })

{:ok, volunteer2} =
  Accounts.register_user(%{
    email: "david@example.com",
    phone: "5155550126",
    role: "volunteer",
    volunteer_car: "2021 Honda Civic",
    volunteer_license_plate: "XYZ789",
    volunteer_bio: "Reliable driver, happy to help with medical appointments and grocery runs.",
    password: "password123",
    password_confirmation: "password123"
  })

# Create sample rides with location privacy fields
{:ok, ride1} =
  Rides.create_ride(
    %{
      pickup_name: "Home",
      pickup_address: "123 Main St, Austin, TX 78701",
      pickup_lat: Decimal.new("30.2672"),
      pickup_long: Decimal.new("-97.7431"),
      destination_name: "Doctor's Office",
      destination_address: "456 Medical Dr, Austin, TX 78705",
      destination_lat: Decimal.new("30.2849"),
      destination_long: Decimal.new("-97.7341"),
      description:
        "Need a ride to my weekly doctor's appointment. I have mobility issues and would appreciate help getting to the door.",
      ride_date: DateTime.add(DateTime.utc_now(), 2, :day),
      status: "pending"
    },
    %{user: rider1}
  )

{:ok, ride2} =
  Rides.create_ride(
    %{
      pickup_name: "Senior Center",
      pickup_address: "789 Community Way, Austin, TX 78704",
      pickup_lat: Decimal.new("30.2500"),
      pickup_long: Decimal.new("-97.7500"),
      destination_name: "Grocery Store",
      destination_address: "321 Shopping Blvd, Austin, TX 78704",
      destination_lat: Decimal.new("30.2400"),
      destination_long: Decimal.new("-97.7450"),
      description:
        "Weekly grocery shopping trip. I usually take about 45 minutes inside the store.",
      ride_date: DateTime.add(DateTime.utc_now(), 1, :day),
      status: "pending"
    },
    %{user: rider2}
  )

{:ok, ride3} =
  Rides.create_ride(
    %{
      pickup_name: "Apartment",
      pickup_address: "555 Oak Ave, Austin, TX 78702",
      pickup_lat: Decimal.new("30.2800"),
      pickup_long: Decimal.new("-97.7200"),
      destination_name: "Pharmacy",
      destination_address: "777 Health St, Austin, TX 78703",
      destination_lat: Decimal.new("30.2750"),
      destination_long: Decimal.new("-97.7150"),
      description:
        "Need to pick up prescription medication. Quick stop, should only take 10 minutes.",
      ride_date: DateTime.add(DateTime.utc_now(), 3, :day),
      status: "confirmed",
      volunteer_id: volunteer1.id
    },
    %{user: rider1}
  )

{:ok, ride4} =
  Rides.create_ride(
    %{
      pickup_name: "My House",
      pickup_address: "999 Elm Street, Austin, TX 78701",
      pickup_lat: Decimal.new("30.2700"),
      pickup_long: Decimal.new("-97.7400"),
      destination_name: "Hospital",
      destination_address: "1000 Hospital Drive, Austin, TX 78705",
      destination_lat: Decimal.new("30.2900"),
      destination_long: Decimal.new("-97.7300"),
      description: "Urgent medical appointment. Need to be there by 2 PM.",
      ride_date: DateTime.add(DateTime.utc_now(), 4, :hour),
      status: "pending"
    },
    %{user: rider2}
  )

{:ok, ride5} =
  Rides.create_ride(
    %{
      pickup_name: "Work",
      pickup_address: "200 Business Park Dr, Austin, TX 78759",
      pickup_lat: Decimal.new("30.4000"),
      pickup_long: Decimal.new("-97.7000"),
      destination_name: "Airport",
      destination_address: "3600 Presidential Blvd, Austin, TX 78719",
      destination_lat: Decimal.new("30.1975"),
      destination_long: Decimal.new("-97.6664"),
      description: "Need a ride to the airport for my flight. I have one small suitcase.",
      ride_date: DateTime.add(DateTime.utc_now(), 5, :day),
      status: "completed",
      volunteer_id: volunteer2.id
    },
    %{user: rider1}
  )

# Create a simple test ride for basic accounts
{:ok, simple_ride} =
  Rides.create_ride(
    %{
      pickup_name: "Home",
      pickup_address: "100 Main Street, Austin, TX 78701",
      pickup_lat: Decimal.new("30.2650"),
      pickup_long: Decimal.new("-97.7450"),
      destination_name: "Store",
      destination_address: "200 Commerce St, Austin, TX 78701",
      destination_lat: Decimal.new("30.2680"),
      destination_long: Decimal.new("-97.7420"),
      description: "Quick trip to the store for groceries.",
      ride_date: DateTime.add(DateTime.utc_now(), 6, :hour),
      status: "pending"
    },
    %{user: simple_rider}
  )

# Create some volunteer requests to test the matching system
{:ok, _request1} =
  Rides.create_volunteer_request(%{
    ride_id: ride1.id,
    volunteer_user_id: volunteer1.id,
    message:
      "I'd be happy to help with your doctor's appointment! I have experience with mobility assistance.",
    status: "pending"
  })

{:ok, _request2} =
  Rides.create_volunteer_request(%{
    ride_id: ride1.id,
    volunteer_user_id: volunteer2.id,
    message: "I can provide this ride and help carry anything you need.",
    status: "pending"
  })

{:ok, _request3} =
  Rides.create_volunteer_request(%{
    ride_id: ride2.id,
    volunteer_user_id: volunteer1.id,
    message: "I'm available for your grocery trip. I can help with bags too!",
    status: "pending"
  })

{:ok, _request4} =
  Rides.create_volunteer_request(%{
    ride_id: ride4.id,
    volunteer_user_id: volunteer2.id,
    message: "I can get you to the hospital on time. I know the area well.",
    status: "pending"
  })

IO.puts("Database seeded successfully!")
IO.puts("Created #{Enum.count(Repo.all(Accounts.User))} users")
IO.puts("Created #{Enum.count(Repo.all(Rides.Ride))} rides")
IO.puts("Created #{Enum.count(Repo.all(Rides.VolunteerRequest))} volunteer requests")
IO.puts("")
IO.puts("🎯 Simple Test Accounts:")
IO.puts("Rider: rider@example.com")
IO.puts("Volunteer: volunteer@example.com")
IO.puts("Password: password123")
IO.puts("")
IO.puts("📋 Additional Test Users:")
IO.puts("Riders: sarah@example.com, michael@example.com")
IO.puts("Volunteers: emily@example.com, david@example.com")
IO.puts("All passwords: password123")
IO.puts("")
IO.puts("📊 Sample Data:")
IO.puts("- 4 riders, 2 volunteers (6 total users)")
IO.puts("- 6 rides (3 pending, 1 confirmed, 1 completed, 1 urgent)")
IO.puts("- 4 volunteer requests for testing")
IO.puts("- All rides have location privacy fields populated")
IO.puts("- Ready to test location privacy system!")
