class AddLockingToDraftResponses < ActiveRecord::Migration[8.0]
  def change
    add_reference :draft_responses, :locked_by, type: :uuid, foreign_key: { to_table: :users }, null: true
    add_column :draft_responses, :locked_at, :datetime, null: true
  end
end
