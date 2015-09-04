require 'net/http'
require 'uri'
require 'json'
require 'set'
require 'date'

# monkey patches

class String

  # squish from ActiveSupport
  # http://apidock.com/rails/v4.2.1/String/squish%21
  def squish
    gsub(/\A[[:space:]]+/, '').
    gsub(/[[:space:]]+\z/, '').
    gsub(/[[:space:]]+/, ' ')
  end

end

# App

# Loop through the paginated api requests to download all the tranactions
def download_raw_transactions
  transactions = []
  total_transactions = nil
  page = 1

  while total_transactions.nil? || transactions.length < total_transactions
    url = "http://resttest.bench.co/transactions/#{page}.json"
    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)

    # only process 2XX responses, fail if you receive anything else others
    break if response.code.to_i / 100 != 2

    json = JSON.parse(response.body)

    transactions += json['transactions']

    total_transactions = json['totalCount']
    page = json['page'] + 1
  end

  transactions
end

CITIES = [ 'VANCOUVER', 'RICHMOND', 'CALGARY', 'MISSISSAUGA', 'ROVICTORIA' ]
PROVINCES = [ 'AB', 'BC', 'MB', 'NB', 'NL', 'NS', 'NT', 'NU', 'ON', 'PE', 'QC', 'SK', 'YT' ]
STOP_WORDS = [ 'PAYMENT', 'PAIEMENT', 'THANK YOU', 'MERCI' ]
ALL_STOP_WORDS_SET = (STOP_WORDS + CITIES + PROVINCES).to_set

# have to consider tokens with multiple words
def get_name_tokens(name)
  tokens = name.split(' ')

  all_tokens = []

  (1..(tokens.length)).each do |len|
    (0..(tokens.length - len)).each do |i|
      all_tokens << tokens[i, len]
    end
  end

  # sort longest first, to get the most exact matches sooner
  all_tokens.sort_by { |a| -a.length }
end

# remove words from the stop list
def remove_stop_words(str)
  tokens = get_name_tokens(str)

  s = str.dup

  tokens.each do |t|
    token_str = t.join(' ')
    s.gsub!(token_str, '') if ALL_STOP_WORDS_SET.include?(token_str)
  end

  s
end

# limitations
# - if there is a stop word in the vendor name, then it will remove it, i.e., VANCOUVER CABS => CABS
# - looking at the data, location is always at the end, modify to factor that into account
def clean_vendor_name(txn)
  name = txn['Company']

  # remove extra white space
  n = name.squish

  # remove currency conversions
  n = n.gsub(/\sCA x*[\d.]+ USD @ x*[\d.]+$/, ' ')

  # remove non alphanumeric tokens characters
  n = n.gsub(/\s[^\w\&]+\s/, ' ')

  # remove credit card info
  n = n.gsub(/x{3,}\d{4}/, '')

  # remove stop words
  n = remove_stop_words(n)

  # remove store numbers
  n = n.gsub(/\s\#\d+\s/, ' ')

  # remove extra white space one more time
  n = n.squish

  n = 'NO VENDOR NAME' if n == ''

  n
end

# Do any processing and conversions of the raw transactions
def process_transactions(txns)
  txns.collect do |txn|
    t = txn.dup
    t['Date'] = Date.strptime(txn['Date'],"%Y-%m-%d")
    t['Amount'] = (txn['Amount'].to_f * 100).to_i
    t['Clean Company'] = clean_vendor_name(t)
    t
  end
end

def calculate_total_balance(txns)
  txns.inject(0) { |memo, t| memo += t['Amount'] }
end

def calculate_category_totals(txns)
  categories = {}

  txns.each do |txn|
    if txn['Amount'] < 0
      categories[txn['Ledger']] ||= 0
      categories[txn['Ledger']] = categories[txn['Ledger']] + -txn['Amount']
    end
  end

  categories
end

def calculate_daily_balances(txns)
  sorted_txns = txns.sort_by { |txn| txn['Date'] }
  first_date = sorted_txns.first['Date']
  last_date = sorted_txns.last['Date']

  current_date = first_date

  index = 1
  totals = []
  current_date_total = 0

  while current_date <= last_date && index < sorted_txns.length
    if current_date == sorted_txns[index]['Date']
      current_date_total += sorted_txns[index]['Amount']
      index += 1
    else
      totals << [current_date, current_date_total]
      current_date = current_date + 1
      current_date_total = 0
    end
  end

  totals
end

raw_transactions = download_raw_transactions
processed_transactions = process_transactions(raw_transactions)
total_balance = calculate_total_balance(processed_transactions)
category_totals = calculate_category_totals(processed_transactions)
daily_balances = calculate_daily_balances(processed_transactions)

puts
puts '==== Total Balance ===='
puts

puts "#{total_balance < 0 ? '-' : ''}$#{sprintf '%.2f', (total_balance.abs / 100.0)}"

puts
puts '==== Category Expenses ===='
puts

category_totals.each_pair do |k,v|
  puts "#{k}: $#{sprintf '%.2f', (v / 100.0)}"
end

puts
puts '==== Daily Balances ===='
puts

daily_balances.each do |db|
  puts "#{db[0].to_s} :: #{db[1] < 0 ? '-' : ''}$#{sprintf '%.2f', (db[1].abs / 100.0)}"
end
