class AddManualToSecurities < ActiveRecord::Migration[7.2]
  def change
    add_column :securities, :manual, :boolean, default: false, null: false
  end
end
