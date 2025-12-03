defmodule XenoWeb.NoteCreateLive do
  @moduledoc """
  LiveView for creating a new Note.

  Provides a form interface for creating notes with directory selection,
  note type templating, and validation.
  """
  use XenoWeb, :live_view

  alias Xeno.Content.{Note, NoteType}
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
      Note
      |> AshPhoenix.Form.for_create(:create,
        as: "note",
        forms: [auto?: true]
      )
      |> to_form()

    assign(socket, :form, form)
  end

  defp initialize_state(socket) do
    socket
    |> assign(:selected_directory_id, nil)
    |> assign(:selected_note_type, nil)
    |> assign(:filename_manually_set, false)
    |> assign(:tags_string, "")
    |> assign(:data_string, "")
    |> assign(:markdown_error, nil)
    |> assign(:json_error, nil)
  end

  @impl true
  def handle_event("select_directory", %{"id" => directory_id}, socket) do
    {:noreply, assign(socket, :selected_directory_id, directory_id)}
  end

  @impl true
  def handle_event("note_type_changed", %{"note_type_id" => ""}, socket) do
    {:noreply,
     socket
     |> assign(:selected_note_type, nil)
     |> assign(:tags_string, "")
     |> assign(:data_string, "")
     |> update_form_text("")}
  end

  def handle_event("note_type_changed", %{"note_type_id" => note_type_id}, socket) do
    note_type = Enum.find(socket.assigns.note_types, &(&1.id == note_type_id))

    socket =
      socket
      |> assign(:selected_note_type, note_type_id)
      |> assign(:tags_string, tags_to_string(note_type.initial_tags))
      |> assign(:data_string, data_to_string(note_type.initial_data))
      |> update_form_text(note_type.initial_text || "")

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"note" => note_params}, socket) do
    processed_params =
      note_params
      |> preprocess_params(socket)
      |> Map.put("directory_id", socket.assigns.selected_directory_id)
      |> maybe_add_note_type_id(socket)

    case AshPhoenix.Form.submit(socket.assigns.form, params: processed_params) do
      {:ok, note} ->
        {:noreply,
         socket
         |> put_flash(:info, "Note created successfully")
         |> push_navigate(to: ~p"/notes/#{note.id}")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> put_flash(:error, "Please check the form for errors")
         |> update_helper_assigns(note_params)}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_event("validate", %{"note" => note_params} = params, socket) do
    note_type_id = params["note_type_id"]

    socket =
      if filename_changed?(note_params, socket.assigns.form) do
        assign(socket, :filename_manually_set, true)
      else
        socket
      end

    json_error = validate_json(Map.get(note_params, "data_string"))

    processed_params = preprocess_params(note_params, socket)

    updated_form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(processed_params)
      |> to_form()

    socket =
      socket
      |> assign(:form, updated_form)
      |> assign(:json_error, json_error)
      |> maybe_update_note_type_id(note_type_id)
      |> update_helper_assigns(note_params)

    {:noreply, socket}
  end

  defp maybe_update_note_type_id(socket, nil), do: socket
  defp maybe_update_note_type_id(socket, ""), do: socket

  defp maybe_update_note_type_id(socket, note_type_id) do
    assign(socket, :selected_note_type, note_type_id)
  end

  defp tags_to_string(nil), do: ""
  defp tags_to_string([]), do: ""
  defp tags_to_string(tags) when is_list(tags), do: Enum.join(tags, " ")

  defp data_to_string(nil), do: ""
  defp data_to_string(data) when is_map(data), do: Jason.encode!(data, pretty: true)

  defp update_form_text(socket, text) do
    existing_params = socket.assigns.form.source.params

    updated_form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(Map.put(existing_params, "text", text))
      |> to_form()

    assign(socket, :form, updated_form)
  end

  defp preprocess_params(params, socket) do
    params
    |> maybe_generate_filename(socket)
    |> convert_tags_string_to_array()
    |> convert_data_string_to_map()
  end

  defp maybe_generate_filename(params, socket) do
    filename = Map.get(params, "filename", "")
    name = Map.get(params, "name", "")

    if !socket.assigns.filename_manually_set && filename == "" && name != "" do
      Map.put(params, "filename", generate_filename_from_name(name))
    else
      params
    end
  end

  defp generate_filename_from_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]+/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
  end

  defp filename_changed?(params, form) do
    new_filename = Map.get(params, "filename", "")
    old_filename = AshPhoenix.Form.value(form, :filename) || ""

    new_filename != "" && new_filename != old_filename
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

  defp validate_json(nil), do: nil
  defp validate_json(""), do: nil

  defp validate_json(data_string) do
    case Jason.decode(data_string) do
      {:ok, _} -> nil
      {:error, %Jason.DecodeError{} = error} ->
        "Invalid JSON: #{Exception.message(error)}"
    end
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

  defp maybe_add_note_type_id(params, socket) do
    case socket.assigns.selected_note_type do
      nil -> params
      note_type_id -> Map.put(params, "note_type_id", note_type_id)
    end
  end

  defp get_argument_error(form, argument_name) do
    case form.source do
      %AshPhoenix.Form{submitted_once?: true, source: %Ash.Changeset{errors: errors}}
      when is_list(errors) ->
        errors
        |> Enum.find_value(fn
          %{field: ^argument_name} = error ->
            Exception.message(error)

          _ ->
            nil
        end)

      _ ->
        nil
    end
  end
end
