defmodule Carlosassist.Accounts.User do
  @moduledoc """
  User schema and changesets for the authentication system.

  ## Roles

  The system supports three user roles:
  - `"volunteer"` - Users who provide assistance/services
  - `"rider"` - Users who request assistance/services
  - `"admin"` - Users with administrative privileges (can access both volunteer and rider functionality)

  The default role is `"rider"` as set in the database migration.

  Only rider/volunteer can be chosen through user-facing changesets; admin is
  granted manually (e.g. via iex: `Repo.update!(Ecto.Changeset.change(user, role: "admin"))`).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :phone, :string
    field :role, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :profile_pic_location, :string

    # Volunteer-specific fields
    field :volunteer_license_plate, :string
    field :volunteer_car, :string
    field :volunteer_bio, :string

    has_many :rides, Carlosassist.Rides.Ride

    timestamps(type: :utc_datetime)
  end

  ## Registration Changesets

  @doc """
  A user changeset specifically for user registration.

  This is used only when creating new user accounts and includes
  all required fields for initial account setup.

  ## Options

    * `:validate_email` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :email,
      :phone,
      :role,
      :volunteer_license_plate,
      :volunteer_car,
      :volunteer_bio,
      :profile_pic_location
    ])
    |> validate_email_for_registration(opts)
    |> validate_phone()
    |> validate_role()
    |> validate_volunteer_fields()
    |> validate_profile_pic_location()
  end

  ## Update Changesets

  @doc """
  A user changeset for updating basic user information.

  This allows updating email, phone, role, and volunteer fields
  but includes proper validation for updates (not registration).
  """
  def update_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :email,
      :phone,
      :role,
      :volunteer_license_plate,
      :volunteer_car,
      :volunteer_bio,
      :profile_pic_location
    ])
    |> validate_email_for_update(opts)
    |> validate_phone()
    |> validate_role()
    |> validate_volunteer_fields()
    |> validate_profile_pic_location()
  end

  @doc """
  A user changeset specifically for updating email addresses.

  This includes validation to ensure the email actually changes
  and is suitable for email update workflows.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email_for_update(opts)
    |> validate_email_changed()
  end

  @doc """
  A user changeset specifically for updating phone numbers.
  """
  def phone_changeset(user, attrs) do
    user
    |> cast(attrs, [:phone])
    |> validate_phone()
  end

  @doc """
  A user changeset specifically for updating volunteer information.

  This is only applicable to users with the "volunteer" role.
  """
  def volunteer_info_changeset(user, attrs) do
    user
    |> cast(attrs, [:volunteer_license_plate, :volunteer_car, :volunteer_bio])
    |> validate_volunteer_fields()
  end

  @doc """
  A user changeset specifically for updating profile pictures.
  """
  def profile_pic_changeset(user, attrs) do
    user
    |> cast(attrs, [:profile_pic_location])
    |> validate_profile_pic_location()
  end

  ## Password Changesets

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  ## Validation Functions

  defp validate_profile_pic_location(changeset) do
    changeset
    |> validate_format(:profile_pic_location, ~r/\.(jpg|jpeg|png|webp)$/i,
      message: "must be a valid image file (jpg, jpeg, png, webp)"
    )
  end

  defp validate_email_for_registration(changeset, opts) do
    changeset =
      changeset
      # Stored lowercase: SQLite comparisons are case-sensitive (no citext)
      |> update_change(:email, &String.downcase/1)
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Carlosassist.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp validate_email_for_update(changeset, opts) do
    changeset =
      changeset
      # Stored lowercase: SQLite comparisons are case-sensitive (no citext)
      |> update_change(:email, &String.downcase/1)
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Carlosassist.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  defp validate_phone(changeset) do
    changeset
    |> validate_required([:phone])
    |> update_change(:phone, &normalize_phone/1)
    |> validate_format(:phone, ~r/^\+?1?\d{10,14}$/,
      message:
        "must be a valid phone number. Example formats: 415-555-0101, (415) 555-0101, +14155550101"
    )
  end

  defp normalize_phone(nil), do: nil

  defp normalize_phone(phone) do
    # Remove all non-digit characters except + at the start
    normalized =
      phone
      |> String.trim()
      |> String.replace(~r/[^\d+]/, "")
      |> String.replace(~r/^\+?1?(\d{10,14})$/, "\\1")

    # Add +1 prefix if not present and we have a 10-digit number
    case String.length(normalized) do
      10 ->
        "+1" <> normalized

      n when n in 11..14 ->
        if String.starts_with?(normalized, "1") do
          "+" <> normalized
        else
          normalized
        end

      # Return original if we can't normalize it
      _ ->
        phone
    end
  end

  # Deliberately excludes "admin": these changesets take user-supplied params,
  # so allowing it would let anyone self-register as admin.
  defp validate_role(changeset) do
    changeset
    |> validate_required([:role])
    |> validate_inclusion(:role, ["volunteer", "rider"],
      message: "must be either volunteer or rider"
    )
  end

  defp validate_volunteer_fields(changeset) do
    role = get_field(changeset, :role)

    if role == "volunteer" do
      changeset
      |> validate_required([:volunteer_license_plate, :volunteer_car],
        message: "is required for volunteers"
      )
      |> validate_length(:volunteer_license_plate, min: 2, max: 20)
      |> validate_length(:volunteer_car, min: 3, max: 100)
      |> validate_length(:volunteer_bio, max: 1000)
    else
      changeset
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  ## Utility Changesets

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Carlosassist.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
