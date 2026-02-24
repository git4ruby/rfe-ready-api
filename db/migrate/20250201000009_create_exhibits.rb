class CreateExhibits < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibits, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.references :case, type: :uuid, null: false, foreign_key: true
      t.references :rfe_document, type: :uuid, foreign_key: true

      t.string :label, null: false
      t.string :title
      t.text :description
      t.integer :position, default: 0, null: false
      t.string :page_range

      t.timestamps
    end

    add_index :exhibits, [ :case_id, :position ]
    add_index :exhibits, [ :case_id, :label ], unique: true
  end
end
