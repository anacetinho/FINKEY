require "test_helper"

class CategoryNegativeExpensesTest < ActiveSupport::TestCase
  setup do
    @family = families(:one)
  end

  test "allows_negative_expenses can be set for expense categories" do
    category = @family.categories.create!(
      name: "Expense Reimbursement",
      classification: "expense",
      color: "#e99537",
      lucide_icon: "hand-helping",
      allows_negative_expenses: true
    )

    assert category.allows_negative_expenses?
  end

  test "allows_negative_expenses cannot be set for income categories" do
    category = @family.categories.build(
      name: "Income Category",
      classification: "income",
      color: "#e99537",
      lucide_icon: "circle-dollar-sign",
      allows_negative_expenses: true
    )

    refute category.valid?
    assert_includes category.errors[:allows_negative_expenses], "can only be enabled for expense categories"
  end

  test "negative expenses reduce expense totals in transaction search" do
    # Create a reimbursement category
    reimbursement_category = @family.categories.create!(
      name: "Expense Reimbursement",
      classification: "expense",
      color: "#e99537", 
      lucide_icon: "hand-helping",
      allows_negative_expenses: true
    )

    # Create regular expense category
    expense_category = @family.categories.create!(
      name: "Food",
      classification: "expense",
      color: "#eb5429",
      lucide_icon: "utensils"
    )

    account = @family.accounts.first

    # Create a regular expense transaction
    expense_entry = account.entries.create!(
      date: Date.current,
      name: "Restaurant dinner",
      amount: 50.00, # positive amount = expense
      currency: "USD"
    )
    
    expense_transaction = expense_entry.build_entryable(Transaction.new)
    expense_transaction.category = expense_category
    expense_entry.save!

    # Create a reimbursement transaction (negative expense)
    reimbursement_entry = account.entries.create!(
      date: Date.current,
      name: "Expense reimbursement",
      amount: -20.00, # negative amount in reimbursement category should reduce expenses
      currency: "USD"
    )
    
    reimbursement_transaction = reimbursement_entry.build_entryable(Transaction.new)
    reimbursement_transaction.category = reimbursement_category
    reimbursement_entry.save!

    # Test transaction search totals
    search = Transaction::Search.new(@family)
    totals = search.totals

    # Net expense should be $30 (50 - 20)
    expected_expense_total = Money.new(30.00, "USD")
    assert_equal expected_expense_total.to_s, totals.expense_money.to_s
  end
end