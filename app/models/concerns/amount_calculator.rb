module AmountCalculator
  extend ActiveSupport::Concern

  class_methods do
    # Generates SQL for calculating expense amounts with negative expense logic
    # 
    # For categories with allows_negative_expenses = true, the amount is negated (reimbursements)
    # For regular expense categories, the absolute value is used
    #
    # @param amount_column [String] The column containing the transaction amount
    # @param rate_column [String] The exchange rate column (default: "COALESCE(NULLIF(er.rate, 0), 1)")
    # @return [String] SQL fragment for calculating expense amounts
    def expense_amount_sql(amount_column = "ae.amount", rate_column = "COALESCE(NULLIF(er.rate, 0), 1)")
      <<~SQL
        CASE 
          WHEN c.allows_negative_expenses = true 
            THEN SUM(#{amount_column} * #{rate_column} * -1)
          ELSE ABS(SUM(#{amount_column} * #{rate_column}))
        END
      SQL
    end

    # Generates SQL for calculating income amounts (always absolute value)
    #
    # @param amount_column [String] The column containing the transaction amount  
    # @param rate_column [String] The exchange rate column (default: "COALESCE(NULLIF(er.rate, 0), 1)")
    # @return [String] SQL fragment for calculating income amounts
    def income_amount_sql(amount_column = "ae.amount", rate_column = "COALESCE(NULLIF(er.rate, 0), 1)")
      "ABS(SUM(#{amount_column} * #{rate_column}))"
    end

    # Generates SQL for expense calculations in search contexts
    # Used when filtering positive amounts (expenses) and need to handle negative expense categories
    #
    # @param amount_column [String] The column containing the transaction amount
    # @param rate_column [String] The exchange rate column 
    # @return [String] SQL fragment for search expense calculations
    def search_expense_amount_sql(amount_column = "entries.amount", rate_column = "COALESCE(NULLIF(er.rate, 0), 1)")
      <<~SQL
        CASE WHEN #{amount_column} >= 0 AND transactions.kind NOT IN ('funds_movement', 'cc_payment') 
          THEN CASE 
            WHEN categories.allows_negative_expenses = true 
              THEN -(#{amount_column} * #{rate_column})
            ELSE ABS(#{amount_column} * #{rate_column})
          END 
        ELSE 0 
        END
      SQL
    end
  end
end