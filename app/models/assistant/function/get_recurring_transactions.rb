class Assistant::Function::GetRecurringTransactions < Assistant::Function
  class << self
    def name
      "get_recurring_transactions"
    end

    def description
      <<~INSTRUCTIONS
        Use this to identify recurring transactions (subscriptions, bills, regular income) by analyzing patterns.

        This function analyzes the last 6 months of transactions and detects:
        - Recurring expenses (subscriptions, bills, regular payments)
        - Recurring income (salary, regular deposits)
        - Frequency classification (weekly, monthly, quarterly, etc.)
        - Fixed vs. variable amounts
        - Estimated monthly/annual costs

        Examples:
        - "What subscriptions do I have?"
        - "Show me my recurring bills"
        - "How much do I spend on subscriptions?"
        - "What are my monthly recurring expenses?"

        Detection Logic:
        - Requires minimum 3 occurrences in 6-month period
        - Groups by merchant + category + similar amount (±$5 range)
        - Calculates average interval between transactions
      INSTRUCTIONS
    end
  end

  def call(params = {})
    # Analyze last 6 months
    end_date = Date.current
    start_date = 6.months.ago.to_date

    # Get all transactions in period
    transactions = family.transactions.visible
      .joins(:entry)
      .where("entries.date >= ? AND entries.date <= ?", start_date, end_date)
      .includes(:merchant, :category, entry: :account)
      .order("entries.date")

    # Group transactions by merchant + category
    grouped = transactions.group_by do |txn|
      merchant_name = txn.merchant&.name || "Unknown"
      category_name = txn.category&.name || "Uncategorized"
      amount_bucket = (txn.entry.amount.abs / 5).round * 5 # Bucket amounts to ±$5
      "#{merchant_name}|#{category_name}|#{amount_bucket}"
    end

    # Filter for recurring patterns (3+ occurrences)
    recurring_groups = grouped.select { |_key, txns| txns.size >= 3 }

    recurring_expenses = []
    recurring_income = []

    recurring_groups.each do |_key, txns|
      first_txn = txns.first
      last_txn = txns.last

      # Calculate frequency
      dates = txns.map { |t| t.entry.date }.sort
      intervals = dates.each_cons(2).map { |a, b| (b - a).to_i }
      avg_interval = intervals.any? ? intervals.sum / intervals.size : 0

      # Classify frequency
      frequency, frequency_days = classify_frequency(avg_interval)

      # Calculate amount statistics
      amounts = txns.map { |t| t.entry.amount.abs.to_f }
      avg_amount = amounts.sum / amounts.size
      amount_variance = amounts.any? ? (amounts.map { |a| (a - avg_amount).abs }.sum / amounts.size / avg_amount * 100) : 0
      is_fixed_amount = amount_variance < 5 # Less than 5% variance = fixed

      # Estimate monthly cost
      estimated_monthly_cost = case frequency
      when "weekly" then avg_amount * 4.33
      when "biweekly" then avg_amount * 2.17
      when "monthly" then avg_amount
      when "bimonthly" then avg_amount / 2
      when "quarterly" then avg_amount / 3
      when "semiannual" then avg_amount / 6
      when "annual" then avg_amount / 12
      else avg_amount # irregular
      end

      estimated_annual_cost = estimated_monthly_cost * 12

      recurring_data = {
        merchant: first_txn.merchant&.name || "Unknown",
        category: first_txn.category&.name || "Uncategorized",
        account: first_txn.entry.account.name,
        frequency: frequency,
        frequency_days: frequency_days,
        occurrences: txns.size,
        average_amount: avg_amount,
        formatted_average: Money.new(avg_amount, first_txn.entry.currency).format,
        amount_variance_percent: amount_variance.round(2),
        is_fixed_amount: is_fixed_amount,
        estimated_monthly_cost: estimated_monthly_cost,
        formatted_monthly_cost: Money.new(estimated_monthly_cost, family.currency).format,
        estimated_annual_cost: estimated_annual_cost,
        formatted_annual_cost: Money.new(estimated_annual_cost, family.currency).format,
        first_occurrence: first_txn.entry.date,
        last_occurrence: last_txn.entry.date,
        recent_transactions: txns.last(3).map do |t|
          {
            date: t.entry.date,
            amount: t.entry.amount.abs.to_f,
            formatted_amount: t.entry.amount_money.abs.format,
            name: t.name
          }
        end
      }

      if first_txn.entry.amount < 0
        recurring_income << recurring_data
      else
        recurring_expenses << recurring_data
      end
    end

    # Sort by monthly cost descending
    recurring_expenses.sort_by! { |r| -r[:estimated_monthly_cost] }
    recurring_income.sort_by! { |r| -r[:estimated_monthly_cost] }

    # Calculate summary statistics
    total_monthly_expenses = recurring_expenses.sum { |r| r[:estimated_monthly_cost] }
    total_annual_expenses = recurring_expenses.sum { |r| r[:estimated_annual_cost] }
    total_monthly_income = recurring_income.sum { |r| r[:estimated_monthly_cost] }

    # Group by frequency
    by_frequency = (recurring_expenses + recurring_income)
      .group_by { |r| r[:frequency] }
      .map do |freq, items|
        {
          frequency: freq,
          count: items.size,
          total_monthly_cost: items.sum { |i| i[:estimated_monthly_cost] },
          formatted_total: Money.new(items.sum { |i| i[:estimated_monthly_cost] }, family.currency).format
        }
      end
      .sort_by { |f| -f[:total_monthly_cost] }

    # Group by category
    by_category = recurring_expenses
      .group_by { |r| r[:category] }
      .map do |cat, items|
        {
          category: cat,
          count: items.size,
          total_monthly_cost: items.sum { |i| i[:estimated_monthly_cost] },
          formatted_total: Money.new(items.sum { |i| i[:estimated_monthly_cost] }, family.currency).format,
          items: items.map { |i| "#{i[:merchant]} (#{i[:formatted_monthly_cost]}/mo)" }
        }
      end
      .sort_by { |c| -c[:total_monthly_cost] }

    # Most expensive recurring item
    most_expensive = recurring_expenses.max_by { |r| r[:estimated_monthly_cost] }

    # Fixed vs variable count
    fixed_count = recurring_expenses.count { |r| r[:is_fixed_amount] }
    variable_count = recurring_expenses.size - fixed_count

    # Likely subscriptions (fixed monthly amounts < $100)
    subscriptions_likely = recurring_expenses.count do |r|
      r[:is_fixed_amount] && r[:frequency] == "monthly" && r[:average_amount] < 100
    end

    {
      analysis_period: {
        start_date: start_date,
        end_date: end_date,
        months_analyzed: 6
      },

      summary: {
        total_recurring_items: recurring_expenses.size + recurring_income.size,
        recurring_expenses_count: recurring_expenses.size,
        recurring_income_count: recurring_income.size,
        total_monthly_expenses: total_monthly_expenses,
        formatted_monthly_expenses: Money.new(total_monthly_expenses, family.currency).format,
        total_annual_expenses: total_annual_expenses,
        formatted_annual_expenses: Money.new(total_annual_expenses, family.currency).format,
        total_monthly_income: total_monthly_income,
        formatted_monthly_income: Money.new(total_monthly_income, family.currency).format
      },

      recurring_expenses: recurring_expenses,
      recurring_income: recurring_income,

      by_frequency: by_frequency,
      by_category: by_category,

      insights: {
        most_expensive_recurring: most_expensive ? {
          merchant: most_expensive[:merchant],
          estimated_monthly_cost: most_expensive[:estimated_monthly_cost],
          formatted_monthly_cost: most_expensive[:formatted_monthly_cost]
        } : nil,
        fixed_amount_count: fixed_count,
        variable_amount_count: variable_count,
        subscriptions_likely: subscriptions_likely
      }
    }
  end

  private

  def classify_frequency(avg_interval_days)
    case avg_interval_days
    when 0..10
      ["weekly", 7]
    when 11..17
      ["biweekly", 14]
    when 18..40
      ["monthly", 30]
    when 41..70
      ["bimonthly", 60]
    when 71..110
      ["quarterly", 90]
    when 111..200
      ["semiannual", 180]
    when 201..400
      ["annual", 365]
    else
      ["irregular", avg_interval_days]
    end
  end
end
