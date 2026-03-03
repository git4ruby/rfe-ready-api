class CreateSlackIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_integrations, id: :uuid do |t|
      t.references :tenant, null: false, foreign_key: true, type: :uuid
      t.string :webhook_url, null: false
      t.string :channel_name
      t.string :events, array: true, default: []
      t.boolean :active, default: true, null: false
      t.timestamps
    end
  end
end
