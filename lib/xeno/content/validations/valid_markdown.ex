defmodule Xeno.Content.Validations.ValidMarkdown do
  @moduledoc """
  Validates markdown syntax using Earmark parser.

  This validator checks for markdown syntax errors but allows warnings
  and deprecations. Only `:error` severity messages block validation.

  Earmark returns messages in the format: `{severity, line_number, description}`
  where severity can be `:error`, `:warning`, or `:deprecation`.

  ## Options

  * `:attribute` - The attribute name to validate (required, must be an atom)

  ## Examples

      validate {Validations.ValidMarkdown, attribute: :text}
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

    value = Ash.Changeset.get_attribute(changeset, attribute)

    case value do
      nil -> :ok
      "" -> :ok
      markdown when is_binary(markdown) ->
        validate_markdown_syntax(markdown, attribute)
      _ ->
        {:error, field: attribute, message: "must be a string"}
    end
  end

  defp validate_markdown_syntax(markdown, attribute) do
    case Earmark.Parser.as_ast(markdown) do
      {:ok, _ast, []} ->
        :ok

      {:ok, _ast, messages} ->
        # Has warnings/deprecations but no errors - allow save
        case Enum.filter(messages, &match?({:error, _, _}, &1)) do
          [] -> :ok
          errors -> format_errors(errors, attribute)
        end

      {:error, _ast, messages} ->
        # Parse failed - extract error messages
        errors = Enum.filter(messages, &match?({:error, _, _}, &1))
        format_errors(errors, attribute)
    end
  end

  defp format_errors(errors, attribute) do
    formatted =
      errors
      |> Enum.map(fn {:error, line, description} ->
        "Line #{line}: #{description}"
      end)
      |> Enum.join("; ")

    {:error, field: attribute, message: "Invalid markdown - #{formatted}"}
  end
end
