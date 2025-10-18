class FixExpenseReimbursementAmounts < ActiveRecord::Migration[7.2]
  def up
    # Find all entries with transactions that have expense reimbursement categories
    # and negative amounts (which should be positive to increase account balance)
    
    entries_to_fix = ActiveRecord::Base.connection.select_all(<<~SQL)
      SELECT entries.id, entries.amount
      FROM entries 
      JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'
      JOIN categories ON categories.id = transactions.category_id
      WHERE categories.allows_negative_expenses = true 
        AND entries.amount < 0
    SQL

    if entries_to_fix.any?
      say "Found #{entries_to_fix.size} expense reimbursement entries with negative amounts to fix"
      
      entries_to_fix.each do |entry_data|
        entry_id = entry_data['id']
        current_amount = entry_data['amount'].to_f
        new_amount = current_amount.abs
        
        ActiveRecord::Base.connection.execute(<<~SQL)
          UPDATE entries 
          SET amount = #{new_amount}
          WHERE id = '#{entry_id}'
        SQL
        
        say "Fixed entry #{entry_id}: #{current_amount} → #{new_amount}"
      end
      
      say "✅ Fixed #{entries_to_fix.size} expense reimbursement amounts"
    else
      say "No expense reimbursement entries with negative amounts found - nothing to fix"
    end
  end

  def down
    # Reverse the migration by making positive amounts negative again
    entries_to_reverse = ActiveRecord::Base.connection.select_all(<<~SQL)
      SELECT entries.id, entries.amount
      FROM entries 
      JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'
      JOIN categories ON categories.id = transactions.category_id
      WHERE categories.allows_negative_expenses = true 
        AND entries.amount > 0
    SQL

    if entries_to_reverse.any?
      say "Reversing #{entries_to_reverse.size} expense reimbursement entries back to negative amounts"
      
      entries_to_reverse.each do |entry_data|
        entry_id = entry_data['id']
        current_amount = entry_data['amount'].to_f
        new_amount = -current_amount.abs
        
        ActiveRecord::Base.connection.execute(<<~SQL)
          UPDATE entries 
          SET amount = #{new_amount}
          WHERE id = '#{entry_id}'
        SQL
        
        say "Reversed entry #{entry_id}: #{current_amount} → #{new_amount}"
      end
      
      say "✅ Reversed #{entries_to_reverse.size} expense reimbursement amounts"
    else
      say "No expense reimbursement entries to reverse"
    end
  end
end