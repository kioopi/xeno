defmodule Xeno.XenoTest do
  use ExUnit.Case, async: true

  test "notes_dir/0 returns the path directory containing the notes " do
    assert String.match?(Xeno.notes_dir(), ~r"test/notes")
  end

  test "notes_dir(path) joins notes_dir with path " do
    assert String.ends_with?(Xeno.notes_dir("hello/world"), "test/notes/hello/world")
  end
end
