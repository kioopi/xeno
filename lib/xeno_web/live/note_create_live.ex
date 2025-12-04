defmodule XenoWeb.NoteCreateLive do
  @moduledoc """
  LiveView for creating a new Note.

  Provides a form interface for creating notes with directory selection,
  note type templating, and validation.
  """
  use XenoWeb, :live_view

  alias Xeno.Content.NoteType
  alias Xeno.Files

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_page_title()
     |> load_note_types()
     |> load_directories()
     |> create_empty_form()
     |> initialize_state()}
  end

  defp assign_page_title(socket) do
    assign(socket, :page_title, "Create Note")
  end

  defp load_note_types(socket) do
    note_types = NoteType.list!()
    assign(socket, :note_types, note_types)
  end

  defp load_directories(socket) do
    directories = Files.tree!()
    assign(socket, :directories, directories)
  end

  defp create_empty_form(socket) do
    form =
      Xeno.Content.form_to_create_note(
        prepare_source: fn changeset ->
          # Ash.Changeset.load(changeset, [:tags_string, :data_json_string])
          changeset
        end,
        prepare_params: fn params, :validate ->
          params
        end
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp initialize_state(socket) do
    socket
    |> assign(:filename_manually_set, false)
  end

  @impl true
  def handle_event("save", %{"form" => form_data}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: form_data) do
      {:ok, note} ->
        {:noreply,
         socket
         |> put_flash(:info, "Note created successfully")
         |> push_navigate(to: ~p"/notes/#{note.id}")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> put_flash(:error, "Please check the form for errors")}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_event("validate", params, socket) do
    socket =
      socket
      |> mark_filename_manually_set(params)
      |> validate_form(params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("directory_id_changed", %{"id" => directory_id}, socket) do
    {:noreply, update_form(socket, %{"directory_id" => directory_id})}
  end

  defp update_form(socket, data) do
    update(socket, :form, fn form ->
      AshPhoenix.Form.update_params(form, &Map.merge(&1, data))
    end)
  end

  def validate_form(socket, params) do
    update(socket, :form, fn form ->
      form =
        AshPhoenix.Form.validate(form, prepare_params(socket, params),
          only_touched?: true,
          target: Map.get(params, "_target", [])
        )

      AshPhoenix.Form.update_params(form, &Map.merge(&1, changed_params(form)))
    end)
  end

  defp prepare_params(socket, %{"form" => data}) do
    Map.put(data, :overwrite_filename, !socket.assigns.filename_manually_set)
  end

  defp changed_params(form) do
    # ash validation may update attributes based on other attributes
    # via changes.
    # But there seems to be no well defined way back into our
    # Phoenix.HTML.Form
    # source 1 is an Ash.Form
    # source 2 is an Ash.Changeset
    to_string_keys(form.source.source.attributes)
  end

  defp to_string_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp mark_filename_manually_set(socket, %{"_target" => ["form", "filename"]} = params) do
    %{"form" => %{"filename" => filename}} = params

    assign(socket, :filename_manually_set, filename != "")
  end

  defp mark_filename_manually_set(socket, _params) do
    socket
  end

  defp tags_to_string(nil), do: ""
  defp tags_to_string([]), do: ""
  defp tags_to_string(tags) when is_list(tags), do: Enum.join(tags, " ")
  defp tags_to_string(tags) when is_binary(tags), do: tags

  defp data_to_string(nil), do: ""
  defp data_to_string(data) when is_map(data), do: Jason.encode!(data, pretty: true)
  defp data_to_string(data), do: data

  @impl true
  def handle_info({:handle_event, event, params}, socket) do
    handle_event(event, params, socket)
  end
end
