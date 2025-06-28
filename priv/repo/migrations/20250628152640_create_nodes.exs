defmodule Terminalphx.Repo.Migrations.CreateNodes do
  use Ecto.Migration

  def change do
    create table(:nodes) do
      add :name, :string
      add :path, :string
      add :content, :text
      add :is_directory, :boolean, default: false, null: false
      add :parent_id, references(:nodes, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:nodes, [:parent_id])
  end
end
