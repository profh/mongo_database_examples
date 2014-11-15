# This version is primarily for instructional purposes.
# To do a full conversion, use gcpd_conversion_complete.rb

require 'pg'
require 'mongo'

# set up connections
conn_pg  = PG.connect( dbname: 'gcpd_mongo_1', port: 5432, host: 'localhost')
conn_mdb = Mongo::Connection.new('localhost') # connect to MongoDB
mdb = conn_mdb['gcpd_cases']  # connect to (or create) a db called 'gcpd_cases'


# # get some output to test connection to pg (commented out)
# conn_pg.exec("select * from units") do |result|
#   puts "Unit ID |    Name"
#   result.each do |row|
#     puts "  #{row.values_at('unit_id')[0]}     |    #{row.values_at('name')[0]}"
#   end
# end


# get data from postgres using special view (see bottom of file for copy)
case_data = Array.new
conn_pg.exec("select * from mongo_case_criminal_view") do |result|
  result.each do |row|
    case_data << row
  end
end


# put the data into a collection called 'cases'
collection = mdb['cases']  # create a collection callled 'cases' within gcpd_cases db
51.times do |r|
  # extract the data
  case_id = case_data[r]['case_id'].to_i
  crime = case_data[r]['crime_name']
  location = case_data[r]['crime_location']
  opened = case_data[r]['date_opened']
  closed = case_data[r]['date_closed']
  solved = case_data[r]['solved']
  is_solved = (solved == 't' ? 1 : 0)
  batman_involved = case_data[r]['batman_involved']
  batman_helped = (batman_involved == "t" ? 1 : 0)
  suspects_raw = case_data[r]['suspects'].split('","') unless case_data[r]['suspects'].nil?
  suspects_array = Array.new
  suspects_raw.each do |sr|
    if sr == "{}"
      suspects_hash = nil
    else
      fn, ln, als = sr.split(',') # split the string into three parts
      # do some clean-up (as needed) on fn, als
      first_name = fn.gsub(/{"/,'').strip unless fn.nil?
      last_name = ln.strip unless ln.nil?
      aka = als.gsub(/"}/,'').strip unless als.nil?
      
      # print results to screen for sanity-check
      puts "#{case_id}: #{first_name} #{last_name} #{aka} => #{closed}"
      # create a suspects_hash
      suspects_hash = {"first_name" => first_name, "last_name" => last_name}
      unless aka == ' ' || aka == '' || aka.nil?
        suspects_hash.merge!({"alias" => aka})
      end
    end
    # push the suspects hash into an array for use later
    suspects_array << suspects_hash unless suspects_hash.nil?
  end
  
  # create the document we will insert into our mongo collection
  doc = {"case_number" => case_id, 
         "crime"  => crime,
         "location" => location,
         "date_opened" => opened,
         "solved" => is_solved,
         "batman_involved" => batman_helped
  }
  # get additional attributes if present  
  doc.merge!({"date_closed" => closed}) unless closed == 'null' || closed == ' ' || closed.nil?
  doc.merge!({"suspects" => suspects_array.first}) if suspects_array.size == 1
  doc.merge!({"suspects" => suspects_array}) if suspects_array.size > 1
  
  # finally ready to do the insert... (uncomment when ready to use)
  id = collection.insert(doc)
end


# The postgres view used above
# --------------------------------
# CREATE OR REPLACE VIEW mongo_case_criminal_view AS 
# SELECT cs.case_id, cr.name AS "crime_name", cs.crime_location
# , cs.date_opened, cs.date_closed
# , cs.solved, cs.batman_involved
# , coalesce((SELECT array_agg(cx.first_name || ', ' || cx.last_name || ', ' ||coalesce(cx.alias,'')) 
#     FROM criminals cx JOIN suspects sus USING (criminal_id) 
#     WHERE sus.case_id = cs.case_id),'{}') AS suspects
# FROM cases cs JOIN crimes cr USING (crime_id)
# ORDER BY cs.case_id;
