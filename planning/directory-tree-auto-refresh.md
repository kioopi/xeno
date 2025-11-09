# Directory Tree Auto-Refresh Feature - TDD Implementation Plan

## Current Status

**Last Updated**: 2025-11-10

### ✅ Completed Phases

- **Phase 1: Basic PubSub Infrastructure** - COMPLETE
  - All 4 directory actions (create, update, move, destroy) broadcast to PubSub
  - Tests organized in separate file: `test/xeno/files/directory_pubsub_test.exs`
  - Code interface functions added for all actions
  - Tests verified stable with ID pinning pattern (no flakiness)
  - Verified descendants don't trigger notifications during move operations

- **Phase 2: Smart Tree Update Functions** - COMPLETE
  - All 3 functions implemented with ltree optimizations
  - `find_root_ancestor/1` uses O(1) ltree path extraction (not O(depth) recursion)
  - `build_branch/1` leverages ltree `descendants_of` action with `<@` operator
  - `update_tree/3` preserves object identity for unchanged branches
  - 9 new tests added (11 total tree tests), 0 failures
  - Full test suite: 76 tests, 0 failures
  - Code interface extended: added `get` and `descendants_of` functions

### 🚧 In Progress

- **Phase 3: LiveView Integration** - NOT STARTED

### 📋 Remaining Phases

- **Phase 4: Refinement & Edge Cases** - NOT STARTED

---

## Overview

Implement automatic directory tree refresh in InfoLive when Directory resources are created, updated, moved, or destroyed using Ash.Notifier.PubSub.

## Goals

- Real-time updates to directory tree in InfoLive
- Smart updates (only rebuild affected branches)
- Test-driven development approach
- Small, incremental changes
- Testable at every step

## Architecture Decision Records

### ADR-001: Use Ash.Notifier.PubSub

- **Decision**: Use Ash's built-in PubSub notifier
- **Rationale**: Declarative, well-integrated, follows Ash patterns
- **Alternative**: Custom notifier (more code, more maintenance)

### ADR-002: Per-Action Topics

- **Decision**: Use separate topics for each action type
- **Topics**: `directory:created`, `directory:updated`, `directory:moved`, `directory:destroyed`
- **Rationale**: Allows fine-grained subscription and future flexibility
- **Alternative**: Single `directory:changes` topic (less granular)
- **Note**: Move action broadcasts with `event: "move"` (uses action name, not "update")

### ADR-003: Smart Branch Updates

- **Decision**: Rebuild only affected root directory branches
- **Rationale**: Better performance, less DOM churn
- **Alternative**: Full tree rebuild (simpler but less performant)

### ADR-004: Phoenix Broadcast Type

- **Decision**: Use `broadcast_type: :phoenix_broadcast`
- **Rationale**: Native LiveView integration, standard pattern
- **Alternative**: Custom payload structure

### ADR-005: Async Test Strategy for PubSub

- **Decision**: Use ID pinning pattern for async PubSub tests
- **Implementation**:
  - Generate unique directory names with `System.unique_integer/1`
  - Extract directory IDs into variables
  - Use pin operator `^` in pattern matching to accept only expected notifications
- **Rationale**: Enables fast async test execution while preventing cross-test pollution
- **Alternative**: Disable async (`async: false`) - simpler but much slower
- **Result**: Tests remain async, ~5x faster than sequential execution, 0% flakiness

### ADR-006: Ltree Path Optimization for Root Finding

- **Decision**: Use ltree path segment extraction for `find_root_ancestor/1` instead of recursive parent traversal
- **Implementation**:
  - Extract first segment from `path_ltree` (e.g., `["docs", "guides"]` → `"docs"`)
  - Query root directly: `Directory.by_path!("/#{root_segment}")`
  - Return self if already at root (optimization to avoid unnecessary query)
- **Rationale**:
  - O(1) database queries regardless of nesting depth
  - Traditional approach requires O(depth) queries (recursive parent loading)
  - For directory nested 10 levels deep, saves 9 database queries
- **Alternative**: Recursive parent traversal (original plan approach)
- **Result**: Implemented in Phase 2, significantly faster than planned approach

## Implementation Phases

### Phase 1: Basic PubSub Infrastructure (Testable)

Add PubSub notifications without LiveView integration - can verify with manual subscription in IEx.

### Phase 2: Smart Tree Update Functions (Testable)

Pure functions for tree manipulation - fully unit testable.

### Phase 3: LiveView Integration (Testable)

Connect PubSub to InfoLive - integration testable.

### Phase 4: Refinement & Edge Cases (Testable)

Handle edge cases and optimize - test all scenarios.

---

## Phase 1: Basic PubSub Infrastructure

### Step 1.1: Test PubSub Broadcast on Directory Create

**File**: `test/xeno/files/directory_test.exs`

**What to do**:

1. Add a new test block: `describe "pubsub notifications"`
2. Write test: `test "broadcasts message on create"`
3. Subscribe to `"directory:created"` topic
4. Create a directory
5. Assert message received with correct payload

**Expected result**: ❌ Test fails - no PubSub configured yet

**How to verify manually**:

```elixir
# In IEx
Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")
Xeno.Files.Directory.create!(%{name: "test", path: "/test"})
# Should receive no message yet
```

**Code example**:

```elixir
describe "pubsub notifications" do
  test "broadcasts message on directory:created topic when directory is created" do
    Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")

    directory = Directory.create!(%{name: "test", path: "/test"})

    assert_receive %Phoenix.Socket.Broadcast{
      topic: "directory:created",
      event: "create",
      payload: %{data: %{id: id}}
    }
    assert id == directory.id
  end
end
```

---

### Step 1.2: Configure PubSub for Create Action

**File**: `lib/xeno/files/directory.ex`

**What to do**:

1. Add `notifiers: [Ash.Notifier.PubSub]` to resource options
2. Add `pub_sub` block after `postgres` block
3. Configure module: `XenoWeb.Endpoint`
4. Add publish for `:create` action: `publish :create, "directory:created"`
5. Set `broadcast_type :phoenix_broadcast`

**Expected result**: ✅ Test from 1.1 passes

**How to verify manually**:

```elixir
# In IEx (restart after code change)
Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")
Xeno.Files.Directory.create!(%{name: "test", path: "/test"})
# Should now receive a broadcast message
flush() # See the message
```

**Code example**:

```elixir
use Ash.Resource,
  domain: Xeno.Files,
  data_layer: AshPostgres.DataLayer,
  notifiers: [Ash.Notifier.PubSub]

pub_sub do
  module XenoWeb.Endpoint
  prefix "directory"

  publish :create, "created"

  broadcast_type :phoenix_broadcast
end
```

---

### Step 1.3: Test PubSub Broadcast on Directory Update

**File**: `test/xeno/files/directory_test.exs`

**What to do**:

1. Add test: `test "broadcasts message on directory:updated topic when directory is updated"`
2. Create a directory first
3. Subscribe to `"directory:updated"` topic
4. Update the directory (e.g., change name)
5. Assert message received

**Expected result**: ❌ Test fails - update not configured yet

**Code example**:

```elixir
test "broadcasts message on directory:updated topic when directory is updated" do
  directory = Directory.create!(%{name: "test", path: "/test"})

  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:updated")

  updated = Directory.update!(directory, %{name: "updated"})

  assert_receive %Phoenix.Socket.Broadcast{
    topic: "directory:updated",
    event: "update",
    payload: %{data: %{id: id}}
  }
  assert id == updated.id
end
```

---

### Step 1.4: Configure PubSub for Update Action

**File**: `lib/xeno/files/directory.ex`

**What to do**:

1. Add to `pub_sub` block: `publish :update, "updated"`

**Expected result**: ✅ Test from 1.3 passes

**How to verify manually**:

```elixir
# In IEx
Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:updated")
dir = Xeno.Files.Directory.create!(%{name: "test", path: "/test"})
Xeno.Files.Directory.update!(dir, %{name: "changed"})
flush()
```

---

### Step 1.5: Test PubSub Broadcast on Directory Move

**File**: `test/xeno/files/directory_test.exs`

**What to do**:

1. Add test: `test "broadcasts message on directory:moved topic when directory is moved"`
2. Create parent and child directories
3. Subscribe to `"directory:moved"` topic
4. Move the child directory
5. Assert message received

**Expected result**: ❌ Test fails - move not configured yet

**Code example**:

```elixir
test "broadcasts message on directory:moved topic when directory is moved" do
  parent1 = Directory.create!(%{name: "parent1", path: "/parent1"})
  parent2 = Directory.create!(%{name: "parent2", path: "/parent2"})
  child = Directory.create!(%{name: "child", path: "/parent1/child"})

  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:moved")

  moved = Directory.move!(child, parent2)

  assert_receive %Phoenix.Socket.Broadcast{
    topic: "directory:moved",
    event: "update",
    payload: %{data: %{id: id}}
  }
  assert id == moved.id
end
```

---

### Step 1.6: Configure PubSub for Move Action

**File**: `lib/xeno/files/directory.ex`

**What to do**:

1. Add to `pub_sub` block: `publish :move, "moved"`

**Expected result**: ✅ Test from 1.5 passes

**Note**: The `:move` action is an update action, so the event will be "update" not "move"

---

### Step 1.7: Test PubSub Broadcast on Directory Destroy

**File**: `test/xeno/files/directory_test.exs`

**What to do**:

1. Add test: `test "broadcasts message on directory:destroyed topic when directory is destroyed"`
2. Create a directory
3. Subscribe to `"directory:destroyed"` topic
4. Destroy the directory
5. Assert message received

**Expected result**: ❌ Test fails - destroy not configured yet

**Code example**:

```elixir
test "broadcasts message on directory:destroyed topic when directory is destroyed" do
  directory = Directory.create!(%{name: "test", path: "/test"})

  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:destroyed")

  Directory.destroy!(directory)

  assert_receive %Phoenix.Socket.Broadcast{
    topic: "directory:destroyed",
    event: "destroy",
    payload: %{data: %{id: id}}
  }
  assert id == directory.id
end
```

---

### Step 1.8: Configure PubSub for Destroy Action

**File**: `lib/xeno/files/directory.ex`

**What to do**:

1. Add destroy action if not present: `destroy :destroy`
2. Add to `pub_sub` block: `publish :destroy, "destroyed"`

**Expected result**: ✅ Test from 1.7 passes

**How to verify manually**:

```elixir
# In IEx
Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:destroyed")
dir = Xeno.Files.Directory.create!(%{name: "test", path: "/test"})
Xeno.Files.Directory.destroy!(dir)
flush()
```

---

### Phase 1 Checkpoint ✅ COMPLETE

**Implementation Date**: 2025-11-09

**What we have now**:

- ✅ All Directory CRUD operations broadcast to PubSub
- ✅ Per-action topics configured (`directory:created`, `directory:updated`, `directory:moved`, `directory:destroyed`)
- ✅ All broadcasts tested in dedicated test file: `test/xeno/files/directory_pubsub_test.exs`
- ✅ Code interface functions added: `Directory.update!/2`, `Directory.move!/2`, `Directory.destroy!/1`
- ✅ Tests use ID pinning pattern to prevent flakiness in async execution
- ✅ Verified descendant directories don't trigger notifications during move operations
- ✅ Can manually verify in IEx

**Implementation Notes**:

1. **Event names**: Move action broadcasts with `event: "move"` (not "update" as originally planned)
2. **Test organization**: Tests moved to separate file for better organization
3. **Async testing**: Tests remain async with ID pinning pattern:
   - Uses `System.unique_integer/1` for unique directory names
   - Extracts IDs into variables before pattern matching
   - Uses pin operator `^` to match only expected notifications
4. **Descendants**: Confirmed that moving a directory only broadcasts for the explicitly moved directory, not its descendants

**What we can test**:

```elixir
# Full manual test in IEx
Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")
Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:updated")
Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:moved")
Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:destroyed")

# Try operations
dir = Xeno.Files.Directory.create!(%{name: "test", path: "/test"})
Xeno.Files.Directory.update!(dir, %{name: "changed"})
parent = Xeno.Files.Directory.create!(%{name: "parent", path: "/parent"})
Xeno.Files.Directory.move!(dir, parent)
Xeno.Files.Directory.destroy!(dir)

flush() # See all 4 messages
```

**Files Modified in Phase 1**:

1. `lib/xeno/files/directory.ex`
   - Added `notifiers: [Ash.Notifier.PubSub]` to resource declaration
   - Added complete `pub_sub` block with 4 publish directives
   - Added code_interface functions: `define :update`, `define :move`, `define :destroy`

2. `test/xeno/files/directory_pubsub_test.exs` (NEW FILE)
   - Created dedicated test file for PubSub notifications
   - 5 tests total: create, update, move, destroy, and descendants test
   - Uses ID pinning pattern for async execution

**Test Results**:
- ✅ 5 PubSub tests, 0 failures
- ✅ 48 total directory tests, 0 failures
- ✅ Verified stable over multiple runs with different seeds
- ✅ Tests run async (fast)

**Ready for Phase 2**: Yes! PubSub infrastructure is complete and tested.

---

## Phase 2: Smart Tree Update Functions

### Step 2.1: Test Find Root Ancestor Function

**File**: `test/xeno/files/directory/tree_test.exs` (new file)

**What to do**:

1. Create new test file for Tree module
2. Write test: `test "find_root_ancestor/1 returns the root directory for a nested directory"`
3. Create a tree: `/root/child/grandchild`
4. Assert that `find_root_ancestor(grandchild)` returns root
5. Assert that `find_root_ancestor(root)` returns root

**Expected result**: ❌ Test fails - function doesn't exist yet

**Code example**:

```elixir
defmodule Xeno.Files.Directory.TreeTest do
  use Xeno.DataCase
  alias Xeno.Files.Directory
  alias Xeno.Files.Directory.Tree

  describe "find_root_ancestor/1" do
    test "returns the root directory for a nested directory" do
      root = Directory.create!(%{name: "root", path: "/root"})
      child = Directory.create!(%{name: "child", path: "/root/child"})
      grandchild = Directory.create!(%{name: "grandchild", path: "/root/child/grandchild"})

      assert Tree.find_root_ancestor(grandchild).id == root.id
      assert Tree.find_root_ancestor(child).id == root.id
      assert Tree.find_root_ancestor(root).id == root.id
    end

    test "returns the directory itself if it's already a root" do
      root = Directory.create!(%{name: "root", path: "/root"})

      assert Tree.find_root_ancestor(root).id == root.id
    end

    test "handles multiple root trees" do
      root1 = Directory.create!(%{name: "root1", path: "/root1"})
      child1 = Directory.create!(%{name: "child1", path: "/root1/child1"})

      root2 = Directory.create!(%{name: "root2", path: "/root2"})
      child2 = Directory.create!(%{name: "child2", path: "/root2/child2"})

      assert Tree.find_root_ancestor(child1).id == root1.id
      assert Tree.find_root_ancestor(child2).id == root2.id
    end
  end
end
```

---

### Step 2.2: Implement Find Root Ancestor Function

**File**: `lib/xeno/files/directory/tree.ex`

**What to do**:

1. Add function: `find_root_ancestor/1`
2. Load the directory with parent relationship
3. Recursively traverse up to find root (parent is nil)
4. Return the root directory

**Expected result**: ✅ Test from 2.1 passes

**How to verify manually**:

```elixir
# In IEx
root = Xeno.Files.Directory.create!(%{name: "root", path: "/root"})
child = Xeno.Files.Directory.create!(%{name: "child", path: "/root/child"})
grandchild = Xeno.Files.Directory.create!(%{name: "gc", path: "/root/child/gc"})

Xeno.Files.Directory.Tree.find_root_ancestor(grandchild)
# Should return root directory
```

**Code example**:

```elixir
def find_root_ancestor(%Directory{} = directory) do
  directory = Ash.load!(directory, :parent)
  do_find_root_ancestor(directory)
end

defp do_find_root_ancestor(%Directory{parent: nil} = directory), do: directory
defp do_find_root_ancestor(%Directory{parent: parent}) do
  parent = Ash.load!(parent, :parent)
  do_find_root_ancestor(parent)
end
```

---

### Step 2.3: Test Build Single Branch Function

**File**: `test/xeno/files/directory/tree_test.exs`

**What to do**:

1. Add test: `test "build_branch/1 builds tree for a single root directory"`
2. Create a tree structure under one root
3. Call `build_branch(root_id)`
4. Assert returned structure matches expected nested tuples
5. Verify children are nested correctly

**Expected result**: ❌ Test fails - function doesn't exist yet

**Code example**:

```elixir
describe "build_branch/1" do
  test "builds tree for a single root directory and its descendants" do
    root = Directory.create!(%{name: "root", path: "/root"})
    child1 = Directory.create!(%{name: "child1", path: "/root/child1"})
    child2 = Directory.create!(%{name: "child2", path: "/root/child2"})
    grandchild = Directory.create!(%{name: "gc", path: "/root/child1/gc"})

    branch = Tree.build_branch(root.id)

    # Should be a single root tuple with nested children
    assert {root_dir, children} = branch
    assert root_dir.id == root.id
    assert length(children) == 2

    # Find child1 in children
    {child1_dir, child1_children} = Enum.find(children, fn {d, _} -> d.id == child1.id end)
    assert length(child1_children) == 1

    {gc_dir, gc_children} = List.first(child1_children)
    assert gc_dir.id == grandchild.id
    assert gc_children == []
  end

  test "handles root with no children" do
    root = Directory.create!(%{name: "lonely", path: "/lonely"})

    assert {root_dir, []} = Tree.build_branch(root.id)
    assert root_dir.id == root.id
  end
end
```

---

### Step 2.4: Implement Build Single Branch Function

**File**: `lib/xeno/files/directory/tree.ex`

**What to do**:

1. Add function: `build_branch/1` that takes a directory ID
2. Query for the root directory and all its descendants
3. Use same algorithm as `build/0` but filtered to this root
4. Return single tuple instead of list

**Expected result**: ✅ Test from 2.3 passes

**How to verify manually**:

```elixir
# In IEx
root = Xeno.Files.Directory.create!(%{name: "root", path: "/root"})
Xeno.Files.Directory.create!(%{name: "child", path: "/root/child"})
Xeno.Files.Directory.Tree.build_branch(root.id)
# Should return nested tuple structure
```

**Code example**:

```elixir
def build_branch(root_id) when is_binary(root_id) do
  # Get root directory
  root = Directory.get!(root_id)

  # Get all descendants
  descendants = Directory.descendants_of!(root)

  # Build tree using same algorithm as build/0 but for this subset
  all_dirs = [root | descendants]
  build_tree_from_list(all_dirs)
  |> List.first() # Return just the single root branch
end

# Extract common tree building logic
defp build_tree_from_list(directories) do
  # Same logic as build/0 but parameterized
  # ... (extract from existing build/0 implementation)
end
```

---

### Step 2.5: Test Update Tree Function

**File**: `test/xeno/files/directory/tree_test.exs`

**What to do**:

1. Add test: `test "update_tree/3 replaces a branch in the tree"`
2. Create two root trees
3. Build initial full tree
4. Modify one root's branch
5. Call `update_tree(tree, root_id, new_branch)`
6. Assert tree has updated branch and other branches unchanged

**Expected result**: ❌ Test fails - function doesn't exist yet

**Code example**:

```elixir
describe "update_tree/3" do
  test "replaces a branch in the tree with updated branch" do
    root1 = Directory.create!(%{name: "root1", path: "/root1"})
    child1 = Directory.create!(%{name: "child1", path: "/root1/child1"})

    root2 = Directory.create!(%{name: "root2", path: "/root2"})
    child2 = Directory.create!(%{name: "child2", path: "/root2/child2"})

    original_tree = Tree.build()

    # Update root1's branch (rebuild it)
    new_branch = Tree.build_branch(root1.id)

    updated_tree = Tree.update_tree(original_tree, root1.id, new_branch)

    # Should have same number of roots
    assert length(updated_tree) == 2

    # Root1 branch should be the new one
    {updated_root1, _} = Enum.find(updated_tree, fn {d, _} -> d.id == root1.id end)
    assert updated_root1.id == root1.id

    # Root2 should be unchanged (same object reference)
    {unchanged_root2, _} = Enum.find(original_tree, fn {d, _} -> d.id == root2.id end)
    {result_root2, _} = Enum.find(updated_tree, fn {d, _} -> d.id == root2.id end)
    assert unchanged_root2 == result_root2
  end

  test "handles updating when root doesn't exist in tree" do
    root1 = Directory.create!(%{name: "root1", path: "/root1"})
    root2 = Directory.create!(%{name: "root2", path: "/root2"})

    tree = Tree.build()

    # Create a new root that wasn't in original tree
    root3 = Directory.create!(%{name: "root3", path: "/root3"})
    new_branch = Tree.build_branch(root3.id)

    updated_tree = Tree.update_tree(tree, root3.id, new_branch)

    # Should have 3 roots now
    assert length(updated_tree) == 3
  end
end
```

---

### Step 2.6: Implement Update Tree Function

**File**: `lib/xeno/files/directory/tree.ex`

**What to do**:

1. Add function: `update_tree/3` takes (tree, root_id, new_branch)
2. Find and replace the branch with matching root_id
3. If not found, append the new branch
4. Return updated tree

**Expected result**: ✅ Test from 2.5 passes

**How to verify manually**:

```elixir
# In IEx
root1 = Xeno.Files.Directory.create!(%{name: "r1", path: "/r1"})
root2 = Xeno.Files.Directory.create!(%{name: "r2", path: "/r2"})
tree = Xeno.Files.Directory.Tree.build()
new_branch = Xeno.Files.Directory.Tree.build_branch(root1.id)
updated = Xeno.Files.Directory.Tree.update_tree(tree, root1.id, new_branch)
# Should have updated tree
```

**Code example**:

```elixir
def update_tree(tree, root_id, new_branch) do
  case Enum.find_index(tree, fn {dir, _children} -> dir.id == root_id end) do
    nil ->
      # Root not in tree, append it
      tree ++ [new_branch]

    index ->
      # Replace at index
      List.replace_at(tree, index, new_branch)
  end
end
```

---

### Phase 2 Checkpoint ✅ COMPLETE

**Implementation Date**: 2025-11-10

**What we have now**:

- ✅ Pure function to find root ancestor of any directory (ltree-optimized)
- ✅ Pure function to build a single branch (ltree-optimized)
- ✅ Pure function to update tree with new branch (preserves object identity)
- ✅ All functions unit tested (9 new tests)
- ✅ Functions can be tested independently in IEx
- ✅ All tests passing (76 total tests, 0 failures)

**Implementation Notes**:

1. **Ltree Optimization Discovery**: `find_root_ancestor/1` uses O(1) ltree path extraction instead of O(depth) recursive parent loading (ADR-006)
2. **Code Interface Extensions**: Added `Directory.get!/1` and `Directory.descendants_of!/1` to code interface
3. **Refactoring**: `build_branch/1` uses `descendants` relationship for simpler implementation
4. **Performance**: For deeply nested directories (10 levels), saves 9 database queries vs. original approach

**What we can test**:

```elixir
# Complete manual test
alias Xeno.Files.Directory
alias Xeno.Files.Directory.Tree

# Create test structure
root1 = Directory.create!("r1")
child1 = Directory.create!("r1/c1")
root2 = Directory.create!("r2")

# Test functions with ltree optimizations
Tree.find_root_ancestor(child1) # => root1 (O(1) query!)
Tree.build_branch(root1.id) # => {root1, [{child1, []}]}
tree = Tree.build() # => full tree
Tree.update_tree(tree, root1.id, Tree.build_branch(root1.id)) # => updated tree
```

**Files Modified in Phase 2**:

1. `lib/xeno/files/directory.ex`
   - Added `define :get, action: :read, get_by: [:id]` to code interface
   - Added `define :descendants_of, args: [:parent]` to code interface

2. `lib/xeno/files/directory/tree.ex`
   - Added `find_root_ancestor/1` with ltree optimization (~45 lines with docs)
   - Added `build_branch/1` leveraging ltree descendants (~50 lines with docs)
   - Added `update_tree/3` for efficient tree updates (~50 lines with docs)
   - Refactored `map_directories_by_path/2` to support optional transformation function

3. `test/xeno/files/directory/tree_test.exs`
   - Added 9 new tests across 3 describe blocks
   - Tests cover all three functions comprehensively
   - Total tree tests: 11 (2 existing + 9 new)

**Test Results**:
- ✅ 9 new Phase 2 tests, 0 failures
- ✅ 11 total tree tests, 0 failures
- ✅ 76 total project tests, 0 failures
- ✅ All tests run async (fast execution)

**Ready for Phase 3**: Yes! Smart tree functions are complete, tested, and optimized.

---

## Phase 3: LiveView Integration

### Step 3.1: Create InfoLive Test File

**File**: `test/xeno_web/live/info_live_test.exs` (new file)

**What to do**:

1. Create new test file
2. Add basic setup with `use XenoWeb.ConnCase`
3. Import `Phoenix.LiveViewTest`
4. Add test: `test "renders directory tree on initial load"`
5. Create some test directories
6. Connect to LiveView
7. Assert tree elements are present

**Expected result**: ✅ Test passes (testing existing behavior)

**Code example**:

```elixir
defmodule XenoWeb.InfoLiveTest do
  use XenoWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Xeno.Files.Directory

  describe "mount" do
    test "renders directory tree on initial load", %{conn: conn} do
      # Create test directories
      root = Directory.create!(%{name: "docs", path: "/docs"})
      _child = Directory.create!(%{name: "guides", path: "/docs/guides"})

      {:ok, view, _html} = live(conn, ~p"/info")

      # Should show the directory names
      assert has_element?(view, "details", "docs")
      assert has_element?(view, "details", "guides")
    end

    test "shows empty state when no directories exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/info")

      # Should render without error even with no directories
      assert html =~ "Notes Directory"
    end
  end
end
```

---

### Step 3.2: Test Auto-Refresh on Directory Create

**File**: `test/xeno_web/live/info_live_test.exs`

**What to do**:

1. Add test: `test "automatically shows new directory when created"`
2. Connect to LiveView
3. Assert new directory not present initially
4. Create a directory (will trigger PubSub)
5. Assert new directory appears in the view

**Expected result**: ❌ Test fails - no subscription in LiveView yet

**Code example**:

```elixir
describe "auto-refresh" do
  test "automatically shows new directory when created", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/info")

    # Initially no directory
    refute has_element?(view, "details", "new-dir")

    # Create directory (triggers PubSub broadcast)
    _new_dir = Directory.create!(%{name: "new-dir", path: "/new-dir"})

    # Should automatically appear in the tree
    assert has_element?(view, "details", "new-dir")
  end

  test "shows new nested directory under correct parent", %{conn: conn} do
    root = Directory.create!(%{name: "root", path: "/root"})

    {:ok, view, _html} = live(conn, ~p"/info")

    # Create child (triggers PubSub broadcast)
    _child = Directory.create!(%{name: "child", path: "/root/child"})

    # Should appear nested under root
    assert has_element?(view, "details", "root")
    assert has_element?(view, "details", "child")
  end
end
```

---

### Step 3.3: Add PubSub Subscription to InfoLive

**File**: `lib/xeno_web/live/info_live.ex`

**What to do**:

1. In `mount/3`, check `if connected?(socket)`
2. Subscribe to `"directory:created"` topic
3. Keep existing tree building logic

**Expected result**: ⚠️ Test still fails - no handler for messages yet

**Code example**:

```elixir
def mount(_params, _session, socket) do
  notes_dir = Xeno.notes_dir()
  dirs = Directory.Tree.build()

  # Subscribe to directory changes
  if connected?(socket) do
    Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")
  end

  {:ok, assign(socket, notes_dir: notes_dir, directories: dirs)}
end
```

---

### Step 3.4: Add Handler for Directory Created

**File**: `lib/xeno_web/live/info_live.ex`

**What to do**:

1. Add `handle_info/2` for `%Phoenix.Socket.Broadcast{topic: "directory:created"}`
2. Extract directory ID from payload
3. Find root ancestor of created directory
4. Rebuild that branch
5. Update tree with new branch
6. Return updated socket

**Expected result**: ✅ Test from 3.2 passes

**How to verify manually**:

1. Start server: `iex -S mix phx.server`
2. Open browser to `/info`
3. In IEx: `Xeno.Files.Directory.create!(%{name: "test", path: "/test"})`
4. Watch browser - new directory should appear

**Code example**:

```elixir
def handle_info(
      %Phoenix.Socket.Broadcast{
        topic: "directory:created",
        payload: %{data: created_dir}
      },
      socket
    ) do
  # Find which root this directory belongs to
  root = Directory.Tree.find_root_ancestor(created_dir)

  # Rebuild just that branch
  new_branch = Directory.Tree.build_branch(root.id)

  # Update the tree
  updated_tree = Directory.Tree.update_tree(socket.assigns.directories, root.id, new_branch)

  {:noreply, assign(socket, directories: updated_tree)}
end
```

---

### Step 3.5: Test Auto-Refresh on Directory Update

**File**: `test/xeno_web/live/info_live_test.exs`

**What to do**:

1. Add test: `test "automatically updates directory name when changed"`
2. Create a directory
3. Connect to LiveView
4. Update directory name
5. Assert new name appears in view

**Expected result**: ❌ Test fails - no subscription to updated topic yet

**Code example**:

```elixir
test "automatically updates directory name when changed", %{conn: conn} do
  directory = Directory.create!(%{name: "old-name", path: "/old-name"})

  {:ok, view, _html} = live(conn, ~p"/info")
  assert has_element?(view, "details", "old-name")

  # Update directory (triggers PubSub broadcast)
  Directory.update!(directory, %{name: "new-name"})

  # Should show updated name
  refute has_element?(view, "details", "old-name")
  assert has_element?(view, "details", "new-name")
end
```

---

### Step 3.6: Add Subscription and Handler for Updates

**File**: `lib/xeno_web/live/info_live.ex`

**What to do**:

1. Add subscription to `"directory:updated"` in mount
2. Add `handle_info/2` for updated events (same logic as created)

**Expected result**: ✅ Test from 3.5 passes

**Code example**:

```elixir
# In mount/3
if connected?(socket) do
  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")
  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:updated")
end

# New handler
def handle_info(
      %Phoenix.Socket.Broadcast{
        topic: "directory:updated",
        payload: %{data: updated_dir}
      },
      socket
    ) do
  root = Directory.Tree.find_root_ancestor(updated_dir)
  new_branch = Directory.Tree.build_branch(root.id)
  updated_tree = Directory.Tree.update_tree(socket.assigns.directories, root.id, new_branch)

  {:noreply, assign(socket, directories: updated_tree)}
end
```

---

### Step 3.7: Test Auto-Refresh on Directory Move

**File**: `test/xeno_web/live/info_live_test.exs`

**What to do**:

1. Add test: `test "automatically updates tree when directory is moved"`
2. Create two root directories
3. Create child under root1
4. Connect to LiveView
5. Move child from root1 to root2
6. Assert child now appears under root2

**Expected result**: ❌ Test fails - move requires updating TWO branches

**Code example**:

```elixir
test "automatically updates tree when directory is moved", %{conn: conn} do
  root1 = Directory.create!(%{name: "root1", path: "/root1"})
  root2 = Directory.create!(%{name: "root2", path: "/root2"})
  child = Directory.create!(%{name: "child", path: "/root1/child"})

  {:ok, view, _html} = live(conn, ~p"/info")

  # Child should be under root1
  assert has_element?(view, "details", "child")

  # Move to root2 (triggers PubSub broadcast)
  Directory.move!(child, root2)

  # Tree should update to show child under root2
  # This requires checking the actual nesting in HTML
  assert has_element?(view, "details", "child")
  # Additional assertions about parent-child relationship would go here
end
```

---

### Step 3.8: Handle Directory Move (Two Branches)

**File**: `lib/xeno_web/live/info_live.ex`

**What to do**:

1. Add subscription to `"directory:moved"` in mount
2. Add special `handle_info/2` for moved events
3. Need to update BOTH old and new root branches
4. Requires tracking old path before move

**Expected result**: ⚠️ Complex - need to handle both branches

**Challenge**: How do we know which TWO roots to update?

- Current directory only tells us new location
- Need to rebuild both old and new root branches
- **Solution**: Rebuild affected roots based on notification data

**Note**: This step reveals a design challenge. We'll address it in next step.

---

### Step 3.9: Refine Move Handler Strategy

**Problem**: When a directory moves, we need to update two branches:

1. The old parent's root branch (to remove the directory)
2. The new parent's root branch (to add the directory)

**Solution Options**:

**Option A**: Include old path in PubSub payload (requires custom notifier)
**Option B**: Rebuild all root branches (simpler but less efficient)
**Option C**: Rebuild both potentially affected roots by checking notification metadata

**Decision**: Use Option B for now (simplest), can optimize later

**File**: `lib/xeno_web/live/info_live.ex`

**What to do**:

1. Add subscription to `"directory:moved"`
2. Add handler that rebuilds entire tree on move
3. Comment explaining this is a simplification

**Expected result**: ✅ Test from 3.7 passes

**Code example**:

```elixir
# In mount/3
if connected?(socket) do
  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")
  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:updated")
  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:moved")
end

# Handler for moved directories
def handle_info(
      %Phoenix.Socket.Broadcast{topic: "directory:moved"},
      socket
    ) do
  # When a directory moves, we need to update both the old and new parent branches.
  # For simplicity, we rebuild the entire tree. This can be optimized later
  # by tracking old paths or using change metadata.
  updated_tree = Directory.Tree.build()

  {:noreply, assign(socket, directories: updated_tree)}
end
```

---

### Step 3.10: Test Auto-Refresh on Directory Destroy

**File**: `test/xeno_web/live/info_live_test.exs`

**What to do**:

1. Add test: `test "automatically removes directory when destroyed"`
2. Create a directory
3. Connect to LiveView - assert present
4. Destroy directory
5. Assert directory no longer appears

**Expected result**: ❌ Test fails - no destroy subscription yet

**Code example**:

```elixir
test "automatically removes directory when destroyed", %{conn: conn} do
  directory = Directory.create!(%{name: "temp", path: "/temp"})

  {:ok, view, _html} = live(conn, ~p"/info")
  assert has_element?(view, "details", "temp")

  # Destroy directory (triggers PubSub broadcast)
  Directory.destroy!(directory)

  # Should disappear from tree
  refute has_element?(view, "details", "temp")
end

test "removes nested directories when parent is destroyed", %{conn: conn} do
  root = Directory.create!(%{name: "root", path: "/root"})
  _child = Directory.create!(%{name: "child", path: "/root/child"})

  {:ok, view, _html} = live(conn, ~p"/info")

  # Destroy root (should also remove child from tree)
  Directory.destroy!(root)

  # Both should disappear
  refute has_element?(view, "details", "root")
  refute has_element?(view, "details", "child")
end
```

---

### Step 3.11: Add Subscription and Handler for Destroy

**File**: `lib/xeno_web/live/info_live.ex`

**What to do**:

1. Add subscription to `"directory:destroyed"`
2. Add handler - need to find root of destroyed directory
3. Rebuild that branch (directory will be gone)

**Challenge**: The destroyed directory no longer exists in DB!

- Can't call `find_root_ancestor` on deleted data
- Can't query for descendants

**Solution**: Extract parent info from payload before it's destroyed, OR rebuild entire tree

**For simplicity**: Rebuild entire tree on destroy

**Expected result**: ✅ Test from 3.10 passes

**Code example**:

```elixir
# In mount/3
if connected?(socket) do
  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:created")
  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:updated")
  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:moved")
  Phoenix.PubSub.subscribe(Xeno.PubSub, "directory:destroyed")
end

# Handler for destroyed directories
def handle_info(
      %Phoenix.Socket.Broadcast{topic: "directory:destroyed"},
      socket
    ) do
  # When a directory is destroyed, we can't query for its parent since it's gone.
  # Rebuild the entire tree. This can be optimized later by including parent info
  # in the notification payload.
  updated_tree = Directory.Tree.build()

  {:noreply, assign(socket, directories: updated_tree)}
end
```

---

### Phase 3 Checkpoint ✓

**What we have now**:

- ✅ InfoLive subscribes to all directory change topics
- ✅ Auto-refresh on create (smart update)
- ✅ Auto-refresh on update (smart update)
- ✅ Auto-refresh on move (full rebuild)
- ✅ Auto-refresh on destroy (full rebuild)
- ✅ All scenarios tested
- ✅ Can test manually in browser + IEx

**What we can test**:

1. Start server: `iex -S mix phx.server`
2. Open browser to `http://localhost:4000/info`
3. In IEx, run:

   ```elixir
   # Create
   d = Xeno.Files.Directory.create!(%{name: "test", path: "/test"})
   # Watch it appear in browser

   # Update
   Xeno.Files.Directory.update!(d, %{name: "updated"})
   # Watch name change in browser

   # Destroy
   Xeno.Files.Directory.destroy!(d)
   # Watch it disappear in browser
   ```

---

## Phase 4: Refinement & Optimization

### Step 4.1: Refactor Common Handler Logic

**File**: `lib/xeno_web/live/info_live.ex`

**What to do**:

1. Extract common tree update logic into private function
2. DRY up the created/updated handlers
3. Add documentation

**Expected result**: ✅ All existing tests still pass

**Code example**:

```elixir
# Refactored handlers
def handle_info(
      %Phoenix.Socket.Broadcast{
        topic: "directory:created",
        payload: %{data: directory}
      },
      socket
    ) do
  {:noreply, update_directory_branch(socket, directory)}
end

def handle_info(
      %Phoenix.Socket.Broadcast{
        topic: "directory:updated",
        payload: %{data: directory}
      },
      socket
    ) do
  {:noreply, update_directory_branch(socket, directory)}
end

def handle_info(%Phoenix.Socket.Broadcast{topic: "directory:moved"}, socket) do
  {:noreply, rebuild_entire_tree(socket)}
end

def handle_info(%Phoenix.Socket.Broadcast{topic: "directory:destroyed"}, socket) do
  {:noreply, rebuild_entire_tree(socket)}
end

# Private helpers
defp update_directory_branch(socket, directory) do
  root = Directory.Tree.find_root_ancestor(directory)
  new_branch = Directory.Tree.build_branch(root.id)
  updated_tree = Directory.Tree.update_tree(socket.assigns.directories, root.id, new_branch)
  assign(socket, directories: updated_tree)
end

defp rebuild_entire_tree(socket) do
  assign(socket, directories: Directory.Tree.build())
end
```

---

### Step 4.2: Add Test for Multiple Clients

**File**: `test/xeno_web/live/info_live_test.exs`

**What to do**:

1. Add test: `test "updates all connected clients"`
2. Connect two separate LiveView sessions
3. Create directory
4. Assert both views update

**Expected result**: ✅ Should pass (PubSub broadcasts to all)

**Code example**:

```elixir
test "updates all connected clients when directory is created", %{conn: conn} do
  # Connect two clients
  {:ok, view1, _html} = live(conn, ~p"/info")
  {:ok, view2, _html} = live(conn, ~p"/info")

  # Create directory
  _dir = Directory.create!(%{name: "shared", path: "/shared"})

  # Both views should show the new directory
  assert has_element?(view1, "details", "shared")
  assert has_element?(view2, "details", "shared")
end
```

---

### Step 4.3: Test Edge Case - Rapid Changes

**File**: `test/xeno_web/live/info_live_test.exs`

**What to do**:

1. Add test: `test "handles rapid successive changes"`
2. Create multiple directories in quick succession
3. Assert all appear correctly

**Expected result**: ✅ Should pass

**Code example**:

```elixir
test "handles rapid successive directory creations", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/info")

  # Create multiple directories rapidly
  _d1 = Directory.create!(%{name: "dir1", path: "/dir1"})
  _d2 = Directory.create!(%{name: "dir2", path: "/dir2"})
  _d3 = Directory.create!(%{name: "dir3", path: "/dir3"})

  # All should appear
  assert has_element?(view, "details", "dir1")
  assert has_element?(view, "details", "dir2")
  assert has_element?(view, "details", "dir3")
end
```

---

### Step 4.4: Optimize Move Handler (Optional)

**Goal**: Make move operations update only affected branches instead of full rebuild

**File**: `lib/xeno/files/directory/tree.ex`

**What to do**:

1. Add `find_affected_roots/2` function
2. Takes old and new directory states
3. Returns list of root IDs that need updating

**This is an optimization step - can be skipped if performance is acceptable**

---

### Step 4.5: Add Logging for Debugging

**File**: `lib/xeno_web/live/info_live.ex`

**What to do**:

1. Add require `Logger`
2. Add debug logs in handlers
3. Can be disabled in production

**Expected result**: ✅ All tests pass, logs appear in dev

**Code example**:

```elixir
require Logger

def handle_info(
      %Phoenix.Socket.Broadcast{topic: topic, payload: payload},
      socket
    ) do
  Logger.debug("InfoLive received PubSub: #{topic} - #{inspect(payload)}")
  # ... existing handler logic
end
```

---

### Step 4.6: Add Documentation

**Files**:

- `lib/xeno/files/directory.ex`
- `lib/xeno/files/directory/tree.ex`
- `lib/xeno_web/live/info_live.ex`

**What to do**:

1. Add module docs explaining PubSub integration
2. Add function docs for public functions
3. Add examples

**Expected result**: Better code maintainability

---

### Phase 4 Checkpoint ✓

**What we have now**:

- ✅ Refactored, DRY code
- ✅ Edge cases tested
- ✅ Multiple client support verified
- ✅ Optional optimizations identified
- ✅ Debug logging for troubleshooting
- ✅ Documentation

---

## Final Testing Checklist

### Manual Testing Script

```elixir
# In iex -S mix phx.server
# Open browser to localhost:4000/info

# Test 1: Create root directory
d1 = Xeno.Files.Directory.create!(%{name: "test-root", path: "/test-root"})
# ✓ Should appear in browser

# Test 2: Create nested directory
d2 = Xeno.Files.Directory.create!(%{name: "child", path: "/test-root/child"})
# ✓ Should appear nested under test-root

# Test 3: Update directory
Xeno.Files.Directory.update!(d2, %{name: "renamed-child"})
# ✓ Should see name change from "child" to "renamed-child"

# Test 4: Create another root
d3 = Xeno.Files.Directory.create!(%{name: "other-root", path: "/other-root"})
# ✓ Should appear as separate root

# Test 5: Move directory
Xeno.Files.Directory.move!(d2, d3)
# ✓ renamed-child should move from test-root to other-root

# Test 6: Destroy directory
Xeno.Files.Directory.destroy!(d2)
# ✓ renamed-child should disappear

# Test 7: Destroy root with children
Xeno.Files.Directory.create!(%{name: "gc", path: "/other-root/gc"})
Xeno.Files.Directory.destroy!(d3)
# ✓ other-root and gc should both disappear

# Cleanup
Xeno.Files.Directory.destroy!(d1)
```

### Automated Test Run

```bash
# Run all directory tests
mix test test/xeno/files/directory_test.exs

# Run tree tests
mix test test/xeno/files/directory/tree_test.exs

# Run InfoLive tests
mix test test/xeno_web/live/info_live_test.exs

# Run all tests
mix test
```

---

## Rollback Strategy

If issues arise at any step:

### Rollback Phase 3 (LiveView)

```bash
git checkout lib/xeno_web/live/info_live.ex
git checkout test/xeno_web/live/info_live_test.exs
```

### Rollback Phase 2 (Tree Functions)

```bash
git checkout lib/xeno/files/directory/tree.ex
git checkout test/xeno/files/directory/tree_test.exs
```

### Rollback Phase 1 (PubSub)

```bash
git checkout lib/xeno/files/directory.ex
git checkout test/xeno/files/directory_test.exs
```

---

## Performance Considerations

### Current Approach

- Create/Update: Smart update (rebuild 1 branch)
- Move/Destroy: Full rebuild (rebuild entire tree)

### Expected Performance

- For trees with < 1000 directories: Full rebuild is fast enough
- For trees with > 1000 directories: May need optimization

### Future Optimizations

1. Include parent_id in destroy payload to enable smart updates
2. Track old path in move operations for smart updates
3. Use LiveView streams instead of assigns for very large trees
4. Add debouncing for rapid changes

---

## Success Criteria

- ✅ All tests pass
- ✅ Manual browser testing confirms auto-refresh
- ✅ Multiple clients update simultaneously
- ✅ No errors in logs
- ✅ Tree structure remains consistent
- ✅ Changes are immediate (< 100ms latency)

---

## Estimated Time

- Phase 1: 30-45 minutes
- Phase 2: 45-60 minutes
- Phase 3: 60-90 minutes
- Phase 4: 30-45 minutes

**Total**: 2.5 - 4 hours for complete TDD implementation

---

## Notes

- Each step can be committed independently
- Tests can run after each step
- Feature can be tested manually at each phase checkpoint
- Rollback is possible at any point
- No database migrations required
- No frontend JavaScript required (pure LiveView)
