class BalanceSheet
  include Monetizable

  monetize :net_worth

  attr_reader :family

  def initialize(family)
    @family = family
  end

  def assets
    @assets ||= ClassificationGroup.new(
      classification: "asset",
      currency: family.currency,
      accounts: account_totals.asset_accounts
    )
  end

  def liabilities
    @liabilities ||= ClassificationGroup.new(
      classification: "liability",
      currency: family.currency,
      accounts: account_totals.liability_accounts
    )
  end

  def classification_groups
    [ assets, liabilities ]
  end

  def account_groups
    [ assets.account_groups, liabilities.account_groups ].flatten
  end

  def net_worth
    assets_total = assets.total
    liabilities_total = liabilities.total
    
    # Ensure both are Money objects before arithmetic
    assets_money = assets_total.is_a?(Money) ? assets_total : Money.new(assets_total || 0, currency)
    liabilities_money = liabilities_total.is_a?(Money) ? liabilities_total : Money.new(liabilities_total || 0, currency)
    
    # Use float arithmetic to avoid CoercedNumeric struct issues
    Money.new(assets_money.to_f - liabilities_money.to_f, currency)
  end

  def net_worth_series(period: Period.last_30_days)
    net_worth_series_builder.net_worth_series(period: period)
  end

  def currency
    family.currency
  end

  def syncing?
    sync_status_monitor.syncing?
  end

  private
    def sync_status_monitor
      @sync_status_monitor ||= SyncStatusMonitor.new(family)
    end

    def account_totals
      @account_totals ||= AccountTotals.new(family, sync_status_monitor: sync_status_monitor)
    end

    def net_worth_series_builder
      @net_worth_series_builder ||= NetWorthSeriesBuilder.new(family)
    end
end
