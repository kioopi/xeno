defmodule Xeno.Content.Validations.ValidJsonString do
  @moduledoc """
  Validates that a string argument contains valid JSON.

  This validator checks JSON syntax before the string is parsed into a map.
  It allows nil and empty strings (treated as valid), and also accepts
  already-parsed maps for programmatic usage.

  ## Options

  * `:attribute` - The attribute name to validate (required, must be an atom)

  ## Examples

      validate {Validations.ValidJsonString, attribute: :data_string}
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    if is_atom(opts[:attribute]) do
      {:ok, opts}
    else
      {:error, "attribute must be an atom"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    attribute = opts[:attribute]

    case Ash.Changeset.get_argument(changeset, attribute) do
      nil -> :ok
      "" -> :ok
      value when is_binary(value) ->
        case Jason.decode(value) do
          {:ok, _} -> :ok
          {:error, %Jason.DecodeError{} = error} ->
            {:error, field: attribute, message: "Invalid JSON: #{Exception.message(error)}"}
        end
      value when is_map(value) -> :ok
      _ ->
        {:error, field: attribute, message: "must be a JSON string or map"}
    end
  end
end
