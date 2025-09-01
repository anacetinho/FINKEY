class CreateFutureEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :future_events, id: :uuid do |t|
      t.string :name, null: false
      t.date :date, null: false
      t.decimal :amount, precision: 19, scale: 4, null: false
      t.string :event_type, null: false # 'income' or 'expense'
      t.text :description
      t.references :family, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :future_events, [:family_id, :date]
    add_index :future_events, :event_type
  end
end