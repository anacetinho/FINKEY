class PagesController < ApplicationController
  include Periodable

  skip_authentication only: :redis_configuration_error

  def dashboard
    # Cache expensive calculations for 5 minutes to improve performance
    cache_key = "dashboard_#{Current.family.id}_#{params[:cashflow_period] || 'last_30_days'}_#{Current.family.updated_at.to_i}"

    @balance_sheet, @accounts, @cashflow_sankey_data = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      balance_sheet = Current.family.balance_sheet
      accounts = Current.family.accounts.visible.includes(:logo_attachment)

      period_param = params[:cashflow_period]
      cashflow_period = if period_param.present?
        begin
          Period.from_key(period_param)
        rescue Period::InvalidKeyError
          Period.last_30_days
        end
      else
        Period.last_30_days
      end

      family_currency = Current.family.currency
      income_totals = Current.family.income_statement.income_totals(period: cashflow_period)
      expense_totals = Current.family.income_statement.expense_totals(period: cashflow_period)

      sankey_data = build_cashflow_sankey_data(income_totals, expense_totals, family_currency)

      [balance_sheet, accounts, sankey_data]
    end

    # Set period for view (not cached since it's simple)
    @cashflow_period = if params[:cashflow_period].present?
      begin
        Period.from_key(params[:cashflow_period])
      rescue Period::InvalidKeyError
        Period.last_30_days
      end
    else
      Period.last_30_days
    end

    @breadcrumbs = [ [ "Home", root_path ], [ "Dashboard", nil ] ]
  end

  def changelog
    # Static FinKey release notes
    @release_notes = {
      avatar: nil,
      username: "finkey-contributors",
      name: "FinKey v1.5",
      published_at: Date.new(2026, 3, 14),
      body: <<~HTML
        <h1>What's New in v1.5</h1>
        
        <h2>📊 Yearly Budget Totals</h2>
        <ul>
          <li><strong>Aggregated Yearly Views</strong>: You can now view your entire year's budget at a glance. Simply click on the year in the budget picker to see yearly totals, monthly averages, and aggregated spending breakdown.</li>
          <li><strong>Budget Management</strong>: Added the ability to deactivate/reset budgets for individual months if you need to start your planning over.</li>
        </ul>

        <h2>📈 Advanced Forecasting</h2>
        <ul>
          <li><strong>Rolling 12-Month Averages</strong>: The forecasting engine now uses a stable 12-month rolling average for income and expenses. This provides a much more accurate baseline for projections by smoothing out one-time windfalls or unusual spending months.</li>
          <li><strong>Historical Context</strong>: The forecast chart now shows 2 years of historical net worth data alongside your projections for better long-term perspective.</li>
        </ul>

        <h2>💰 Holding Enhancements</h2>
        <ul>
          <li><strong>Manual Holding Management</strong>: Full support for holdings not available via public APIs. You can now flag instruments as "manually managed" to prevent automatic overrides and enter prices manually.</li>
          <li><strong>Multi-Currency Cost Basis</strong>: Holdings now use real-time exchange rates to calculate average cost basis and performance trends accurately across different currencies.</li>
        </ul>

        <hr>

        <h2>Previous Updates (v1.4)</h2>
        <ul>
          <li><strong>🔧 Fixed Local AI Model Caching Issue</strong> - Local LLM model changes now take effect immediately without requiring a server restart.</li>
        </ul>

        <h2>Key Features</h2>
        <ul>
          <li><strong>🤖 Flexible AI Assistant</strong> - OpenAI or local LLM with full UI configuration</li>
          <li><strong>🌍 Yahoo Finance Integration</strong> - Real-time exchange rates for accurate multi-currency tracking</li>
          <li><strong>💸 Advanced Expense Reimbursement System</strong> - Handle complex transaction scenarios</li>
          <li><strong>📊 Extended Forecasting</strong> - 24-month projections with trend analysis</li>
        </ul>
      HTML
    }

    render layout: "settings"
  end

  def feedback
    render layout: "settings"
  end

  def redis_configuration_error
    render layout: "blank"
  end

  private
    def github_provider
      Provider::Registry.get_provider(:github)
    end

    def build_cashflow_sankey_data(income_totals, expense_totals, currency_symbol)
      nodes = []
      links = []
      node_indices = {} # Memoize node indices by a unique key: "type_categoryid"

      # Helper to add/find node and return its index
      add_node = ->(unique_key, display_name, value, percentage, color) {
        node_indices[unique_key] ||= begin
          nodes << { name: display_name, value: value.to_f.round(2), percentage: percentage.to_f.round(1), color: color }
          nodes.size - 1
        end
      }

      total_income_val = income_totals.total.to_f.round(2)
      total_expense_val = expense_totals.total.to_f.round(2)

      # --- Create Central Cash Flow Node ---
      cash_flow_idx = add_node.call("cash_flow_node", "Cash Flow", total_income_val, 0, "var(--color-success)")

      # --- Process Income Side (Top-level categories only) ---
      income_totals.category_totals.each do |ct|
        # Skip subcategories – only include root income categories
        next if ct.category.parent_id.present?

        val = ct.total.to_f.round(2)
        next if val.to_f == 0

        percentage_of_total_income = total_income_val.to_f == 0 ? 0 : (val / total_income_val * 100).round(1)

        node_display_name = ct.category.name
        node_color = ct.category.color.presence || Category::COLORS.sample

        current_cat_idx = add_node.call(
          "income_#{ct.category.id}",
          node_display_name,
          val,
          percentage_of_total_income,
          node_color
        )

        links << {
          source: current_cat_idx,
          target: cash_flow_idx,
          value: val,
          color: node_color,
          percentage: percentage_of_total_income
        }
      end

      # --- Process Expense Side (Top-level categories only) ---
      expense_totals.category_totals.each do |ct|
        # Skip subcategories – only include root expense categories to keep Sankey shallow
        next if ct.category.parent_id.present?

        val = ct.total.to_f.round(2)
        next if val.to_f == 0

        percentage_of_total_expense = total_expense_val.to_f == 0 ? 0 : (val / total_expense_val * 100).round(1)

        node_display_name = ct.category.name
        node_color = ct.category.color.presence || Category::UNCATEGORIZED_COLOR

        current_cat_idx = add_node.call(
          "expense_#{ct.category.id}",
          node_display_name,
          val,
          percentage_of_total_expense,
          node_color
        )

        links << {
          source: cash_flow_idx,
          target: current_cat_idx,
          value: val,
          color: node_color,
          percentage: percentage_of_total_expense
        }
      end

      # --- Process Surplus ---
      leftover = (total_income_val - total_expense_val).round(2)
      if leftover.to_f > 0
        percentage_of_total_income_for_surplus = total_income_val.to_f == 0 ? 0 : (leftover / total_income_val * 100).round(1)
        surplus_idx = add_node.call("surplus_node", "Surplus", leftover, percentage_of_total_income_for_surplus, "var(--color-success)")
        links << { source: cash_flow_idx, target: surplus_idx, value: leftover, color: "var(--color-success)", percentage: percentage_of_total_income_for_surplus }
      end

      # Update Cash Flow and Income node percentages (relative to total income)
      if node_indices["cash_flow_node"]
        nodes[node_indices["cash_flow_node"]][:percentage] = 100.0
      end
      # No primary income node anymore, percentages are on individual income cats relative to total_income_val

      { nodes: nodes, links: links, currency_symbol: Money::Currency.new(currency_symbol).symbol }
    end
end
