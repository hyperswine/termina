defmodule TerminalphxWeb.TerminalLive do
  use TerminalphxWeb, :live_view

  alias Terminalphx.FileSystem

  @impl true
  def mount(_params, _session, socket) do
    # Initialize file system on first load
    FileSystem.initialize_filesystem()

    {:ok,
     socket
     |> assign(:modal_open, false)
     |> assign(:current_directory, "/home")
     |> assign(:command_input, "")  # Empty input, mode prefix is visual only
     |> assign(:command_history, [])
     |> assign(:search_results, [])
     |> assign(:mode, :search)  # :search, :shell, :help
     |> assign(:editor_open, false)
     |> assign(:editor_file_path, nil)
     |> assign(:editor_content, "")
     |> assign(:pane_results, [])  # This will now be a list of results
     |> assign(:pane_history, [])  # Track history of pane results
     |> assign(:last_command, "")
     |> assign(:last_search, "")
     |> assign(:last_search, "")
     |> assign(:key_history, [])
     |> assign(:show_key_visualizer, false)
    }
  end

  @impl true
  def handle_event("toggle_modal", _, socket) do
    modal_open = !socket.assigns.modal_open

    socket =
      socket
      |> assign(:modal_open, modal_open)
      |> assign(:command_input, if(modal_open, do: "", else: ""))  # Empty input, mode prefix is visual
      |> assign(:mode, :search)
      |> assign(:search_results, [])
      |> assign(:pane_results, [])

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:modal_open, false)
     |> assign(:command_input, "")
     |> assign(:search_results, [])
     |> assign(:pane_results, [])
    }
  end

  @impl true
  def handle_event("input_change", %{"command" => command}, socket) do
    {mode, cleaned_command} = determine_mode_from_input(command, socket.assigns.mode)

    socket =
      socket
      |> assign(:command_input, cleaned_command)
      |> assign(:mode, mode)

    socket = case mode do
      :search when cleaned_command != "" ->
        results = FileSystem.search(cleaned_command)
        socket
        |> assign(:search_results, results)
        |> assign(:pane_results, [])

      :help when cleaned_command == "" ->
        socket
        |> assign(:search_results, get_help_options())
        |> assign(:pane_results, [])

      _ ->
        if mode != socket.assigns.mode do
          # Mode changed, clear results
          socket
          |> assign(:search_results, [])
          |> assign(:pane_results, [])
        else
          # Same mode, keep search results if they exist
          socket
        end
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("execute_command", %{"command" => command}, socket) do
    # For execution, we build the full command with prefix for history
    full_command = case socket.assigns.mode do
      :search -> ">" <> command
      :shell -> "$" <> command
      :help -> command
    end

    # But we execute using the current mode and clean command
    socket = case socket.assigns.mode do
      :search -> handle_search_command(command, socket)
      :shell -> handle_shell_command(command, socket)
      :help -> handle_help_command(command, socket)
    end

    # Add to history and reset input only if modal is still open
    history = [full_command | socket.assigns.command_history]

    final_socket = socket
    |> assign(:command_history, Enum.take(history, 10))

    # Only reset input if modal is still open, but preserve mode
    final_socket = if socket.assigns.modal_open do
      new_input = ""  # Clear input after execution

      final_socket
      |> assign(:command_input, new_input)
      # Don't reset mode - keep current mode
    else
      final_socket
    end

    {:noreply, final_socket}
  end

  @impl true
  def handle_event("close_editor", _, socket) do
    {:noreply,
     socket
     |> assign(:editor_open, false)
     |> assign(:editor_file_path, nil)
     |> assign(:editor_content, "")
     |> assign(:modal_open, true)  # Reopen modal when closing editor
     |> assign(:command_input, "")  # Empty input, mode prefix is visual
     |> assign(:mode, :search)
    }
  end

  @impl true
  def handle_event("save_file", %{"content" => content}, socket) do
    case socket.assigns.editor_file_path do
      nil -> {:noreply, socket}
      path ->
        case FileSystem.get_node_by_path(path) do
          nil -> {:noreply, socket}
          node ->
            FileSystem.update_node(node, %{content: content})
            {:noreply,
             socket
             |> assign(:editor_content, content)
             |> put_flash(:info, "File saved successfully")
            }
        end
    end
  end

  @impl true
  def handle_event("key_press", %{"key" => key}, socket) do
    # Add to key history for visualizer
    key_history = [key | socket.assigns[:key_history] || []] |> Enum.take(10)

    {:noreply, assign(socket, :key_history, key_history)}
  end

  @impl true
  def handle_event("toggle_key_visualizer", _, socket) do
    show = !socket.assigns.show_key_visualizer
    {:noreply, assign(socket, :show_key_visualizer, show)}
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    # Don't include mode prefix in input - it's shown visually
    {new_input, new_mode} = case mode do
      "search" -> {"", :search}
      "shell" -> {"", :shell}
      "help" -> {"", :help}
      _ -> {"", :search}
    end

    socket = socket
    |> assign(:command_input, new_input)
    |> assign(:mode, new_mode)

    # Set appropriate results based on mode
    socket = case new_mode do
      :help ->
        socket
        |> assign(:search_results, get_help_options())
        |> assign(:pane_results, [])
      _ ->
        socket
        |> assign(:search_results, [])
        |> assign(:pane_results, [])
    end

    {:noreply, socket}
  end

  # Private functions

  defp determine_mode_from_input(command, current_mode) do
    # Since mode prefixes are visual only, input never contains them
    # The mode is determined by current mode state, not input content
    cond do
      command == "" and current_mode == :help ->
        {:help, ""}
      command == "" ->
        # Empty input keeps current mode
        {current_mode, ""}
      true ->
        # Non-empty input stays in current mode
        {current_mode, command}
    end
  end

  defp handle_search_command(query, socket) when query != "" do
    results = FileSystem.search(query)

    socket
    |> assign(:search_results, results)
    |> assign(:last_search, query)
    |> assign(:pane_results, [])  # Clear shell results when searching
    # Keep modal open for search results
  end

  defp handle_search_command(_, socket) do
    # Clear search results for empty query but keep modal open
    socket
    |> assign(:search_results, [])
  end

  defp handle_shell_command(command, socket) do
    [cmd | args] = String.split(command, " ", trim: true)

    result = case cmd do
      "ls" -> handle_ls_command(args, socket)
      "cd" -> handle_cd_command(args, socket)
      "cat" -> handle_cat_command(args, socket)
      "show" -> handle_cat_command(args, socket)
      "rm" -> handle_rm_command(args, socket)
      "touch" -> handle_touch_command(args, socket)
      "edit" -> handle_edit_command(args, socket)
      _ -> {:error, "Command not found: #{cmd}"}
    end

    {socket, result} = case result do
      {:cd, new_path} ->
        updated_socket = assign(socket, :current_directory, new_path)
        {updated_socket, {:ok, %{type: :cd, path: new_path}}}
      _ -> {socket, result}
    end

    socket = case result do
      {:ok, data} ->
        # Add new result to the top of the pane_results list (limit to 5 results)
        new_pane_results = [data | socket.assigns.pane_results] |> Enum.take(5)
        socket
        |> assign(:pane_results, new_pane_results)
        |> assign(:search_results, [])  # Clear search results when showing shell results
        |> assign(:last_command, command)
        # Keep modal open to show results

      {:error, message} ->
        # Add error result to the top of the pane_results list (limit to 5 results)
        error_data = %{type: :message, content: "Error: #{message}"}
        new_pane_results = [error_data | socket.assigns.pane_results] |> Enum.take(5)
        socket
        |> assign(:pane_results, new_pane_results)
        |> assign(:last_command, command)
        # Keep modal open to show error

      {:edit, path, content} ->
        socket
        |> assign(:editor_open, true)
        |> assign(:editor_file_path, path)
        |> assign(:editor_content, content)
        |> assign(:modal_open, false)  # Only close modal for edit
    end

    socket
  end

  defp handle_help_command(_query, socket) do
    # Keep modal open for help and show help results
    socket
    |> assign(:search_results, get_help_options())
    |> assign(:pane_results, [])
  end

  defp handle_ls_command([], socket) do
    files = FileSystem.list_directory_recursive(socket.assigns.current_directory, 2)
    {:ok, %{type: :file_list_recursive, files: files, path: socket.assigns.current_directory, nesting: 2}}
  end

  defp handle_ls_command(args, socket) do
    {path, nesting} = parse_ls_args(args)
    abs_path = if path, do: resolve_path(path, socket.assigns.current_directory), else: socket.assigns.current_directory

    case FileSystem.cd(abs_path) do
      {:ok, _} ->
        files = FileSystem.list_directory_recursive(abs_path, nesting)
        {:ok, %{type: :file_list_recursive, files: files, path: abs_path, nesting: nesting}}
      {:error, msg} -> {:error, msg}
    end
  end

  # Parse ls arguments to extract path and nesting level
  defp parse_ls_args(args) do
    {nesting, remaining_args} = extract_nesting_arg(args, 2)
    path = case remaining_args do
      [] -> nil
      [p] -> p
      _ -> List.first(remaining_args)
    end
    {path, nesting}
  end

  defp extract_nesting_arg([], default), do: {default, []}
  defp extract_nesting_arg([arg | rest], default) do
    if String.starts_with?(arg, "--nesting=") do
      nesting_str = String.slice(arg, 10..-1//1)
      case Integer.parse(nesting_str) do
        {nesting, _} when nesting >= 0 -> {nesting, rest}
        _ -> {default, [arg | rest]}
      end
    else
      {nesting, remaining} = extract_nesting_arg(rest, default)
      {nesting, [arg | remaining]}
    end
  end

  defp handle_cd_command([], _socket) do
    {:cd, "/home"}
  end

  defp handle_cd_command([path], socket) do
    abs_path = resolve_path(path, socket.assigns.current_directory)
    case FileSystem.cd(abs_path) do
      {:ok, new_path} -> {:cd, new_path}
      {:error, msg} -> {:error, msg}
    end
  end

  defp handle_cat_command([path], socket) do
    abs_path = resolve_path(path, socket.assigns.current_directory)
    case FileSystem.cat(abs_path) do
      {:ok, content} -> {:ok, %{type: :file_content, content: content, path: abs_path}}
      {:error, msg} -> {:error, msg}
    end
  end

  defp handle_cat_command(_, _socket), do: {:error, "Usage: cat <file>"}

  defp handle_rm_command([path], socket) do
    abs_path = resolve_path(path, socket.assigns.current_directory)
    case FileSystem.rm(abs_path) do
      {:ok, _} -> {:ok, %{type: :message, content: "Removed #{abs_path}"}}
      {:error, msg} -> {:error, msg}
    end
  end

  defp handle_rm_command(_, _socket), do: {:error, "Usage: rm <file>"}

  defp handle_touch_command([path], socket) do
    abs_path = resolve_path(path, socket.assigns.current_directory)
    case FileSystem.touch(abs_path) do
      {:ok, _} -> {:ok, %{type: :message, content: "Created #{abs_path}"}}
      {:error, msg} -> {:error, msg}
    end
  end

  defp handle_touch_command(_, _socket), do: {:error, "Usage: touch <file>"}

  defp handle_edit_command([path], socket) do
    abs_path = resolve_path(path, socket.assigns.current_directory)

    # Check if it's a valid file path (must have an extension)
    case Path.extname(abs_path) do
      "" -> {:error, "edit command only works with files (must have an extension)"}
      _ ->
        case FileSystem.cat(abs_path) do
          {:ok, content} -> {:edit, abs_path, content}
          {:error, _} ->
            # Create file if it doesn't exist
            case FileSystem.touch(abs_path, "") do
              {:ok, _} -> {:edit, abs_path, ""}
              {:error, msg} -> {:error, msg}
            end
        end
    end
  end

  defp handle_edit_command(_, _socket), do: {:error, "Usage: edit <file>"}

  defp resolve_path("/" <> _ = path, _cwd), do: path
  defp resolve_path(path, cwd), do: Path.join(cwd, path)

  defp get_help_options do
    [
      %{name: "Search files", path: "Type > followed by search term", is_directory: false, content: "Search for files by name or content"},
      %{name: "Shell commands", path: "Type $ followed by command", is_directory: false, content: "Execute shell commands like ls, cd, cat"},
      %{name: "List files", path: "$ ls", is_directory: false, content: "List files in current directory"},
      %{name: "Change directory", path: "$ cd <path>", is_directory: false, content: "Change current directory"},
      %{name: "View file", path: "$ cat <file>", is_directory: false, content: "Display file contents"},
      %{name: "Edit file", path: "$ edit <file>", is_directory: false, content: "Open file in editor"},
      %{name: "Create file", path: "$ touch <file>", is_directory: false, content: "Create new file or directory"},
      %{name: "Remove file", path: "$ rm <file>", is_directory: false, content: "Delete file or directory"}
    ]
  end

  # Private helper functions for rendering

  defp flatten_recursive_files(files, level) do
    Enum.flat_map(files, fn file ->
      file_with_indent = Map.put(file, :indent, level)
      children = Map.get(file, :children, [])

      if file.is_directory and length(children) > 0 do
        [file_with_indent | flatten_recursive_files(children, level + 1)]
      else
        [file_with_indent]
      end
    end)
  end
end
