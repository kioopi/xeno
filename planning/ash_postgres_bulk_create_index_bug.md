# AshPostgres Bug Report: Missing `bulk_create_index` Metadata

## Summary

AshPostgres 2.6.26 fails to set the `bulk_create_index` metadata field on records returned from bulk create operations, causing a `KeyError` when Ash 3.9.0 attempts to sort bulk create results with the `sorted?: true` option.

## Environment

- **Ash Version**: 3.9.0
- **AshPostgres Version**: 2.6.26
- **AshSQL Version**: 0.3.14
- **Elixir Version**: 1.18.1
- **OTP Version**: 27

## Problem Description

When using `Ash.bulk_create!/4` with the `sorted?: true` option (which is the default for `Ash.Generator.generate_many/2`), the operation fails with a KeyError indicating that the `bulk_create_index` key is missing from the record metadata.

### Error Stack Trace

```
** (KeyError) key :bulk_create_index not found in: %{
  selected: [:id, :name, :filename, :text, :data, :tags, :version, :inserted_at,
   :updated_at, :directory_id, :note_type_id],
  bulk_action_ref: #Reference<0.329940200.3969122312.197178>
}. Did you mean:

      * :bulk_action_ref

stacktrace:
  (ash 3.9.0) lib/ash/actions/create/bulk.ex:1018: anonymous fn/1 in Ash.Actions.Create.Bulk.sort/2
  (elixir 1.18.1) lib/enum.ex:3363: anonymous fn/2 in Enum.sort_by/3
  ...
```

### Root Cause Analysis

#### In Ash Core (Expected Behavior)

When `sorted?: true` is passed to `Ash.bulk_create!/4`, the bulk create handler expects to sort results by the `bulk_create_index` metadata field set on each record:

**File**: `deps/ash/lib/ash/actions/create/bulk.ex:1016-1022`

```elixir
defp sort(%{records: records} = result, opts) when is_list(records) do
  if opts[:sorted?] do
    %{result | records: Enum.sort_by(records, & &1.__metadata__.bulk_create_index)}
  else
    result
  end
end
```

The `bulk_create_index` is set by Ash when creating the changeset context:

**File**: `deps/ash/lib/ash/actions/create/bulk.ex:531`, `542`, `1285`, `1301`

```elixir
bulk_create_index: changeset.context.bulk_create.index
```

#### In AshPostgres (Actual Behavior)

However, AshPostgres only sets the `bulk_action_ref` metadata (as a "Compatibility fallback") and **never sets `bulk_create_index`**:

**File**: `deps/ash_postgres/lib/data_layer.ex:2144-2149` and `2161-2166`

```elixir
# Compatibility fallback
Ash.Resource.put_metadata(
  result,
  :bulk_action_ref,
  changeset.context[:bulk_create][:ref]
)
```

The comment "Compatibility fallback" suggests this was intended as temporary code, but the proper `bulk_create_index` metadata was never added alongside `bulk_action_ref`.

## Reproduction Steps

### Minimal Project Setup

1. Create a new Phoenix + Ash project:

```bash
mix phx.new my_app --install
cd my_app
```

2. Add dependencies to `mix.exs`:

```elixir
defp deps do
  [
    {:ash, "~> 3.9"},
    {:ash_postgres, "~> 2.6"},
    {:ash_phoenix, "~> 2.3"}
  ]
end
```

3. Create a simple Ash resource with a change that loads associations:

```elixir
# lib/my_app/resources/article.ex
defmodule MyApp.Article do
  use Ash.Resource,
    domain: MyApp.Content,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "articles"
    repo MyApp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :body]
    end
  end

  # This change triggers the bug
  changes do
    change load([:category]) do
      on [:create]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false
    attribute :body, :string
  end

  relationships do
    belongs_to :category, MyApp.Category
  end
end

# lib/my_app/resources/category.ex
defmodule MyApp.Category do
  use Ash.Resource,
    domain: MyApp.Content,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "categories"
    repo MyApp.Repo
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
  end

  relationships do
    has_many :articles, MyApp.Article
  end
end
```

4. Create a test that uses `Ash.Generator.generate_many/2`:

```elixir
# test/my_app/article_test.exs
defmodule MyApp.ArticleTest do
  use MyApp.DataCase
  import Ash.Generator

  test "generate many articles" do
    # This will fail with KeyError on bulk_create_index
    articles = generate_many(article(), 3)

    assert length(articles) == 3
  end

  defp article(overrides \\ []) do
    Ash.Generator.seed_input(MyApp.Article, :create, overrides)
  end
end
```

5. Run the test:

```bash
mix test test/my_app/article_test.exs
```

### Expected vs Actual Behavior

**Expected**: The bulk create operation should succeed and return 3 sorted article records with all metadata properly set.

**Actual**: The operation fails with:

```
** (KeyError) key :bulk_create_index not found in: %{
  bulk_action_ref: #Reference<...>
}
```

## Why Some Resources Work and Others Don't

The bug is most likely to manifest in resources that have:

1. A `change load([...])` hook on `:create` action (as shown in the example)
2. Complex associations or computed attributes
3. Any operation that causes Ash to interact with the record metadata after bulk creation

Resources without these features may not trigger the sorting code path that exposes the missing metadata.

## Proposed Fix

In `deps/ash_postgres/lib/data_layer.ex`, the "Compatibility fallback" sections (around lines 2144-2149 and 2161-2166) should be updated to set **both** `bulk_action_ref` and `bulk_create_index` metadata:

### Current Code (Incomplete)

```elixir
# Compatibility fallback
Ash.Resource.put_metadata(
  result,
  :bulk_action_ref,
  changeset.context[:bulk_create][:ref]
)
```

### Proposed Fix

```elixir
# Set both metadata fields expected by Ash 3.9+
result
|> Ash.Resource.put_metadata(
  :bulk_action_ref,
  changeset.context[:bulk_create][:ref]
)
|> Ash.Resource.put_metadata(
  :bulk_create_index,
  changeset.context[:bulk_create][:index]
)
```

Or using `set_metadata/2` for a cleaner approach:

```elixir
Ash.Resource.set_metadata(result, %{
  bulk_action_ref: changeset.context[:bulk_create][:ref],
  bulk_create_index: changeset.context[:bulk_create][:index]
})
```

This change needs to be applied in **both** locations where the compatibility fallback is used (lines ~2147 and ~2164 in the current version).

## Workarounds

Until this is fixed in AshPostgres, users can:

1. **Avoid `generate_many/2`**: Use individual `generate/1` calls instead:

```elixir
# Instead of:
articles = generate_many(article(), 3)

# Use:
articles = Enum.map(1..3, fn _ -> generate(article()) end)
```

2. **Skip affected tests**: Mark tests using `generate_many` with `@tag :skip` and add a comment referencing this issue.

3. **Disable sorting**: If calling `Ash.bulk_create!` directly, pass `sorted?: false`:

```elixir
Ash.bulk_create!(inputs, MyApp.Article, :create, sorted?: false)
```

## Additional Notes

- The issue appears to have been introduced during the "simplify bulk operation metadata handling" changes in AshPostgres v2.6.21 (October 2024)
- The "Compatibility fallback" comment suggests this was meant to be temporary transition code
- The proper fix should align AshPostgres's metadata handling with what Ash 3.9.0 expects

## Related Code References

### Xeno Project Context

In our project, this affects:

- `test/xeno/content/generator_example_test.exs:122` - "generate multiple notes" test
- `test/xeno/content/generator_example_test.exs:134` - "generate multiple notes with same type" test
- `lib/xeno/content/note.ex:189-191` - The `change load([:directory, :note_type])` hook that triggers the issue

The Note resource is particularly affected because it loads associations on create, which causes Ash to process the bulk results through the sorting code path.
