defmodule XenoWeb.NoteEditLive do
  @moduledoc """
  LiveView for editing an existing Note.

  Provides a form interface for updating note fields including name, text,
  tags, and data. Handles tag conversion from space-separated string to array
  and JSON string to map conversion. Supports optimistic locking to prevent
  lost updates.
  """
  use XenoWeb, :live_view

  alias Xeno.Content.Note

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Note.get(id) do
      {:ok, note} ->
        note = Ash.load!(note, [:directory, :note_type])
        form = AshPhoenix.Form.for_update(note, :update, as: "note") |> to_form()

        {:ok,
         socket
         |> assign(note: note, form: form, page_title: "Edit #{note.name}")
         |> assign_helpers(note)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Note not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate", %{"note" => params}, socket) do
    processed_params = preprocess_params(params)
    form = AshPhoenix.Form.validate(socket.assigns.form, processed_params)

    socket =
      socket
      |> assign(form: form)
      |> update_helper_assigns(params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"note" => params}, socket) do
    params = preprocess_params(params)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, note} ->
        {:noreply,
         socket
         |> put_flash(:info, "Note updated successfully")
         |> push_navigate(to: ~p"/notes/#{note.id}")}

      {:error, form} ->
        socket =
          if has_stale_record_error?(form) do
            put_flash(
              socket,
              :error,
              "This note has been updated by someone else. Please refresh and try again."
            )
          else
            socket
          end

        {:noreply, assign(socket, form: form)}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/notes/#{socket.assigns.note.id}")}
  end

  defp assign_helpers(socket, note) do
    socket
    |> assign(:tags_string, tags_to_string(note.tags))
    |> assign(:data_string, data_to_string(note.data))
  end

  defp update_helper_assigns(socket, params) do
    socket =
      if Map.has_key?(params, "tags_string") do
        assign(socket, :tags_string, params["tags_string"])
      else
        socket
      end

    socket =
      if Map.has_key?(params, "data_string") do
        assign(socket, :data_string, params["data_string"])
      else
        socket
      end

    socket
  end

  defp preprocess_params(params) do
    params
    |> convert_tags_string_to_array()
    |> convert_data_string_to_map()
  end

  defp convert_tags_string_to_array(params) do
    case Map.get(params, "tags_string") do
      nil ->
        params

      "" ->
        Map.put(params, "tags", [])

      tags_string ->
        tags =
          tags_string
          |> String.split()
          |> Enum.reject(&(&1 == ""))

        params
        |> Map.put("tags", tags)
        |> Map.delete("tags_string")
    end
  end

  defp convert_data_string_to_map(params) do
    case Map.get(params, "data_string") do
      nil ->
        params

      "" ->
        Map.put(params, "data", %{})

      data_string ->
        case Jason.decode(data_string) do
          {:ok, data} ->
            params
            |> Map.put("data", data)
            |> Map.delete("data_string")

          {:error, _} ->
            params
        end
    end
  end

  defp tags_to_string(nil), do: ""
  defp tags_to_string([]), do: ""

  defp tags_to_string(tags) when is_list(tags) do
    tags |> Enum.sort() |> Enum.join(" ")
  end

  defp data_to_string(nil), do: ""
  defp data_to_string(data) when data == %{}, do: ""

  defp data_to_string(data) when is_map(data) do
    Jason.encode!(data, pretty: true)
  end

  defp has_stale_record_error?(form) do
    case AshPhoenix.Form.raw_errors(form, for_path: :all) do
      {_, errors} when is_list(errors) ->
        Enum.any?(errors, fn error ->
          is_struct(error, Ash.Error.Changes.StaleRecord)
        end)

      _ ->
        false
    end
  end
end
