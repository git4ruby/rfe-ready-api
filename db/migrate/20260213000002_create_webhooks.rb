class CreateWebhooks < ActiveRecord::Migration[8.0]
  def change
    create_table :webhooks, id: :uuid do |t|
      t.references :tenant, null: false, foreign_key: true, type: :uuid
      t.string :url, null: false
      t.string :events, array: true, default: []
      t.string :secret
      t.boolean :active, default: true, null: false
      t.string :description
      t.timestamps
    end
  end
end
