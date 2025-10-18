require "test_helper"

class AmountCalculatorTest < ActiveSupport::TestCase
  class TestClass
    include AmountCalculator
  end

  setup do
    @test_class = TestClass.new
  end

  test "expense_amount_sql generates correct SQL for negative expense logic" do
    sql = TestClass.expense_amount_sql

    assert_includes sql, "CASE"
    assert_includes sql, "categories.allows_negative_expenses = true"
    assert_includes sql, "SUM(ae.amount * COALESCE(NULLIF(er.rate, 0), 1) * -1)"
    assert_includes sql, "ABS(SUM(ae.amount * COALESCE(NULLIF(er.rate, 0), 1)))"
  end

  test "expense_amount_sql accepts custom column parameters" do
    sql = TestClass.expense_amount_sql("custom_amount", "custom_rate")

    assert_includes sql, "SUM(custom_amount * custom_rate * -1)"
    assert_includes sql, "ABS(SUM(custom_amount * custom_rate))"
  end

  test "income_amount_sql generates simple absolute value calculation" do
    sql = TestClass.income_amount_sql

    assert_equal "ABS(SUM(ae.amount * COALESCE(NULLIF(er.rate, 0), 1)))", sql
  end

  test "income_amount_sql accepts custom column parameters" do
    sql = TestClass.income_amount_sql("custom_amount", "custom_rate")

    assert_equal "ABS(SUM(custom_amount * custom_rate))", sql
  end

  test "search_expense_amount_sql includes transaction type filtering" do
    sql = TestClass.search_expense_amount_sql

    assert_includes sql, "entries.amount >= 0"
    assert_includes sql, "transactions.kind NOT IN ('funds_movement', 'cc_payment')"
    assert_includes sql, "categories.allows_negative_expenses = true"
    assert_includes sql, "-(entries.amount * COALESCE(NULLIF(er.rate, 0), 1))"
    assert_includes sql, "ABS(entries.amount * COALESCE(NULLIF(er.rate, 0), 1))"
    assert_includes sql, "ELSE 0"
  end

  test "search_expense_amount_sql accepts custom column parameters" do
    sql = TestClass.search_expense_amount_sql("custom_entries.amount", "custom_rate")

    assert_includes sql, "custom_entries.amount >= 0"
    assert_includes sql, "-(custom_entries.amount * custom_rate)"
    assert_includes sql, "ABS(custom_entries.amount * custom_rate)"
  end
end