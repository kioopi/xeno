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
        note = Ash.load!(note, [:directory, :note_type, :tags_string, :data_json_string])
        form = AshPhoenix.Form.for_update(note, :update, as: "note") |> to_form()

        {:ok,
         socket
         |> assign(note: note, form: form, page_title: "Edit #{note.name}")}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Note not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate", %{"note" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    socket =
      socket
      |> assign(form: form)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"note" => params}, socket) do
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
