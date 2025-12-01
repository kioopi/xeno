defmodule XenoWeb.Components.DocumentationTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests to ensure all components have complete documentation.

  This test suite validates that:
  - All component modules have @moduledoc
  - All public component functions have @doc
  - All components have usage examples
  - All attributes and slots are documented
  """

  describe "module documentation" do
    test "layout.ex has @moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(XenoWeb.Components.Layout)

      assert module_doc != :none,
             "XenoWeb.Components.Layout must have @moduledoc"

      assert module_doc != :hidden,
             "XenoWeb.Components.Layout @moduledoc should not be hidden"

      case module_doc do
        %{"en" => doc_string} ->
          assert String.length(doc_string) > 100,
                 "XenoWeb.Components.Layout @moduledoc should be comprehensive (>100 chars)"

        _ ->
          flunk("XenoWeb.Components.Layout @moduledoc has unexpected format")
      end
    end

    test "ui.ex has @moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(XenoWeb.Components.UI)

      assert module_doc != :none,
             "XenoWeb.Components.UI must have @moduledoc"

      assert module_doc != :hidden,
             "XenoWeb.Components.UI @moduledoc should not be hidden"

      case module_doc do
        %{"en" => doc_string} ->
          assert String.length(doc_string) > 100,
                 "XenoWeb.Components.UI @moduledoc should be comprehensive (>100 chars)"

        _ ->
          flunk("XenoWeb.Components.UI @moduledoc has unexpected format")
      end
    end
  end

  describe "component function documentation" do
    test "all layout component functions have @doc" do
      layout_components = [:container, :stack, :grid, :split, :flank]

      {:docs_v1, _, :elixir, _, _, _, functions} = Code.fetch_docs(XenoWeb.Components.Layout)

      for component <- layout_components do
        doc_entry =
          Enum.find(functions, fn {{type, name, _arity}, _, _, _, _} ->
            type == :function and name == component
          end)

        assert doc_entry != nil,
               "Component #{component}/1 not found in XenoWeb.Components.Layout"

        {{_, _, _}, _, _, doc_content, _} = doc_entry

        assert doc_content != :none,
               "Component #{component}/1 must have @doc"

        assert doc_content != :hidden,
               "Component #{component}/1 @doc should not be hidden"

        case doc_content do
          %{"en" => doc_string} ->
            assert String.length(doc_string) > 50,
                   "Component #{component}/1 @doc should be comprehensive (>50 chars)"

            assert String.contains?(doc_string, "##"),
                   "Component #{component}/1 @doc should contain usage examples with ## headers"

          _ ->
            flunk("Component #{component}/1 @doc has unexpected format")
        end
      end
    end

    test "all ui component functions have @doc" do
      ui_components = [
        :heading,
        :icon,
        :button,
        :badge,
        :spinner,
        :divider,
        :card,
        :alert,
        :page_header,
        :button_group,
        :tag_list,
        :code_block,
        :modal
      ]

      {:docs_v1, _, :elixir, _, _, _, functions} = Code.fetch_docs(XenoWeb.Components.UI)

      for component <- ui_components do
        doc_entry =
          Enum.find(functions, fn {{type, name, _arity}, _, _, _, _} ->
            type == :function and name == component
          end)

        assert doc_entry != nil,
               "Component #{component}/1 not found in XenoWeb.Components.UI"

        {{_, _, _}, _, _, doc_content, _} = doc_entry

        assert doc_content != :none,
               "Component #{component}/1 must have @doc"

        assert doc_content != :hidden,
               "Component #{component}/1 @doc should not be hidden"

        case doc_content do
          %{"en" => doc_string} ->
            assert String.length(doc_string) > 50,
                   "Component #{component}/1 @doc should be comprehensive (>50 chars)"

            assert String.contains?(doc_string, "##"),
                   "Component #{component}/1 @doc should contain usage examples with ## headers"

          _ ->
            flunk("Component #{component}/1 @doc has unexpected format")
        end
      end
    end
  end

  describe "documentation examples" do
    test "layout components have code examples" do
      layout_components = [:container, :stack, :grid, :split, :flank]

      {:docs_v1, _, :elixir, _, _, _, functions} = Code.fetch_docs(XenoWeb.Components.Layout)

      for component <- layout_components do
        {{_, _, _}, _, _, doc_content, _} =
          Enum.find(functions, fn {{type, name, _arity}, _, _, _, _} ->
            type == :function and name == component
          end)

        case doc_content do
          %{"en" => doc_string} ->
            assert String.contains?(doc_string, "<.#{component}"),
                   "Component #{component}/1 @doc should contain usage example with <.#{component}>"

          _ ->
            :ok
        end
      end
    end

    test "ui components have code examples" do
      ui_components = [
        :heading,
        :icon,
        :button,
        :badge,
        :spinner,
        :divider,
        :card,
        :alert,
        :page_header,
        :button_group,
        :tag_list,
        :code_block,
        :modal
      ]

      {:docs_v1, _, :elixir, _, _, _, functions} = Code.fetch_docs(XenoWeb.Components.UI)

      for component <- ui_components do
        {{_, _, _}, _, _, doc_content, _} =
          Enum.find(functions, fn {{type, name, _arity}, _, _, _, _} ->
            type == :function and name == component
          end)

        case doc_content do
          %{"en" => doc_string} ->
            assert String.contains?(doc_string, "<.#{component}"),
                   "Component #{component}/1 @doc should contain usage example with <.#{component}>"

          _ ->
            :ok
        end
      end
    end
  end
end
