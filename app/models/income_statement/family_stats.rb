class IncomeStatement::FamilyStats
  def initialize(family, interval: "month")
    @family = family
    @interval = interval
  end

  def call
    ActiveRecord::Base.connection.select_all(sanitized_query_sql).map do |row|
      StatRow.new(
        classification: row["classification"],
        median: row["median"],
        avg: row["avg"]
      )
    end
  end

  private
    StatRow = Data.define(:classification, :median, :avg)

    def sanitized_query_sql
      ActiveRecord::Base.sanitize_sql_array([
        query_sql,
        {
          target_currency: @family.currency,
          interval: @interval,
          family_id: @family.id,
          start_date: 24.months.ago.beginning_of_month
        }
      ])
    end

    def query_sql
      <<~SQL
        WITH period_totals AS (
          SELECT
            date_trunc(:interval, ae.date) as period,
            CASE 
              WHEN c.allows_negative_expenses = true THEN 'expense'
              WHEN ae.amount < 0 THEN 'income' 
              ELSE 'expense' 
            END as classification,
            SUM(
              CASE 
                WHEN c.allows_negative_expenses = true 
                  THEN ae.amount * COALESCE(NULLIF(er.rate, 0), 1) * -1
                ELSE ae.amount * COALESCE(NULLIF(er.rate, 0), 1)
              END
            ) as total
          FROM transactions t
          JOIN entries ae ON ae.entryable_id = t.id AND ae.entryable_type = 'Transaction'
          JOIN accounts a ON a.id = ae.account_id
          LEFT JOIN categories c ON c.id = t.category_id
          LEFT JOIN exchange_rates er ON (
            er.date = ae.date AND
            er.from_currency = ae.currency AND
            er.to_currency = :target_currency
          )
          WHERE a.family_id = :family_id
            AND a.status IN ('draft', 'active')
            AND ae.date >= :start_date
            AND t.kind NOT IN ('funds_movement', 'one_time', 'cc_payment')
            AND ae.excluded = false
          GROUP BY period, CASE 
              WHEN c.allows_negative_expenses = true THEN 'expense'
              WHEN ae.amount < 0 THEN 'income' 
              ELSE 'expense' 
            END
        )
        SELECT
          classification,
          ABS(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total)) as median,
          ABS(AVG(total)) as avg
        FROM period_totals
        GROUP BY classification;
      SQL
    end
end
