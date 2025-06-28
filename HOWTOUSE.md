# Terminal Phoenix

A spotlight-like terminal interface built with Phoenix.

## Features

### Spotlight-Style Interface

- Press `Ctrl+K` (or `Cmd+K` on Mac) to open the terminal modal
- Press `Escape` to close the modal

### Three Operating Modes

#### 1. Search Mode (`>`)

- Type `>` followed by your search term
- Searches through file names and content
- Real-time search results as you type
- Example: `>config` finds files containing "config"

#### 2. Shell Mode (`$`)

- Type `$` followed by your command
- Supports common Unix-like commands:
  - `ls [path]` - List files and directories
  - `cd [path]` - Change current directory
  - `cat <file>` - Display file contents
  - `show <file>` - Alias for cat
  - `rm <file>` - Remove file or directory
  - `touch <file>` - Create new file or directory
  - `edit <file>` - Open file in the built-in editor

#### 3. Help Mode (empty input)

- Leave the input empty to see available commands and options
- Shows quick reference for all available functionality

### Virtual File System

- Persistent file system stored in SQLite database
- Hierarchical directory structure
- Support for both files and directories
- File content is searchable

### Built-in Text Editor

- Full-screen text editor opens when using `edit` command
- Syntax highlighting ready (can be extended)
- Save functionality with `Ctrl+S`
- Clean, minimalist interface

## Getting Started

### Prerequisites

- Elixir 1.15+
- Phoenix 1.8+
- PostgreSQL (or SQLite for development)

### Installation

1. Clone the repository
2. Install dependencies:

   ```bash
   mix deps.get
   ```

3. Create and setup the database:

   ```bash
   mix ecto.create
   mix ecto.migrate
   mix run priv/repo/seeds.exs
   ```

4. Install frontend dependencies:

   ```bash
   mix assets.setup
   ```

5. Start the Phoenix server:

   ```bash
   mix phx.server
   ```

6. Visit [`localhost:4000`](http://localhost:4000)

## Usage Examples

### Basic Navigation

1. Press `Ctrl+K` to open terminal
2. Type `$ ls` to see files in current directory
3. Type `$ cd /home` to change directory
4. Type `$ cat welcome.txt` to read a file

### File Operations

1. `$ touch myfile.txt` - Create a new file
2. `$ edit myfile.txt` - Open file in editor
3. `$ rm myfile.txt` - Delete the file

### Search Examples

1. `> txt` - Find all files with "txt" in name or content
2. `> Phoenix` - Find files containing "Phoenix"
3. `> config` - Find configuration files

### Key Components

- `TerminalLive` - Main LiveView module
- `FileSystem` - Context for file operations
- `FileSystem.Node` - Schema for files and directories

## File System Structure

The virtual file system starts with:

```bash
/
└── home/
    ├── welcome.txt
    ├── readme.md
    └── config.json
```

## Customization

### Adding New Commands

Add new commands in `TerminalLive.handle_shell_command/2`:

```elixir
defp handle_shell_command(command, socket) do
  [cmd | args] = String.split(command, " ", trim: true)

  result = case cmd do
    "ls" -> handle_ls_command(args, socket)
    "my_command" -> handle_my_command(args, socket)  # Add here
    # ... existing commands
  end
end
```

### Styling

- Background gradients in the main template
- Modal styling and backdrop effects
- Color schemes for different modes
- Animation timing and effects

## Development

### Database Migrations

Create new migrations:

```bash
mix ecto.gen.migration add_feature
```

## License

This project is open source and available under the MIT License.
