class Trend
  include ActiveModel::Validations

  DIRECTIONS = %w[up down].freeze

  attr_reader :current, :previous, :favorable_direction

  validates :current, presence: true

  def initialize(current:, previous:, favorable_direction: nil)
    @current = current
    @previous = previous || 0
    @favorable_direction = (favorable_direction.presence_in(DIRECTIONS) || "up").inquiry

    validate!
  end

  def direction
    # Use float comparisons to avoid Money comparison issues
    current_val = current.respond_to?(:to_f) ? current.to_f : current
    previous_val = previous.respond_to?(:to_f) ? previous.to_f : previous
    
    if current_val == previous_val
      "flat"
    elsif current_val > previous_val
      "up"
    else
      "down"
    end.inquiry
  end

  def color
    case direction
    when "up"
      favorable_direction.down? ? red_hex : green_hex
    when "down"
      favorable_direction.down? ? green_hex : red_hex
    else
      gray_hex
    end
  end

  def icon
    if direction.flat?
      "minus"
    elsif direction.up?
      "arrow-up"
    else
      "arrow-down"
    end
  end

  def value
    # Use float arithmetic to avoid CoercedNumeric struct issues
    if current.respond_to?(:to_f) && previous.respond_to?(:to_f)
      current.to_f - previous.to_f
    else
      current - previous
    end
  end

  def percent
    return 0.0 if previous.to_f == 0 && current.to_f == 0
    return Float::INFINITY if previous.to_f == 0

    # Use float arithmetic to avoid CoercedNumeric struct issues
    change = current.respond_to?(:to_f) ? current.to_f - previous.to_f : (current - previous).to_f

    (change / previous.to_f * 100).round(1)
  end

  def percent_formatted
    if percent.finite?
      "#{percent.round(1)}%"
    else
      percent > 0 ? "＋∞" : "-∞"
    end
  end

  def as_json
    {
      value: value,
      percent: percent,
      percent_formatted: percent_formatted,
      current: current,
      previous: previous,
      color: color,
      icon: icon
    }
  end

  private
    def red_hex
      "var(--color-destructive)"
    end

    def green_hex
      "var(--color-success)"
    end

    def gray_hex
      "var(--color-gray)"
    end
end
