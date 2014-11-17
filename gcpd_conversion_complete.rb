# To convert the gcpd data from postgres to mongodb

require 'pg'
require 'mongo'

# set up connections
# conn_pg  = PG.connect( dbname: 'gcpd_mongo_1', port: 5432, host: 'localhost')
conn_pg  = PG.connect( dbname: 'gcpd_mongo_2', port: 5432, host: 'localhost')
conn_mdb = Mongo::Connection.new('localhost') # connect to MongoDB
mdb = conn_mdb['gcpd']  # connect to (or create) a db called 'gcpd'


# get officer data
officer_data = Array.new
conn_pg.exec("select * from mongo_officer_case_view") do |result|
  result.each do |row|
    officer_data << row
  end
end


# process that data
officer_collection = mdb['officers']  
officer_data.count.times do |r|
  # puts "#{officer_data[r]}"
  # extract the data
  officer_number = officer_data[r]['officer_id'].to_i
  first_name = officer_data[r]['first_name']
  last_name = officer_data[r]['last_name']
  rank = officer_data[r]['rank']
  unit = officer_data[r]['unit']
  joined_gcpd_on = officer_data[r]['joined_gcpd_on']
  cases_raw = officer_data[r]['cases'].split('","') unless officer_data[r]['cases'].nil?
  cases_array = Array.new
  unless cases_raw.nil?
    cases_raw.each do |cr|
      if cr == "{}"
        cases_hash = nil
      else
        cr.gsub!(/{/,'').gsub!(/}/,'')
        tmp = cr.split(',') 
        tmp.each{|c| cases_array << c.to_i unless c.nil?}
      end
    end
  end
  
  # create the document we will insert into our mongo collection
  doc_officer = { "_id" => officer_number,
         "officer_number" => officer_number, 
         "first_name"  => first_name,
         "last_name" => last_name,
         "rank" => rank,
         "unit" => unit,
         "joined_gcpd_on" => joined_gcpd_on
  }
  # get cases if present  
  doc_officer.merge!({"cases" => cases_array}) unless cases_array.empty?
  
  # finally ready to do the insert...
  id = officer_collection.insert(doc_officer)
end


# get data from postgres using special view (see bottom of file for copy)
case_data = Array.new
conn_pg.exec("select * from mongo_case_complete_view") do |result|
  result.each do |row|
    case_data << row
  end
end

# put the data into a collection called 'cases'
collection = mdb['cases']  # create a collection callled 'cases' within gcpd db
case_data.count.times do |r|
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
      # do some clean-up (as needed) on fn, ln, als
      first_name = fn.gsub(/{"/,'').strip unless fn.nil?
      last_name = ln.strip unless ln.nil?
      aka = als.gsub(/"}/,'').strip unless als.nil?
      # create a suspects_hash
      suspects_hash = {"first_name" => first_name, "last_name" => last_name}
      unless aka == ' ' || aka == '' || aka.nil?
        suspects_hash.merge!({"alias" => aka})
      end
    end
    # push the suspects hash into an array for use later
    suspects_array << suspects_hash unless suspects_hash.nil?
  end
  assignments_raw = case_data[r]['assigned_officers'].split('","') unless case_data[r]['assigned_officers'].nil?
  assignments_array = Array.new
  unless assignments_raw.nil?
    assignments_raw.each do |ar|
      if ar == "{}"
        assignments_hash = nil
      else
        ar.gsub!(/{/,'').gsub!(/}/,'')
        tmp = ar.split(',') 
        tmp.each{|a| assignments_array << a.to_i unless a.nil?}
      end
    end
  end
  
  # create the document we will insert into our mongo collection
  doc = { "_id" => case_id,
         "case_number" => case_id, 
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
  doc.merge!({"officers" => assignments_array}) unless assignments_array.empty?
  
  # finally ready to do the insert...
  id = collection.insert(doc)
end

# VIEWS USED ABOVE
# ===================
# CREATE OR REPLACE VIEW mongo_case_complete_view AS 
# SELECT cs.case_id, cr.name AS "crime_name", cs.crime_location
# , cs.date_opened, cs.date_closed
# , cs.solved, cs.batman_involved
# , coalesce((SELECT array_agg(cx.first_name || ', ' || cx.last_name || ', ' ||coalesce(cx.alias,'')) 
#   FROM criminals cx JOIN suspects sus USING (criminal_id) 
#   WHERE sus.case_id = cs.case_id),'{}') AS "suspects"
# , coalesce((SELECT array_agg(officer_id) 
#   FROM assignments ao WHERE ao.case_id = cs.case_id),'{}') AS "assigned_officers"
# FROM cases cs JOIN crimes cr USING (crime_id)
# ORDER BY cs.case_id;
# 
# CREATE VIEW mongo_officer_case_view AS
# SELECT o.officer_id, o.first_name, o.last_name
# , COALESCE(o.rank, 'Officer') AS rank, o.joined_gcpd_on
# , COALESCE(u.name, 'N/A') AS unit
# , COALESCE((SELECT array_agg(a1.case_id) AS array_agg 
#   FROM assignments a1 WHERE (a1.officer_id = o.officer_id)), '{}') AS cases 
# FROM (officers o LEFT JOIN units u USING (unit_id));