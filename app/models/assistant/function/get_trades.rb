class Assistant::Function::GetTrades < Assistant::Function
  class << self
    def name
      "get_trades"
    end

    def description
      <<~INSTRUCTIONS
        Use this to see investment trading activity (buy/sell transactions) with optional filters.

        This function provides detailed trade history including:
        - Buy and sell transactions
        - Securities traded (ticker, name)
        - Quantities and prices
        - Trade values
        - Summary statistics (total invested/divested, most traded securities)

        Examples:
        - "What did I buy last month?"
        - "Show me my AAPL trades"
        - "How much did I invest this year?"
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      properties: {
        start_date: {
          type: "string",
          description: "Start date for trades in YYYY-MM-DD format"
        },
        end_date: {
          type: "string",
          description: "End date for trades in YYYY-MM-DD format"
        },
        account: {
          type: "string",
          description: "Filter by account name",
          enum: family_account_names
        },
        ticker: {
          type: "string",
          description: "Filter by security ticker symbol (e.g., 'AAPL')"
        },
        trade_type: {
          type: "string",
          description: "Filter by trade type",
          enum: ["buy", "sell"]
        }
      }
    )
  end

  def call(params = {})
    # Start with trades for user's family accounts
    trades_query = Trade.joins(entry: :account).where(accounts: { family_id: family.id })

    # Apply filters
    if params["start_date"].present?
      start_date = Date.parse(params["start_date"])
      trades_query = trades_query.where("entries.date >= ?", start_date)
    end

    if params["end_date"].present?
      end_date = Date.parse(params["end_date"])
      trades_query = trades_query.where("entries.date <= ?", end_date)
    end

    if params["account"].present?
      trades_query = trades_query.where(accounts: { name: params["account"] })
    end

    if params["ticker"].present?
      trades_query = trades_query.joins(:security).where("securities.ticker ILIKE ?", params["ticker"])
    end

    if params["trade_type"].present?
      if params["trade_type"] == "buy"
        trades_query = trades_query.where("trades.qty > 0")
      elsif params["trade_type"] == "sell"
        trades_query = trades_query.where("trades.qty < 0")
      end
    end

    # Load trades with associations
    trades = trades_query.includes(:security, entry: :account).order("entries.date DESC")

    # Build trade data
    trades_data = trades.map do |trade|
      entry = trade.entry
      trade_type = trade.qty >= 0 ? "buy" : "sell"
      quantity = trade.qty.abs
      total_value = (trade.price * quantity).abs

      {
        date: entry.date,
        trade_type: trade_type,
        security_name: trade.security.name,
        ticker: trade.security.ticker,
        quantity: quantity,
        price: trade.price,
        formatted_price: trade.price_money.format,
        total_value: total_value,
        formatted_total_value: Money.new(total_value, trade.currency).format,
        currency: trade.currency,
        account: entry.account.name
      }
    end

    # Calculate summary statistics
    buys = trades_data.select { |t| t[:trade_type] == "buy" }
    sells = trades_data.select { |t| t[:trade_type] == "sell" }

    total_invested = buys.sum { |t| t[:total_value] }
    total_divested = sells.sum { |t| t[:total_value] }
    net_investment = total_invested - total_divested

    # Find most traded security
    security_trade_counts = trades_data.group_by { |t| t[:ticker] }
    most_traded = security_trade_counts.max_by { |_ticker, trades| trades.size }

    unique_securities = trades_data.map { |t| t[:ticker] }.uniq

    {
      total_trades: trades_data.size,
      trades: trades_data,
      summary: {
        total_buys: buys.size,
        total_sells: sells.size,
        total_invested: total_invested,
        formatted_total_invested: Money.new(total_invested, family.currency).format,
        total_divested: total_divested,
        formatted_total_divested: Money.new(total_divested, family.currency).format,
        net_investment: net_investment,
        formatted_net_investment: Money.new(net_investment, family.currency).format,
        most_traded_security: most_traded ? {
          ticker: most_traded[0],
          security_name: most_traded[1].first[:security_name],
          trade_count: most_traded[1].size
        } : nil,
        unique_securities_traded: unique_securities.size,
        securities_list: unique_securities
      }
    }
  end
end
