class Assistant::Function::GetAccounts < Assistant::Function
  class << self
    def name
      "get_accounts"
    end

    def description
      "Use this to see what accounts the user has along with their current and historical balances"
    end
  end

  def call(params = {})
    {
      as_of_date: Date.current,
      accounts: family.accounts.includes(:balances, :holdings, :accountable).map do |account|
        account_data = {
          name: account.name,
          balance: account.balance,
          currency: account.currency,
          balance_formatted: account.balance_money.format,
          classification: account.classification,
          type: account.accountable_type,
          subtype: account.accountable&.subtype,
          institution: account.institution_domain,
          start_date: account.start_date,
          is_plaid_linked: account.plaid_account_id.present?,
          status: account.status,
          historical_balances: historical_balances(account)
        }

        # Add holdings data for investment accounts
        if account.accountable_type == "Account::Investment" && account.holdings.any?
          account_data[:holdings] = account.holdings.includes(:security).map do |holding|
            {
              security_name: holding.security.name,
              ticker: holding.ticker,
              qty: holding.qty,
              price: holding.price,
              formatted_price: Money.new(holding.price, holding.currency).format,
              amount: holding.amount.to_f,
              formatted_amount: holding.amount_money.format,
              weight: holding.weight&.round(2) || 0,
              avg_cost: holding.avg_cost.to_f,
              formatted_avg_cost: holding.avg_cost.format,
              current_value: holding.amount.to_f,
              formatted_current_value: holding.amount_money.format
            }
          end
        end

        account_data
      end
    }
  end

  private
    def historical_balances(account)
      start_date = [ account.start_date, 5.years.ago.to_date ].max
      period = Period.custom(start_date: start_date, end_date: Date.current)
      balance_series = account.balance_series(period: period, interval: "1 month")

      to_ai_time_series(balance_series)
    end
end
