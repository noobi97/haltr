# to draw states graph execute:
#   rake state_machine:draw FILE=invoice.rb CLASS=ReceivedInvoice
class ReceivedInvoice < InvoiceDocument

  unloadable

  attr_accessor :md5
  after_create :create_event

  composed_of :subtotal,
    :class_name => "Money",
    :mapping => [%w(subtotal_in_cents cents), %w(currency currency_as_string)],
    :constructor => Proc.new { |cents, currency| Money.new(cents || 0, currency || Money.default_currency) }

  composed_of :withholding_tax,
    :class_name => "Money",
    :mapping => [%w(withholding_tax_in_cents cents), %w(currency currency_as_string)],
    :constructor => Proc.new { |cents, currency| Money.new(cents || 0, currency || Money.default_currency) }

  state_machine :state, :initial => :validating_format do
    before_transition do |invoice,transition|
      unless Event.automatic.include?(transition.event.to_s)
        Event.create(:name=>transition.event.to_s,:invoice=>invoice,:user=>User.current)
      end
    end

    event :success_validating_format do
      transition :validating_format => :validating_signature
    end
    event :error_validating_format do
      transition :validating_format => :received
    end
    event :discard_validating_format do
      transition :validating_format => :received
    end
    event :success_validating_signature do
      transition :validating_signature => :received
    end
    event :error_validating_signature do
      transition :validating_signature => :received
    end
    event :discard_validating_signature do
      transition :validating_signature => :received
    end
    event :refuse do
      transition [:accepted,:received] => :refused
    end
    event :accept do
      transition [:received] => :accepted
    end
    event :pay do
      transition :accepted => :paid
    end
  end

  def total
    import
  end

  def to_label
    "#{number}"
  end

  def past_due?
    #TODO
    false
  end

  def label
    l(self.class)
  end

  def valid_format?
    events.sort.each do |e|
      return true  if %w( success_validating_format ).include? e.name
      return false if %w( error_validating_format discard_validating_format ).include? e.name
    end
    return false
  end

  def valid_signature?
    events.sort.each do |e|
      return true  if %w( success_validating_signature ).include? e.name
      return false if %w( error_validating_signature discard_validating_signature ).include? e.name
    end
    return false
  end

  protected

  def create_event
    Event.create(:name=>'validating_format',:invoice=>self,:md5=>md5)
  end

end