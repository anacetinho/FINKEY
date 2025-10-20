class Assistant::Function::GetPortfolioSummary < Assistant::Function
  class << self
    def name
      "get_portfolio_summary"
    end

    def description
      <<~INSTRUCTIONS
        Use this for comprehensive portfolio analysis including:
        - Asset allocation by exchange (proxy for sector/geography)
        - Diversification scoring and concentration risk analysis
        - Performance metrics (winners/losers, best/worst performers)
        - Top holdings by value
        - Account-level breakdowns

        This is great for questions like:
        - "Give me a portfolio summary"
        - "How diversified is my portfolio?"
        - "What's my asset allocation?"
        - "Show me my top holdings"
      INSTRUCTIONS
    end
  end

  def call(params = {})
    # Get all investment accounts with holdings
    investment_accounts = family.accounts.visible.joins(:holdings).distinct

    # Collect all holdings data
    all_holdings = []
    total_portfolio_value = 0
    total_cost_basis = 0
    total_gain_loss = 0

    account_summaries = investment_accounts.map do |account|
      account_value = 0
      account_cost_basis = 0
      account_gain_loss = 0
      holdings_count = 0

      account.holdings.includes(:security).each do |holding|
        current_value = holding.amount.to_f
        cost_basis = holding.avg_cost.to_f * holding.qty
        gain_loss = current_value - cost_basis

        all_holdings << {
          account_name: account.name,
          ticker: holding.ticker,
          security_name: holding.security.name,
          exchange: holding.security.exchange_operating_mic,
          value: current_value,
          cost_basis: cost_basis,
          gain_loss: gain_loss,
          gain_loss_percent: cost_basis > 0 ? (gain_loss / cost_basis * 100) : 0
        }

        account_value += current_value
        account_cost_basis += cost_basis
        account_gain_loss += gain_loss
        holdings_count += 1
      end

      total_portfolio_value += account_value
      total_cost_basis += account_cost_basis
      total_gain_loss += account_gain_loss

      {
        name: account.name,
        value: account_value,
        formatted_value: Money.new(account_value, account.currency).format,
        gain_loss: account_gain_loss,
        formatted_gain_loss: Money.new(account_gain_loss, account.currency).format,
        gain_loss_percent: account_cost_basis > 0 ? (account_gain_loss / account_cost_basis * 100).round(2) : 0,
        holdings_count: holdings_count,
        weight_in_portfolio: 0 # Will calculate after we know total
      }
    end

    # Calculate portfolio-level weights for accounts
    account_summaries.each do |acct|
      acct[:weight_in_portfolio] = total_portfolio_value > 0 ? (acct[:value] / total_portfolio_value * 100).round(2) : 0
    end

    # Sort holdings by value descending
    all_holdings.sort_by! { |h| -h[:value] }

    # Top 10 holdings
    top_10_holdings = all_holdings.take(10).map do |h|
      {
        ticker: h[:ticker],
        security_name: h[:security_name],
        value: h[:value],
        formatted_value: Money.new(h[:value], family.currency).format,
        weight: total_portfolio_value > 0 ? (h[:value] / total_portfolio_value * 100).round(2) : 0,
        gain_loss_percent: h[:gain_loss_percent].round(2)
      }
    end

    # Asset allocation by exchange
    exchange_allocation = all_holdings.group_by { |h| h[:exchange] || "UNKNOWN" }
      .map do |exchange, holdings|
        exchange_value = holdings.sum { |h| h[:value] }
        {
          exchange: exchange,
          weight: total_portfolio_value > 0 ? (exchange_value / total_portfolio_value * 100).round(2) : 0,
          formatted_total_value: Money.new(exchange_value, family.currency).format
        }
      end
      .sort_by { |a| -a[:weight] }

    # Performance metrics
    winners = all_holdings.select { |h| h[:gain_loss] > 0 }
    losers = all_holdings.select { |h| h[:gain_loss] < 0 }
    total_gains = winners.sum { |h| h[:gain_loss] }
    total_losses = losers.sum { |h| h[:gain_loss] }

    best_performer = all_holdings.max_by { |h| h[:gain_loss_percent] }
    worst_performer = all_holdings.min_by { |h| h[:gain_loss_percent] }

    average_return = all_holdings.any? ? (all_holdings.sum { |h| h[:gain_loss_percent] } / all_holdings.size).round(2) : 0

    # Diversification scoring using Herfindahl index
    # Lower Herfindahl = more diversified (0-1 scale)
    # Convert to 0-100 score where 100 is perfectly diversified
    herfindahl_index = if total_portfolio_value > 0
      all_holdings.sum { |h| (h[:value] / total_portfolio_value) ** 2 }
    else
      0
    end

    # Perfect diversification (equal weights across N holdings) would give 1/N
    # We'll convert to a 0-100 scale where 100 means optimal diversification
    ideal_herfindahl = all_holdings.any? ? 1.0 / all_holdings.size : 0
    diversification_score = if herfindahl_index > 0
      # Lower is better, so we invert and scale
      ((ideal_herfindahl / herfindahl_index) * 100).round(1).clamp(0, 100)
    else
      0
    end

    # Interpret diversification score
    diversification_interpretation = case diversification_score
    when 90..100 then "Excellently diversified"
    when 75..89 then "Well diversified"
    when 60..74 then "Moderately diversified"
    when 40..59 then "Somewhat concentrated"
    when 20..39 then "Highly concentrated"
    else "Extremely concentrated"
    end

    # Concentration risk metrics
    largest_position = top_10_holdings.first
    largest_position_weight = largest_position ? largest_position[:weight] : 0
    top_5_concentration = top_10_holdings.take(5).sum { |h| h[:weight] }

    {
      total_portfolio_value: total_portfolio_value,
      formatted_total_portfolio_value: Money.new(total_portfolio_value, family.currency).format,
      total_gain_loss: total_gain_loss,
      formatted_total_gain_loss: Money.new(total_gain_loss, family.currency).format,
      total_gain_loss_percent: total_cost_basis > 0 ? (total_gain_loss / total_cost_basis * 100).round(2) : 0,

      accounts: {
        count: account_summaries.size,
        summaries: account_summaries
      },

      holdings: {
        total_count: all_holdings.size,
        unique_securities: all_holdings.map { |h| h[:ticker] }.uniq.size,
        top_10: top_10_holdings
      },

      allocation: {
        by_exchange: exchange_allocation
      },

      performance: {
        winners_count: winners.size,
        losers_count: losers.size,
        total_gains: total_gains,
        formatted_total_gains: Money.new(total_gains, family.currency).format,
        total_losses: total_losses,
        formatted_total_losses: Money.new(total_losses, family.currency).format,
        best_performer: best_performer ? {
          ticker: best_performer[:ticker],
          security_name: best_performer[:security_name],
          gain_loss_percent: best_performer[:gain_loss_percent].round(2)
        } : nil,
        worst_performer: worst_performer ? {
          ticker: worst_performer[:ticker],
          security_name: worst_performer[:security_name],
          gain_loss_percent: worst_performer[:gain_loss_percent].round(2)
        } : nil,
        average_return: average_return
      },

      diversification: {
        diversification_score: diversification_score,
        interpretation: diversification_interpretation,
        largest_position_weight: largest_position_weight,
        largest_position_ticker: largest_position ? largest_position[:ticker] : nil,
        top_5_concentration: top_5_concentration.round(2)
      }
    }
  end
end
