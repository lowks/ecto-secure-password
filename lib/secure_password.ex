defmodule SecurePassword do
  @moduledoc ~S"""
  Provides an easy way to interact with hashed password for Ecto models.

  ## Example

      defmodule User do
        use Ecto.Schema
        use SecurePassword

        import Ecto.Changeset

        schema "users" do
          field :email, :string
          field :name, :string

          has_secure_password
        end

        @required_fields ~w(email)
        @optional_fields ~w(name)

        def changeset(model, params \\ :empty) do
          model
          |> cast(params, @required_fields, @optional_fields)
          |> with_secure_password(min_length: 8)
        end
      end

  """

  require Ecto.Schema

  @default_secure_password_opts [
    min_length: 6,
    required: true
  ]

  import Ecto.Changeset

  defmacro __using__(_opts) do
    quote do
      import SecurePassword

      def authenticate(model, password) do
        SecurePassword.authenticate(model, password)
      end
    end
  end

  @doc """
  Defines the needed fiels in the schema.
  Expects `password_digest` row to exist in the database.

      schema "user" do
          field "name", :string

          has_secure_password
      end

  """
  defmacro has_secure_password do
    quote do
      Ecto.Schema.field(:password, :string, [virtual: true])
      Ecto.Schema.field(:password_confirmation, :string, [virtual: true])
      Ecto.Schema.field(:password_digest, :string)
    end
  end

  @doc """
  Validates and modify the changeset to remove the `password` and `password_confirmation` fields
  and add the hashed `password_digest` field.

  ## Options

    * `required`: Do not force the password to be present if set to `false`. (default: `true`)
    * `min_length`: Set the minimum length for the password. (default: `6`)

  """
  def with_secure_password(changeset, opts \\ []) do
    opts = Dict.merge(@default_secure_password_opts, opts)
    if has_password(changeset) do
      password = Dict.get(changeset.params, "password")
      changeset = changeset |> put_change(:password, password) |> validate_password(opts)
      if changeset.valid?, do: set_secure_password(changeset),
      else: changeset
    else
      if !opts[:required] || changeset.model.id, do: changeset,
      else: %{changeset | errors: [{:password, "can't be blank"}|changeset.errors], valid?: false}
    end
  end

  @doc """
  Checks if the model password if valid.
  """
  def authenticate(nil, _), do: false
  def authenticate(model, nil), do: authenticate(model, "")
  def authenticate(model, password) do
    Comeonin.Bcrypt.checkpw(password, model.password_digest) && model
  end

  defp has_password(changeset) do
    password = Dict.get(changeset.params, "password")
    is_binary(password) && String.length(password) > 0
  end

  defp validate_password(changeset, opts) do
    if min_length = opts[:min_length] do
      changeset = validate_length(changeset, :password, min: min_length)
    end
    validate_confirmation(changeset, :password)
  end

  defp set_secure_password(changeset) do
    hashed = Comeonin.Bcrypt.hashpwsalt(Dict.get(changeset.params, "password"))
    changeset
      |> put_change(:password_digest, hashed)
      |> delete_change(:password)
      |> delete_change(:password_confirmation)
  end
end
