class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments, id: :uuid do |t|
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.references :case, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.uuid :parent_id

      t.text :body, null: false
      t.uuid :mentioned_user_ids, array: true, default: []

      t.timestamps
    end

    add_index :comments, :parent_id
    add_index :comments, [:case_id, :created_at]
    add_foreign_key :comments, :comments, column: :parent_id
  end
end
