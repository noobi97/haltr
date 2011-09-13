class InvoiceLine < ActiveRecord::Base

  unloadable

  UNITS     = 1
  HOURS     = 2
  KILOGRAMS = 3
  LITTERS   = 4
  DAYS      = 5

  UNIT_CODES = {
    UNITS     => {:name => 'units',     :facturae => '01', :ubl => 'C62'},
    HOURS     => {:name => 'hours',     :facturae => '02', :ubl => 'HUR'},
    KILOGRAMS => {:name => 'kilograms', :facturae => '03', :ubl => 'KGM'},
    LITTERS   => {:name => 'litters',   :facturae => '04', :ubl => 'LTR'},
    DAYS      => {:name => 'days',      :facturae => '05', :ubl => 'DAY'},
  }

  belongs_to :invoice
  has_many :taxes, :class_name => "Tax", :order => "percent", :dependent => :destroy
  validates_presence_of :description, :unit
  validates_numericality_of :quantity, :price
  attr_accessor :new_and_first

  # remove colons "1,23" => "1.23"
  def price=(v)
    write_attribute :price, (v.is_a?(String) ? v.gsub(',','.') : v)
  end

  # remove colons "1,23" => "1.23"
  def quanity=(v)
    write_attribute :quantity, (v.is_a?(String) ? v.gsub(',','.') : v)
  end

  def initialize(attributes=nil)
    super
    update_currency
  end

  def taxable_base
    Money.new((price * quantity * 100).round.to_i, currency)
  end

  def to_label
    description
  end

  def template_replacements(date=nil)
    Utils.replace_dates! description, (date || Date.today) +  (invoice.frequency || 0).months
  end

  def tax_amount(tax_type=nil)
    line_tax = Money.new(0,currency)
    taxes.each do |tax|
      line_tax += taxable_base * (tax.percent / 100.0) if tax_type.nil? or tax == tax_type
    end
    line_tax
  end

  def has_tax?(tax_type)
    return true if tax_type.nil?
    taxes.each do |tax|
      return true if tax.name == tax_type.name and tax.percent == tax_type.percent
    end
    false
  end

  def self.units
    UNIT_CODES.collect { |k,v|
      [l(v[:name]), k]
    }
  end

  def unit_code(format)
    UNIT_CODES[unit][format]
  end

  def unit_short
    l("s_#{UNIT_CODES[unit][:name]}")
  end

  def attributes=(args)
    self.taxes=[]
    args.keys.each do |k|
      if k =~ /^tax_[a-zA-Z]+$/
        percent=args.delete(k)
        next if percent.blank?
        self.taxes << Tax.new(:name=>k.gsub(/^tax_/,''),:percent=>percent)
      end
    end
    super
  end

  def taxes_withheld
    taxes.find(:all, :conditions => "percent < 0")
  end

  def taxes_outputs
    taxes.find(:all, :conditions => "percent > 0")
  end

  # expenses are invoice lines of reimbursable expenses, payments advanced for the client
  # not subject to taxes. We consider expenses each line that has no taxes.
  def expenses?
    are_expenses = true
    taxes.each do |tax|
      are_expenses &= (tax.percent.nil? || tax.percent == 0)
    end
    are_expenses
  end

  private

  def update_currency
    self.currency = self.invoice.currency rescue nil
    self.currency ||= self.invoice.client.currency rescue nil
    self.currency ||= self.invoice.company.currency rescue nil
    self.currency ||= Setting.plugin_haltr['default_currency']
  end

  def method_missing(m, *args)
#    if m.to_s =~ /^tax_[a-zA-Z]=$+/ and args.size == 1
#      self.taxes << Tax.new(:name=>m.to_s.gsub(/tax_/,'').gsub(/=$/,''),:percent=>args[0])
    if m.to_s =~ /^tax_[a-zA-Z]+/ and args.size == 0
      curr_tax = taxes.find_by_name(m.to_s.gsub(/tax_/,''))
      return curr_tax.nil? ? 0 : curr_tax.percent
    else
      super
    end
  end

end

