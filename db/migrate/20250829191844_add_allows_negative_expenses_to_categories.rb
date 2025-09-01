class AddAllowsNegativeExpensesToCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :categories, :allows_negative_expenses, :boolean, null: false, default: false
  end
end