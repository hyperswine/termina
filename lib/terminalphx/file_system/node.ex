defmodule Terminalphx.FileSystem.Node do
  use Ecto.Schema
  import Ecto.Changeset

  schema "nodes" do
    field :name, :string
    field :path, :string
    field :content, :string
    field :is_directory, :boolean, default: false

    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(node, attrs) do
    node
    |> cast(attrs, [:name, :path, :content, :is_directory, :parent_id])
    |> validate_required([:name, :path, :is_directory])
    |> validate_content_for_files()
    |> validate_unique_path()
  end

  defp validate_content_for_files(changeset) do
    case get_field(changeset, :is_directory) do
      false -> validate_required(changeset, [:content])
      true ->
        changeset
        |> put_change(:content, nil)
    end
  end

  defp validate_unique_path(changeset) do
    validate_change(changeset, :path, fn :path, path ->
      case Terminalphx.Repo.get_by(__MODULE__, path: path) do
        nil -> []
        existing_node ->
          case get_field(changeset, :id) do
            nil -> [path: "already exists"]
            id when id != existing_node.id -> [path: "already exists"]
            _ -> []
          end
      end
    end)
  end
end
