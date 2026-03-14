class IncomeStatement
  include Monetizable

  monetize :median_expense, :median_income

  attr_reader :family

  def initialize(family)
    @family = family
  end

  def totals(transactions_scope: nil)
    transactions_scope ||= family.transactions.visible

    result = totals_query(transactions_scope: transactions_scope)

    total_income = result.select { |t| t.classification == "income" }.sum(&:total)
    total_expense = result.select { |t| t.classification == "expense" }.sum(&:total)

    ScopeTotals.new(
      transactions_count: result.sum(&:transactions_count),
      income_money: Money.new(total_income, family.currency),
      expense_money: Money.new(total_expense, family.currency)
    )
  end

  def expense_totals(period: Period.current_month)
    build_period_total(classification: "expense", period: period)
  end

  def income_totals(period: Period.current_month)
    build_period_total(classification: "income", period: period)
  end

  def median_expense(interval: "month", category: nil)
    if category.present?
      category_stats(interval: interval).find { |stat| stat.classification == "expense" && stat.category_id == category.id }&.median || 0
    else
      family_stats(interval: interval).find { |stat| stat.classification == "expense" }&.median || 0
    end
  end

  def avg_expense(interval: "month", category: nil)
    if category.present?
      category_stats(interval: interval).find { |stat| stat.classification == "expense" && stat.category_id == category.id }&.avg || 0
    else
      family_stats(interval: interval).find { |stat| stat.classification == "expense" }&.avg || 0
    end
  end

  def median_income(interval: "month", period: nil)
    if period.present?
      # Use the specified period for calculation
      scope = family.transactions.visible.in_period(period)
      result = totals_query(transactions_scope: scope)
      
      income_totals = result.select { |t| t.classification == "income" }
      return 0 if income_totals.empty?
      
      # Calculate median value from income transactions
      amounts = income_totals.map(&:total).sort
      size = amounts.size
      
      if size.odd?
        amounts[size/2]
      else
        (amounts[size/2 - 1] + amounts[size/2]) / 2.0
      end
    else
      # Default behavior without period parameter
      family_stats(interval: interval).find { |stat| stat.classification == "income" }&.median || 0
    end
  end

  # Returns the average monthly income and expenses based on the rolling
  # last 12 complete months (excludes the current, partial month).
  # Returns a struct with :income and :expense (both raw numeric amounts).
  Rolling12mAverages = Data.define(:income, :expense)

  def rolling_12m_averages
    Rails.cache.fetch([
      "income_statement", "rolling_12m_averages", family.id,
      family.entries_cache_version, family.accounts_cache_version
    ]) do
      period_start = 12.months.ago.beginning_of_month.to_date
      period_end   = 1.month.ago.end_of_month.to_date

      # Explicitly scope to active/draft accounts only (disabled accounts are excluded)
      scope = family.transactions
                    .joins(:entry => :account)
                    .where(accounts: { status: [ "draft", "active" ] })
                    .where(entries: { date: period_start..period_end, excluded: false })

      rows = totals_query(transactions_scope: scope)

      income_total  = rows.select { |r| r.classification == "income"  }.sum(&:total).to_f
      expense_total = rows.select { |r| r.classification == "expense" }.sum(&:total).abs.to_f

      # Divide by 12 (full months in window) to get the monthly average
      Rolling12mAverages.new(
        income:  income_total  / 12.0,
        expense: expense_total / 12.0
      )
    end
  end

  private
    ScopeTotals = Data.define(:transactions_count, :income_money, :expense_money)
    PeriodTotal = Data.define(:classification, :total, :currency, :category_totals)
    CategoryTotal = Data.define(:category, :total, :currency, :weight)

    def categories
      @categories ||= family.categories.all.to_a
    end

    def build_period_total(classification:, period:)
      totals = totals_query(transactions_scope: family.transactions.visible.in_period(period)).select { |t| t.classification == classification }
      classification_total = totals.sum(&:total)

      uncategorized_category = family.categories.uncategorized

      category_totals = [ *categories, uncategorized_category ].map do |category|
        subcategory = categories.find { |c| c.id == category.parent_id }

        parent_category_total = totals.select { |t| t.category_id == category.id }&.sum(&:total) || 0

        children_totals = if category == uncategorized_category
          0
        else
          totals.select { |t| t.parent_category_id == category.id }&.sum(&:total) || 0
        end

        category_total = parent_category_total + children_totals

        weight = (category_total.to_f == 0 ? 0 : category_total.to_f / classification_total) * 100

        CategoryTotal.new(
          category: category,
          total: category_total,
          currency: family.currency,
          weight: weight,
        )
      end

      PeriodTotal.new(
        classification: classification,
        total: category_totals.reject { |ct| ct.category.subcategory? }.sum(&:total),
        currency: family.currency,
        category_totals: category_totals
      )
    end

    def family_stats(interval: "month")
      @family_stats ||= {}
      @family_stats[interval] ||= Rails.cache.fetch([
        "income_statement", "family_stats", family.id, interval, family.entries_cache_version, family.accounts_cache_version
      ]) { FamilyStats.new(family, interval:).call }
    end

    def category_stats(interval: "month")
      @category_stats ||= {}
      @category_stats[interval] ||= Rails.cache.fetch([
        "income_statement", "category_stats", family.id, interval, family.entries_cache_version, family.accounts_cache_version
      ]) { CategoryStats.new(family, interval:).call }
    end

    def totals_query(transactions_scope:)
      sql_hash = Digest::MD5.hexdigest(transactions_scope.to_sql)

      Rails.cache.fetch([
        "income_statement", "totals_query", family.id, sql_hash, family.entries_cache_version
      ]) { Totals.new(family, transactions_scope: transactions_scope).call }
    end

    def monetizable_currency
      family.currency
    end
end
