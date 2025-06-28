defmodule Terminalphx.FileSystem do
  @moduledoc """
  The FileSystem context.
  """

  import Ecto.Query, warn: false
  alias Terminalphx.Repo
  alias Terminalphx.FileSystem.Node

  @default_cwd "/home"

  @doc """
  Returns the list of nodes.
  """
  def list_nodes do
    Repo.all(Node)
  end

  @doc """
  Gets a single node.
  """
  def get_node!(id), do: Repo.get!(Node, id)

  @doc """
  Gets a node by path.
  """
  def get_node_by_path(path) do
    Repo.get_by(Node, path: path)
  end

  @doc """
  Creates a node.
  """
  def create_node(attrs \\ %{}) do
    %Node{}
    |> Node.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a node.
  """
  def update_node(%Node{} = node, attrs) do
    node
    |> Node.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a node and all its children.
  """
  def delete_node(%Node{} = node) do
    # Delete children first
    children = list_children(node.path)
    Enum.each(children, &delete_node/1)

    Repo.delete(node)
  end

  @doc """
  Lists files and directories in a given path.
  """
  def list_directory(path \\ @default_cwd) do
    normalized_path = normalize_path(path)

    from(n in Node,
      where: n.parent_id == subquery(
        from(p in Node, where: p.path == ^normalized_path, select: p.id)
      ),
      order_by: [asc: n.is_directory, asc: n.name]
    )
    |> Repo.all()
  end

  @doc """
  Lists all children of a path (recursive).
  """
  def list_children(path) do
    like_pattern = path <> "%"

    from(n in Node,
      where: like(n.path, ^like_pattern) and n.path != ^path
    )
    |> Repo.all()
  end

  @doc """
  Creates a file or directory with all necessary parent directories.
  """
  def touch(path, content \\ "") do
    normalized_path = normalize_path(path)

    case get_node_by_path(normalized_path) do
      nil ->
        # Create parent directories if they don't exist
        create_parent_directories(normalized_path)

        # Determine if it's a directory or file
        is_directory = String.ends_with?(path, "/") or not String.contains?(Path.basename(path), ".")

        parent_path = Path.dirname(normalized_path)
        parent = if parent_path == "/" or parent_path == normalized_path do
          nil
        else
          get_node_by_path(parent_path)
        end

        create_node(%{
          name: Path.basename(normalized_path),
          path: normalized_path,
          content: if(is_directory, do: nil, else: content),
          is_directory: is_directory,
          parent_id: if(parent, do: parent.id, else: nil)
        })

      _existing ->
        {:error, "File or directory already exists"}
    end
  end

  @doc """
  Reads the content of a file.
  """
  def cat(path) do
    normalized_path = normalize_path(path)

    case get_node_by_path(normalized_path) do
      nil -> {:error, "File not found"}
      %{is_directory: true} -> {:error, "Is a directory"}
      node -> {:ok, node.content || ""}
    end
  end

  @doc """
  Removes a file or directory.
  """
  def rm(path) do
    normalized_path = normalize_path(path)

    case get_node_by_path(normalized_path) do
      nil -> {:error, "File not found"}
      node -> delete_node(node)
    end
  end

  @doc """
  Changes the current working directory.
  """
  def cd(path \\ @default_cwd) do
    normalized_path = normalize_path(path)

    case get_node_by_path(normalized_path) do
      nil -> {:error, "Directory not found"}
      %{is_directory: false} -> {:error, "Not a directory"}
      node -> {:ok, node.path}
    end
  end

  @doc """
  Searches for files by name or content.
  """
  def search(query) do
    pattern = "%#{query}%"

    from(n in Node,
      where:
        ilike(n.name, ^pattern) or
        (not n.is_directory and ilike(n.content, ^pattern)),
      order_by: [asc: n.is_directory, asc: n.name]
    )
    |> Repo.all()
  end

  @doc """
  Initialize the file system with basic directories.
  """
  def initialize_filesystem do
    # Create root directory
    case get_node_by_path("/") do
      nil ->
        create_node(%{
          name: "/",
          path: "/",
          content: nil,
          is_directory: true,
          parent_id: nil
        })
      _ -> :ok
    end

    # Create home directory
    case get_node_by_path("/home") do
      nil ->
        root = get_node_by_path("/")
        create_node(%{
          name: "home",
          path: "/home",
          content: nil,
          is_directory: true,
          parent_id: root.id
        })
      _ -> :ok
    end

    # Create some sample files
    sample_files = [
      {"/home/welcome.txt", "Welcome to Terminal Phoenix!\nThis is a demo file system."},
      {"/home/readme.md", "# Terminal Phoenix\n\nA spotlight-like terminal interface built with Phoenix LiveView."},
      {"/home/config.json", ~s({"theme": "dark", "shell": "zsh"})}
    ]

    Enum.each(sample_files, fn {path, content} ->
      case get_node_by_path(path) do
        nil -> touch(path, content)
        _ -> :ok
      end
    end)
  end

  @doc """
  Lists files and directories recursively up to a specified nesting level.
  """
  def list_directory_recursive(path \\ @default_cwd, max_nesting \\ 2, current_level \\ 0) do
    normalized_path = normalize_path(path)

    files = from(n in Node,
      where: n.parent_id == subquery(
        from(p in Node, where: p.path == ^normalized_path, select: p.id)
      ),
      order_by: [asc: n.is_directory, asc: n.name]
    )
    |> Repo.all()

    if current_level < max_nesting do
      Enum.map(files, fn file ->
        if file.is_directory and current_level < max_nesting do
          children = list_directory_recursive(file.path, max_nesting, current_level + 1)
          Map.put(file, :children, children)
        else
          Map.put(file, :children, [])
        end
      end)
    else
      Enum.map(files, fn file -> Map.put(file, :children, []) end)
    end
  end

  # Private functions

  defp normalize_path(""), do: @default_cwd
  defp normalize_path("~"), do: @default_cwd
  defp normalize_path("/" <> _ = path), do: Path.expand(path)
  defp normalize_path(path), do: Path.expand(path, @default_cwd)

  defp create_parent_directories(path) do
    parent_path = Path.dirname(path)

    if parent_path != "/" and parent_path != path do
      case get_node_by_path(parent_path) do
        nil ->
          create_parent_directories(parent_path)

          grandparent_path = Path.dirname(parent_path)
          grandparent = if grandparent_path == "/" or grandparent_path == parent_path do
            get_node_by_path("/")
          else
            get_node_by_path(grandparent_path)
          end

          create_node(%{
            name: Path.basename(parent_path),
            path: parent_path,
            content: nil,
            is_directory: true,
            parent_id: if(grandparent, do: grandparent.id, else: nil)
          })

        _ -> :ok
      end
    end
  end
end
