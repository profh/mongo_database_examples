# A faster way to convert the gcpd data from postgres to mongodb

require 'pg'
require 'mongo'
require 'json/pure'

# set up connections
conn_pg  = PG.connect( dbname: 'gcpd_mongo_2', port: 5432, host: 'localhost')
conn_mdb = Mongo::Connection.new('localhost')
mdb = conn_mdb['gcpd_shortcut']

# move officer data
officer_collection = mdb['officers']
# taking advantage of postgres' 'row_to_json' function to convert each record to json quickly
conn_pg.exec("select row_to_json(mongo_officer_case_view) from mongo_officer_case_view") do |result|
  result.each do |row|
    # puts "#{row}"              # to see the original output
    data = row["row_to_json"]    # to just get the actual json
    data = JSON.parse(data.gsub('=>', ':'))  # parsing it so it can be inserted
    # puts "#{data.class} :: #{data}"
    officer_collection.insert(data)  # a new document is inserted
  end
end
