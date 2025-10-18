require "test_helper"

class BudgetNegativeExpenseIntegrationTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = @family.accounts.first
    
    # Create expense reimbursement category
    @reimburse_category = @family.categories.create!(
      name: "Expense Reimbursement",
      classification: "expense",
      color: "#e99537",
      lucide_icon: "hand-coins",
      allows_negative_expenses: true
    )
    
    # Create regular expense category
    @regular_category = @family.categories.create!(
      name: "Food",
      classification: "expense", 
      color: "#eb5429",
      lucide_icon: "utensils"
    )
    
    @budget_date = Date.current.beginning_of_month
    @budget = Budget.find_or_bootstrap(@family, start_date: @budget_date)
  end

  test "budget category actual_spending reflects negative expense logic" do
    # Create regular expense transaction ($100)
    regular_transaction = create_transaction(
      amount: 100, 
      category: @regular_category,
      date: @budget_date + 5.days
    )
    
    # Create reimbursement transaction ($30)  
    reimbursement_transaction = create_transaction(
      amount: 30,
      category: @reimburse_category, 
      date: @budget_date + 10.days
    )
    
    # Get budget categories
    regular_budget_cat = @budget.budget_categories.find { |bc| bc.category.id == @regular_category.id }
    reimburse_budget_cat = @budget.budget_categories.find { |bc| bc.category.id == @reimburse_category.id }
    
    # Regular category should show positive spending
    assert_equal 100, regular_budget_cat.actual_spending.to_f, 
                "Regular expense category should show positive spending"
    
    # Reimbursement category should show negative spending (reduces total expenses)
    assert_equal -30, reimburse_budget_cat.actual_spending.to_f,
                "Reimbursement category should show negative spending"
  end

  test "income statement totals with budget integration handle negative expenses" do
    # Create transactions in budget period
    create_transaction(amount: 200, category: @regular_category, date: @budget_date + 3.days)
    create_transaction(amount: 50, category: @reimburse_category, date: @budget_date + 7.days)
    
    # Test income statement expense totals for budget period
    expense_totals = @family.income_statement.expense_totals(period: @budget.period)
    
    # Find category totals
    regular_total = expense_totals.category_totals.find { |ct| ct.category.id == @regular_category.id }
    reimburse_total = expense_totals.category_totals.find { |ct| ct.category.id == @reimburse_category.id }
    
    assert_equal 200, regular_total.total.to_f, "Regular category should have positive total"
    assert_equal -50, reimburse_total.total.to_f, "Reimbursement category should have negative total"
    
    # Overall expense total should be net amount (200 - 50 = 150)
    assert_equal 150, expense_totals.total.to_f, "Total expenses should be net amount after reimbursements"
  end

  test "transaction search totals match income statement totals with negative expenses" do
    # Create test transactions
    create_transaction(amount: 150, category: @regular_category, date: @budget_date + 1.day)
    create_transaction(amount: 25, category: @reimburse_category, date: @budget_date + 2.days)
    
    # Get search totals
    search = Transaction::Search.new(@family, filters: {
      start_date: @budget_date.strftime("%Y-%m-%d"),
      end_date: @budget_date.end_of_month.strftime("%Y-%m-%d")
    })
    search_totals = search.totals
    
    # Get income statement totals for same period
    income_statement_totals = @family.income_statement.totals(
      transactions_scope: @family.transactions.in_period(@budget.period)
    )
    
    # Both should calculate the same net expense total (150 - 25 = 125)
    expected_expense = 125
    
    assert_equal expected_expense, search_totals.expense_money.amount.to_f,
                "Search totals should handle negative expenses"
    assert_equal expected_expense, income_statement_totals.expense_money.amount.to_f,
                "Income statement totals should handle negative expenses"
    assert_equal search_totals.expense_money.amount, income_statement_totals.expense_money.amount,
                "Search and income statement totals should match"
  end

  private

  def create_transaction(amount:, category:, date:)
    @family.transactions.create!(
      name: "Test Transaction",
      amount: amount,
      date: date,
      category: category,
      account: @account
    ).tap do |transaction|
      # Create the associated entry
      transaction.entries.create!(
        amount: amount,
        currency: @family.currency,
        date: date,
        entryable: transaction
      )
    end
  end
end