defmodule Xeno.Content.Changes.ParseJsonData do
  @moduledoc """
  Parses a JSON string argument into a map attribute.

  This change converts the `data_string` argument (provided by forms/APIs)
  into the `data` map attribute. It runs after validation, so invalid JSON
  will be caught by ValidJsonString before this runs.

  ## Behavior

  - `nil` → No change (data remains as-is)
  - `""` (empty string) → Sets data to `%{}`
  - Valid JSON string → Parses and sets data to resulting map
  - Already a map → Sets data directly (for programmatic usage)
  - Invalid JSON → Passes through (validation will have caught this)

  ## Examples

      change Changes.ParseJsonData
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :data_string) do
      nil ->
        changeset

      "" ->
        Ash.Changeset.force_change_attribute(changeset, :data, %{})

      value when is_binary(value) ->
        case Jason.decode(value) do
          {:ok, parsed} ->
            Ash.Changeset.force_change_attribute(changeset, :data, parsed)

          {:error, _} ->
            # Validation will catch this, just pass through
            changeset
        end

      value when is_map(value) ->
        # Already a map (programmatic usage)
        Ash.Changeset.force_change_attribute(changeset, :data, value)
    end
  end
end
