class Assistant::Function::GetHoldings < Assistant::Function
  class << self
    def name
      "get_holdings"
    end

    def description
      <<~INSTRUCTIONS
        Use this to see detailed holdings across all investment accounts with performance metrics.

        This function provides comprehensive portfolio data including:
        - Current holdings with quantities and values
        - Unrealized gains/losses ($ and %)
        - Cost basis calculations
        - Portfolio allocation percentages
        - Performance summary statistics

        Optionally filter by account name to see holdings for a specific account.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      properties: {
        account: {
          type: "string",
          description: "Optional: Filter holdings by account name",
          enum: family_account_names
        }
      }
    )
  end

  def call(params = {})
    account_scope = if params["account"].present?
      family.accounts.visible.where(name: params["account"])
    else
      family.accounts.visible
    end

    # Get all investment accounts with holdings
    investment_accounts = account_scope.joins(:holdings).distinct

    holdings_data = []
    total_portfolio_value = 0
    total_cost_basis = 0
    total_unrealized_gain_loss = 0

    investment_accounts.each do |account|
      account.holdings.includes(:security).each do |holding|
        current_value = holding.amount.to_f
        cost_basis = holding.avg_cost.to_f * holding.qty
        unrealized_gain_loss = current_value - cost_basis
        unrealized_gain_loss_percent = cost_basis > 0 ? (unrealized_gain_loss / cost_basis * 100) : 0

        holdings_data << {
          account_name: account.name,
          security_name: holding.security.name,
          ticker: holding.ticker,
          qty: holding.qty,
          price: holding.price,
          formatted_price: Money.new(holding.price, holding.currency).format,
          current_value: current_value,
          formatted_current_value: holding.amount_money.format,
          cost_basis: cost_basis,
          formatted_cost_basis: Money.new(cost_basis, holding.currency).format,
          unrealized_gain_loss: unrealized_gain_loss,
          formatted_unrealized_gain_loss: Money.new(unrealized_gain_loss, holding.currency).format,
          unrealized_gain_loss_percent: unrealized_gain_loss_percent.round(2),
          weight_in_portfolio: 0, # Will calculate after we know total
          weight_in_account: holding.weight&.round(2) || 0
        }

        total_portfolio_value += current_value
        total_cost_basis += cost_basis
        total_unrealized_gain_loss += unrealized_gain_loss
      end
    end

    # Calculate portfolio-level weights
    holdings_data.each do |h|
      h[:weight_in_portfolio] = total_portfolio_value > 0 ? (h[:current_value] / total_portfolio_value * 100).round(2) : 0
    end

    # Sort by value descending
    holdings_data.sort_by! { |h| -h[:current_value] }

    # Calculate summary statistics
    winners = holdings_data.select { |h| h[:unrealized_gain_loss] > 0 }
    losers = holdings_data.select { |h| h[:unrealized_gain_loss] < 0 }

    top_performer = holdings_data.max_by { |h| h[:unrealized_gain_loss_percent] }
    worst_performer = holdings_data.min_by { |h| h[:unrealized_gain_loss_percent] }

    avg_gain_loss_percent = holdings_data.any? ? (holdings_data.sum { |h| h[:unrealized_gain_loss_percent] } / holdings_data.size).round(2) : 0

    {
      total_holdings: holdings_data.size,
      total_portfolio_value: total_portfolio_value,
      formatted_total_portfolio_value: Money.new(total_portfolio_value, family.currency).format,
      holdings: holdings_data,
      summary: {
        total_unrealized_gain_loss: total_unrealized_gain_loss,
        formatted_total_unrealized_gain_loss: Money.new(total_unrealized_gain_loss, family.currency).format,
        total_unrealized_gain_loss_percent: total_cost_basis > 0 ? (total_unrealized_gain_loss / total_cost_basis * 100).round(2) : 0,
        total_cost_basis: total_cost_basis,
        formatted_total_cost_basis: Money.new(total_cost_basis, family.currency).format,
        average_gain_loss_percent: avg_gain_loss_percent,
        winners_count: winners.size,
        losers_count: losers.size,
        top_performer: top_performer ? {
          ticker: top_performer[:ticker],
          security_name: top_performer[:security_name],
          gain_loss_percent: top_performer[:unrealized_gain_loss_percent]
        } : nil,
        worst_performer: worst_performer ? {
          ticker: worst_performer[:ticker],
          security_name: worst_performer[:security_name],
          gain_loss_percent: worst_performer[:unrealized_gain_loss_percent]
        } : nil
      }
    }
  end
end
