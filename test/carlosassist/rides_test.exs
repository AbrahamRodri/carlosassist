defmodule Carlosassist.RidesTest do
  use Carlosassist.DataCase

  import Carlosassist.AccountsFixtures

  alias Carlosassist.Messages
  alias Carlosassist.Repo
  alias Carlosassist.Rides
  alias Carlosassist.Rides.Ride
  alias Carlosassist.Rides.VolunteerRequest

  defp rider_scope, do: user_scope_fixture()

  defp volunteer_fixture do
    user_fixture(%{
      role: "volunteer",
      volunteer_car: "2020 Toyota Camry",
      volunteer_license_plate: "ABC123"
    })
  end

  defp ride_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        pickup_name: "Home",
        pickup_address: "123 Main St, Austin, TX",
        destination_name: "Clinic",
        destination_address: "456 Medical Dr, Austin, TX",
        description: "Need a ride to my weekly appointment",
        ride_date: DateTime.add(DateTime.utc_now(), 1, :day)
      })

    {:ok, ride} = Rides.create_ride(attrs, scope)
    ride
  end

  defp volunteer_request_fixture(ride, volunteer, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        ride_id: ride.id,
        volunteer_user_id: volunteer.id,
        message: "Happy to help!",
        status: "pending"
      })

    {:ok, request} = Rides.create_volunteer_request(attrs)
    request
  end

  describe "delete_ride/2" do
    test "owner can delete a pending ride and its volunteer requests" do
      scope = rider_scope()
      ride = ride_fixture(scope)
      volunteer_request_fixture(ride, volunteer_fixture())

      assert {:ok, _} = Rides.delete_ride(ride, scope)
      refute Repo.get(Ride, ride.id)
      assert Repo.aggregate(VolunteerRequest, :count) == 0
    end

    test "another user cannot delete someone else's ride" do
      ride = ride_fixture(rider_scope())
      other_scope = rider_scope()

      assert {:error, :unauthorized} = Rides.delete_ride(ride, other_scope)
      assert Repo.get(Ride, ride.id)
    end

    test "non-pending rides cannot be deleted" do
      scope = rider_scope()
      ride = ride_fixture(scope, %{status: "confirmed", volunteer_id: volunteer_fixture().id})

      assert {:error, :invalid_status} = Rides.delete_ride(ride, scope)
      assert Repo.get(Ride, ride.id)
    end
  end

  describe "accept_volunteer_request/3" do
    test "owner accepts: confirms ride, rejects others, opens conversation" do
      scope = rider_scope()
      ride = ride_fixture(scope)
      accepted = volunteer_request_fixture(ride, volunteer_fixture())
      other = volunteer_request_fixture(ride, volunteer_fixture())

      assert {:ok, {accepted_request, updated_ride}} =
               Rides.accept_volunteer_request(accepted.id, ride.id, scope)

      assert accepted_request.status == "accepted"
      assert updated_ride.status == "confirmed"
      assert updated_ride.volunteer_id == accepted.volunteer_user_id
      assert Repo.get(VolunteerRequest, other.id).status == "rejected"
      assert Messages.get_conversation_by_ride(ride.id)
    end

    test "non-owner cannot accept a request" do
      ride = ride_fixture(rider_scope())
      request = volunteer_request_fixture(ride, volunteer_fixture())

      assert {:error, :unauthorized} =
               Rides.accept_volunteer_request(request.id, ride.id, rider_scope())

      assert Repo.get(Ride, ride.id).status == "pending"
    end

    test "request must belong to the ride being confirmed" do
      scope = rider_scope()
      ride = ride_fixture(scope)
      other_ride = ride_fixture(scope)
      request_for_other = volunteer_request_fixture(other_ride, volunteer_fixture())

      assert {:error, :not_found} =
               Rides.accept_volunteer_request(request_for_other.id, ride.id, scope)
    end
  end

  describe "reject_volunteer_request/2" do
    test "owner can reject" do
      scope = rider_scope()
      ride = ride_fixture(scope)
      request = volunteer_request_fixture(ride, volunteer_fixture())

      assert {:ok, rejected} = Rides.reject_volunteer_request(request.id, scope)
      assert rejected.status == "rejected"
    end

    test "non-owner cannot reject" do
      ride = ride_fixture(rider_scope())
      request = volunteer_request_fixture(ride, volunteer_fixture())

      assert {:error, :unauthorized} =
               Rides.reject_volunteer_request(request.id, rider_scope())

      assert Repo.get(VolunteerRequest, request.id).status == "pending"
    end
  end

  describe "complete_ride/2" do
    test "owner completes a confirmed ride and the conversation closes" do
      scope = rider_scope()
      ride = ride_fixture(scope)
      request = volunteer_request_fixture(ride, volunteer_fixture())
      {:ok, _} = Rides.accept_volunteer_request(request.id, ride.id, scope)

      assert {:ok, completed} = Rides.complete_ride(ride.id, scope)
      assert completed.status == "completed"
      assert Messages.get_conversation_by_ride(ride.id).status == "closed"
    end

    test "non-owner cannot complete" do
      scope = rider_scope()
      ride = ride_fixture(scope, %{status: "confirmed", volunteer_id: volunteer_fixture().id})

      assert {:error, :unauthorized} = Rides.complete_ride(ride.id, rider_scope())
    end

    test "pending rides cannot be completed" do
      scope = rider_scope()
      ride = ride_fixture(scope)

      assert {:error, :invalid_status} = Rides.complete_ride(ride.id, scope)
    end
  end

  describe "cancel_ride/2" do
    test "owner cancels a pending ride and outstanding requests are rejected" do
      scope = rider_scope()
      ride = ride_fixture(scope)
      request = volunteer_request_fixture(ride, volunteer_fixture())

      assert {:ok, cancelled} = Rides.cancel_ride(ride.id, scope)
      assert cancelled.status == "cancelled"
      assert Repo.get(VolunteerRequest, request.id).status == "rejected"
    end

    test "owner cancels a confirmed ride and the conversation closes" do
      scope = rider_scope()
      ride = ride_fixture(scope)
      request = volunteer_request_fixture(ride, volunteer_fixture())
      {:ok, _} = Rides.accept_volunteer_request(request.id, ride.id, scope)

      assert {:ok, cancelled} = Rides.cancel_ride(ride.id, scope)
      assert cancelled.status == "cancelled"
      assert Messages.get_conversation_by_ride(ride.id).status == "closed"
    end

    test "non-owner cannot cancel" do
      ride = ride_fixture(rider_scope())

      assert {:error, :unauthorized} = Rides.cancel_ride(ride.id, rider_scope())
    end

    test "completed rides cannot be cancelled" do
      scope = rider_scope()
      ride = ride_fixture(scope)
      request = volunteer_request_fixture(ride, volunteer_fixture())
      {:ok, _} = Rides.accept_volunteer_request(request.id, ride.id, scope)
      {:ok, _} = Rides.complete_ride(ride.id, scope)

      assert {:error, :invalid_status} = Rides.cancel_ride(ride.id, scope)
    end
  end
end
