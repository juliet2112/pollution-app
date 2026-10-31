defmodule Pollutiondb.Repo.Migrations.AddUniqueIndexToStations do
  use Ecto.Migration

  def change do
    create unique_index(:stations, [:name])
  end
end
