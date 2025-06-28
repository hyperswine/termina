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
     |> assign(:command_input, ">")
     |> assign(:command_history, [])
     |> assign(:search_results, [])
     |> assign(:mode, :search)  # :search, :shell, :help
     |> assign(:editor_open, false)
     |> assign(:editor_file_path, nil)
     |> assign(:editor_content, "")
     |> assign(:pane_results, [])
     |> assign(:last_command, "")
     |> assign(:last_search, "")
    }
  end

  @impl true
  def handle_event("toggle_modal", _, socket) do
    modal_open = !socket.assigns.modal_open

    socket =
      socket
      |> assign(:modal_open, modal_open)
      |> assign(:command_input, if(modal_open, do: ">", else: ""))
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
    {mode, cleaned_command} = determine_mode(command)

    socket =
      socket
      |> assign(:command_input, command)
      |> assign(:mode, mode)

    socket = case mode do
      :search when cleaned_command != "" ->
        results = FileSystem.search(cleaned_command)
        assign(socket, :search_results, results)

      :help when cleaned_command == "" ->
        assign(socket, :search_results, get_help_options())

      _ ->
        assign(socket, :search_results, [])
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("execute_command", %{"command" => command}, socket) do
    {mode, cleaned_command} = determine_mode(command)

    socket = case mode do
      :search -> handle_search_command(cleaned_command, socket)
      :shell -> handle_shell_command(cleaned_command, socket)
      :help -> handle_help_command(cleaned_command, socket)
    end

    # Add to history and reset input
    history = [command | socket.assigns.command_history]

    {:noreply,
     socket
     |> assign(:command_history, Enum.take(history, 10))
     |> assign(:command_input, ">")
     |> assign(:mode, :search)
    }
  end

  @impl true
  def handle_event("close_editor", _, socket) do
    {:noreply,
     socket
     |> assign(:editor_open, false)
     |> assign(:editor_file_path, nil)
     |> assign(:editor_content, "")
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

  # Private functions

  defp determine_mode(command) do
    cond do
      String.starts_with?(command, ">") -> {:search, String.slice(command, 1..-1//1) |> String.trim()}
      String.starts_with?(command, "$") -> {:shell, String.slice(command, 1..-1//1) |> String.trim()}
      command == "" -> {:help, ""}
      true -> {:help, command}
    end
  end

  defp handle_search_command(query, socket) when query != "" do
    results = FileSystem.search(query)

    socket
    |> assign(:search_results, results)
    |> assign(:last_search, query)
    |> assign(:modal_open, false)
  end

  defp handle_search_command(_, socket), do: socket

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
        socket
        |> assign(:pane_results, data)
        |> assign(:last_command, command)
        |> assign(:modal_open, false)

      {:error, message} ->
        socket
        |> put_flash(:error, message)
        |> assign(:last_command, command)
        |> assign(:modal_open, false)

      {:edit, path, content} ->
        socket
        |> assign(:editor_open, true)
        |> assign(:editor_file_path, path)
        |> assign(:editor_content, content)
        |> assign(:modal_open, false)

      _ -> socket
    end

    socket
  end

  defp handle_help_command(_query, socket) do
    assign(socket, :modal_open, false)
  end

  defp handle_ls_command([], socket) do
    files = FileSystem.list_directory(socket.assigns.current_directory)
    {:ok, %{type: :file_list, files: files, path: socket.assigns.current_directory}}
  end

  defp handle_ls_command([path], socket) do
    abs_path = resolve_path(path, socket.assigns.current_directory)
    case FileSystem.cd(abs_path) do
      {:ok, _} ->
        files = FileSystem.list_directory(abs_path)
        {:ok, %{type: :file_list, files: files, path: abs_path}}
      {:error, msg} -> {:error, msg}
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
end
