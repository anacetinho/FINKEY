class Assistant::Function::GetBudget < Assistant::Function
  class << self
    def name
      "get_budget"
    end

    def description
      <<~INSTRUCTIONS
        Use this to see budget vs. actual spending analysis for a specific month.

        This function provides:
        - Budget vs. actual spending by category
        - Over-budget alerts and underutilized categories
        - Income tracking vs. expectations
        - Savings rate calculation
        - Month-over-month variance

        Examples:
        - "How am I doing against my budget?"
        - "Am I over budget this month?"
        - "Show me my budget for September"
        - "What categories am I overspending in?"

        Note: Returns gracefully if no budget exists for the requested month.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      properties: {
        month: {
          type: "string",
          description: "Month in YYYY-MM format (e.g., '2025-10'). Defaults to current month if not specified."
        }
      }
    )
  end

  def call(params = {})
    # Parse month or use current month
    target_date = if params["month"].present?
      Date.parse("#{params['month']}-01")
    else
      Date.current
    end

    # Find or bootstrap budget for the month
    budget = Budget.find_or_bootstrap(family, start_date: target_date)

    return { has_budget: false, message: "No budget available for #{target_date.strftime('%B %Y')}" } unless budget

    # Check if budget is initialized (user has set spending amounts)
    return {
      has_budget: true,
      initialized: false,
      month: budget.name,
      message: "Budget exists but has not been set up yet. User needs to configure spending amounts."
    } unless budget.initialized?

    # Build category breakdowns
    categories_data = budget.budget_categories.reject(&:subcategory?).map do |bc|
      actual = budget.budget_category_actual_spending(bc)
      budgeted = bc.budgeted_spending
      available = budgeted - actual
      percent_spent = budgeted > 0 ? (actual / budgeted.to_f * 100).round(2) : 0
      is_over_budget = available < 0

      {
        category_name: bc.category.name,
        budgeted: budgeted.to_f,
        formatted_budgeted: bc.budgeted_spending_money.format,
        actual: actual.to_f,
        formatted_actual: Money.new(actual, budget.currency).format,
        available: available.to_f,
        formatted_available: Money.new(available, budget.currency).format,
        percent_spent: percent_spent,
        is_over_budget: is_over_budget,
        overage_amount: is_over_budget ? available.abs.to_f : nil,
        formatted_overage: is_over_budget ? Money.new(available.abs, budget.currency).format : nil
      }
    end.sort_by { |c| -c[:actual] }

    # Identify alerts
    over_budget_categories = categories_data.select { |c| c[:is_over_budget] }
    underutilized_categories = categories_data.select { |c| c[:percent_spent] < 50 && c[:budgeted] > 0 }

    # Income analysis
    is_income_surplus = budget.remaining_expected_income < 0

    # Savings rate calculation
    savings = budget.actual_income - budget.actual_spending
    savings_rate = budget.actual_income > 0 ? (savings / budget.actual_income.to_f * 100).round(2) : 0

    # Top spending category
    top_spending_category = categories_data.max_by { |c| c[:actual] }

    {
      has_budget: true,
      initialized: true,
      month: budget.name,
      is_current_month: budget.current?,

      spending: {
        budgeted: budget.budgeted_spending.to_f,
        formatted_budgeted: budget.budgeted_spending_money.format,
        actual: budget.actual_spending.to_f,
        formatted_actual: budget.actual_spending_money.format,
        available: budget.available_to_spend.to_f,
        formatted_available: budget.available_to_spend_money.format,
        percent_spent: budget.percent_of_budget_spent.round(2),
        is_over_budget: budget.available_to_spend < 0,
        overage_percent: budget.overage_percent.round(2)
      },

      allocation: {
        total_budgeted: budget.budgeted_spending.to_f,
        formatted_total_budgeted: budget.budgeted_spending_money.format,
        allocated: budget.allocated_spending.to_f,
        formatted_allocated: budget.allocated_spending_money.format,
        unallocated: budget.available_to_allocate.to_f,
        formatted_unallocated: budget.available_to_allocate_money.format,
        percent_allocated: budget.allocated_percent.round(2)
      },

      income: {
        expected: budget.expected_income&.to_f || 0,
        formatted_expected: budget.expected_income_money.format,
        actual: budget.actual_income.to_f,
        formatted_actual: budget.actual_income_money.format,
        remaining: budget.remaining_expected_income.to_f,
        formatted_remaining: budget.remaining_expected_income_money.format,
        percent_earned: budget.actual_income_percent.round(2),
        is_surplus: is_income_surplus,
        surplus_percent: budget.surplus_percent.round(2)
      },

      categories: categories_data,

      alerts: {
        over_budget_count: over_budget_categories.size,
        over_budget_categories: over_budget_categories.map do |c|
          {
            category: c[:category_name],
            overage: c[:formatted_overage],
            percent_over: (c[:percent_spent] - 100).round(2)
          }
        end,
        underutilized_count: underutilized_categories.size,
        underutilized_categories: underutilized_categories.map do |c|
          {
            category: c[:category_name],
            percent_used: c[:percent_spent],
            available: c[:formatted_available]
          }
        end
      },

      insights: {
        estimated_monthly_spending: budget.estimated_spending.to_f,
        formatted_estimated_monthly_spending: budget.estimated_spending_money.format,
        variance_from_estimate: (budget.actual_spending - budget.estimated_spending).to_f,
        formatted_variance: Money.new((budget.actual_spending - budget.estimated_spending).abs, budget.currency).format,
        top_spending_category: top_spending_category ? top_spending_category[:category_name] : nil,
        savings: savings.to_f,
        formatted_savings: Money.new(savings, budget.currency).format,
        savings_rate: savings_rate
      }
    }
  end
end
