class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :uuid do |t|
      ## Devise Database Authenticatable
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Devise Recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      ## Devise Rememberable
      t.datetime :remember_created_at

      ## Devise Trackable
      t.integer :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip

      ## Devise Confirmable
      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email

      ## Devise Lockable
      t.integer :failed_attempts, default: 0, null: false
      t.string :unlock_token
      t.datetime :locked_at

      ## JWT Revocation (JTI strategy)
      t.string :jti, null: false

      ## Application fields
      t.references :tenant, type: :uuid, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.integer :role, default: 0, null: false
      t.string :bar_number
      t.integer :status, default: 0, null: false
      t.jsonb :preferences, default: {}

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token, unique: true
    add_index :users, :unlock_token, unique: true
    add_index :users, :jti, unique: true
    add_index :users, [ :tenant_id, :role ]
  end
end
