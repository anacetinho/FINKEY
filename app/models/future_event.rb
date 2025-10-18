class FutureEvent < ApplicationRecord
  include Monetizable

  belongs_to :family

  monetize :amount, as: :amount_money

  validates :name, presence: true, length: { maximum: 255 }
  validates :date, presence: true
  validates :amount, presence: true, numericality: { not_equal_to: 0 }
  validates :event_type, presence: true, inclusion: { in: %w[income expense] }
  validates :description, length: { maximum: 1000 }
  validates :name, uniqueness: { scope: [:date, :amount, :event_type, :family_id], message: "event already exists for this date and amount" }

  validate :date_must_be_in_future

  scope :income, -> { where(event_type: 'income') }
  scope :expenses, -> { where(event_type: 'expense') }
  scope :for_period, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :ordered, -> { order(:date, :name) }

  def income?
    event_type == 'income'
  end

  def expense?
    event_type == 'expense'
  end

  def impact_on_net_worth
    income? ? amount_money : -amount_money
  end

  def currency
    family.currency
  end

  private

  def date_must_be_in_future
    return unless date

    if date <= Date.current
      errors.add(:date, "must be in the future")
    end
  end
end