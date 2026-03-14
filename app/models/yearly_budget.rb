class YearlyBudget
  include ActiveModel::Model
  include ActiveModel::Conversion
  include Monetizable

  monetize :budgeted_spending, :expected_income, :allocated_spending,
           :actual_spending, :available_to_spend, :available_to_allocate,
           :actual_income, :remaining_expected_income

  attr_reader :family, :year

  def initialize(family, year)
    @family = family
    @year = year
  end

  def id
    year
  end

  def to_key
    [ year ]
  end

  def name
    year.to_s
  end

  def start_date
    @start_date ||= Date.new(year, 1, 1)
  end

  def end_date
    @end_date ||= Date.new(year, 12, 31)
  end

  def period
    @period ||= Period.custom(start_date: start_date, end_date: end_date)
  end

  def currency
    family.currency
  end

  def previous_budget_param
    prev_year = year - 1
    return nil unless Budget.budget_date_valid?(Date.new(prev_year, 12, 1), family: family)
    prev_year.to_s
  end

  def next_budget_param
    next_year = year + 1
    return nil if next_year > Date.today.year
    return nil unless Budget.budget_date_valid?(Date.new(next_year, 1, 1), family: family)
    next_year.to_s
  end

  def initialized?
    true
  end

  def current?
    year == Date.today.year
  end

  def budgeted_spending
    @budgeted_spending ||= monthly_budgets.sum { |b| b.budgeted_spending || 0 }
  end

  def expected_income
    @expected_income ||= monthly_budgets.sum { |b| b.expected_income || 0 }
  end

  def actual_spending
    @actual_spending ||= expense_totals.total
  end

  def actual_income
    @actual_income ||= income_totals.total
  end

  def actual_income_percent
    return 0 unless expected_income > 0
    (actual_income / expected_income.to_f) * 100
  end

  def surplus_percent
    return 0 unless remaining_expected_income.to_f < 0 && expected_income.to_f > 0
    remaining_expected_income.abs / expected_income.to_f * 100
  end

  def overage_percent
    return 0 unless available_to_spend.to_f < 0 && actual_spending.to_f > 0
    available_to_spend.abs / actual_spending.to_f * 100
  end

  def percent_of_budget_spent
    return 0 unless budgeted_spending.to_f > 0
    (actual_spending / budgeted_spending.to_f) * 100
  end

  def available_to_spend
    (budgeted_spending || 0) - actual_spending
  end

  def remaining_expected_income
    (expected_income || 0) - actual_income
  end

  def available_to_allocate
    (budgeted_spending || 0) - allocated_spending
  end

  def allocated_spending
    @allocated_spending ||= monthly_budgets.sum { |b| b.allocated_spending || 0 }
  end

  def allocations_valid?
    allocated_spending.positive? && available_to_allocate >= 0
  end

  def budget_categories
    @budget_categories ||= begin
      categories = family.categories.expenses.to_a
      categories.map do |category|
        YearlyBudgetCategory.new(self, category)
      end
    end
  end

  def uncategorized_budget_category
    @uncategorized_budget_category ||= YearlyBudgetCategory.new(self, nil)
  end

  def income_category_totals
    income_totals.category_totals.reject { |ct| ct.category.subcategory? || ct.total.to_f == 0 }.sort_by(&:weight).reverse
  end

  def expense_category_totals
    expense_totals.category_totals.reject { |ct| ct.category.subcategory? || ct.total.to_f == 0 }.sort_by(&:weight).reverse
  end

  def to_donut_segments_json
    unused_segment_id = "unused"

    return [ { color: "var(--budget-unallocated-fill)", amount: 1, id: unused_segment_id } ] unless allocations_valid?

    segments = budget_categories.reject(&:subcategory?).map do |bc|
      { color: bc.category.color, amount: bc.actual_spending.to_f, id: bc.id }
    end

    if available_to_spend.to_f > 0
      segments.push({ color: "var(--budget-unallocated-fill)", amount: available_to_spend.to_f, id: unused_segment_id })
    end

    segments
  end

  def budget_category_actual_spending(budget_category)
    expense_totals.category_totals.find { |ct| ct.category.id == budget_category.category.id }&.total || 0
  end

  def category_avg_monthly_expense(category)
    income_statement.avg_expense(category: category)
  end

  def category_median_monthly_expense(category)
    income_statement.median_expense(category: category)
  end

  private

  def monthly_budgets
    @monthly_budgets ||= Budget.where(family: family, start_date: start_date..end_date)
  end

  def income_statement
    @income_statement ||= family.income_statement
  end

  def expense_totals
    @expense_totals ||= income_statement.expense_totals(period: period)
  end

  def income_totals
    @income_totals ||= income_statement.income_totals(period: period)
  end
end

class YearlyBudgetCategory
  include ActiveModel::Model
  include ActiveModel::Conversion
  include Monetizable

  monetize :budgeted_spending, :actual_spending, :available_to_spend, :avg_monthly_expense, :median_monthly_expense

  attr_reader :budget, :category

  def initialize(budget, category)
    @budget = budget
    @category = category || budget.family.categories.uncategorized
  end

  def to_key
    [ category&.id || "uncategorized" ]
  end

  def id
    category&.id || "uncategorized"
  end

  def category_id
    category&.id
  end

  def name
    category&.name || "Uncategorized"
  end

  def currency
    budget.currency
  end

  def budgeted_spending
    @budgeted_spending ||= if category_id.present?
      BudgetCategory.joins(:budget)
                    .where(budgets: { family_id: budget.family.id, start_date: budget.start_date..budget.end_date }, category_id: category_id)
                    .sum(:budgeted_spending)
    else
      budget.available_to_allocate
    end
  end

  def actual_spending
    budget.budget_category_actual_spending(self)
  end

  def available_to_spend
    (budgeted_spending || 0) - actual_spending
  end

  def avg_monthly_expense
    budget.category_avg_monthly_expense(category)
  end

  def median_monthly_expense
    budget.category_median_monthly_expense(category)
  end

  def subcategory?
    category&.parent_id.present?
  end

  def initialized?
    true
  end
end
