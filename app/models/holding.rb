class Holding < ApplicationRecord
  include Monetizable, Gapfillable

  monetize :amount

  belongs_to :account
  belongs_to :security

  validates :qty, :currency, :date, :price, :amount, presence: true
  validates :qty, :price, :amount, numericality: { greater_than_or_equal_to: 0 }

  scope :chronological, -> { order(:date) }
  scope :for, ->(security) { where(security_id: security).order(:date) }

  delegate :ticker, to: :security

  def name
    security.name || ticker
  end

  def weight
    return nil unless amount
    return 0 if amount.to_f == 0

    account.balance.to_f == 0 ? 1 : amount / account.balance * 100
  end

  # Calculates the weighted average cost basis for the holding based on BUY trades
  def avg_cost
    total_cost, total_qty = account.trades
      .with_entry
      .joins(ActiveRecord::Base.sanitize_sql_array([
        "LEFT JOIN exchange_rates ON (
          exchange_rates.date = entries.date AND
          exchange_rates.from_currency = trades.currency AND
          exchange_rates.to_currency = ?
        )", currency
      ]))
      .where(security_id: security.id)
      .where("trades.qty > 0 AND entries.date <= ?", date)
      .pick(
        Arel.sql("SUM(trades.qty * trades.price * COALESCE(exchange_rates.rate, 1))"),
        Arel.sql("SUM(trades.qty)")
      )

    if total_qty.present? && total_qty.to_d > 0
      Money.new(total_cost.to_d / total_qty.to_d, currency)
    else
      Money.new(price, currency)
    end
  end

  def trend
    @trend ||= calculate_trend
  end

  def clear_trend_cache
    @trend = nil
  end

  def trades
    account.entries.where(entryable: account.trades.where(security: security)).reverse_chronological
  end

  def destroy_holding_and_entries!
    transaction do
      account.entries.where(entryable: account.trades.where(security: security)).destroy_all
      destroy
    end

    account.sync_later
  end

  private
    def calculate_trend
      return nil unless amount_money

      start_amount = qty * avg_cost

      Trend.new \
        current: amount_money,
        previous: start_amount
    end
end
