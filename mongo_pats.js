//OWNERS COLLECTION â€“ PATS_mongo

// To be safe, drop any prior collections
db.owners.drop();
db.pets.drop();

// set up some owners
var doc1 = {
  "name": {"first": "Ed", "last": "Gruberman"},
  "street": "1600 Bigelow Blvd",
  "city": "Pittsburgh",
  "state": "PA",
  "zip": "15213",
  "phone": "4122688211",
  "email": "gruberman@example.com"
};

var doc2 = {
  "name": {"first": "Ted", "last": "Gruberman"},
  "street": "1600 Bigelow Blvd",
  "city": "Pittsburgh",
  "state": "PA",
  "zip": "15213",
  "phone": "4122688211",
  "email": "tgruberman@example.com"
};

var doc3 = {
  "name": {"first": "Selina", "last": "Kyle"},
  "street": "143 North Avenue",
  "city": "Pittsburgh",
  "state": "PA",
  "zip": "15237",
  "phone": "4123492409",
  "email": "kittykat@yippee.com"
};

var doc4 = {
  "name": {"first": "Harvey", "last": "Dent"},
  "street": "5001 Forbes Avenue",
  "city": "Pittsburgh",
  "state": "PA",
  "zip": "15213",
  "phone": "4122680551",
  "email": "hdent@gotham.gov"
};

var doc5 = {
  "name": {"first": "Bruce", "last": "Wayne"},
  "street": "One Wayne Manor",
  "city": "Sewickley",
  "state": "PA",
  "zip": "15143",
  "phone": "4127414015",
  "email": "bruce@wayne.com"
};

var doc6 = {
  "name": {"first": "Harvey", "last": "Bullock"},
  "street": "5005 Forbes Avenue",
  "city": "Pittsburgh",
  "state": "PA",
  "zip": "15213",
  "phone": "4122682323",
  "email": "hbullock@gotham.gov"
};

// insert the documents into owners collection
db.owners.insert(doc1);
db.owners.insert(doc2);
db.owners.insert(doc3);
db.owners.insert(doc4);
db.owners.insert(doc5);
db.owners.insert(doc6);

// create variables for 
var ed = db.owners.findOne({"name.first": "Ed", "name.last": "Gruberman"});
var ted = db.owners.findOne({"name.first": "Ted", "name.last": "Gruberman"});
var selina = db.owners.findOne({"name.last": "Kyle"});
var harvey = db.owners.findOne({"name.last": "Dent"});
var bullock = db.owners.findOne({"name.last": "Bullock"});
var bruce = db.owners.findOne({"name.last": "Wayne"});

â€ƒ
// PETS COLLECTION â€“ PATS_mongo

// insert some pets directly
db.pets.insert({
  "animal": "dog",
  "owner_id": ed._id,
  "name": "Zaphod",
  "gender": "m",
  "date_of_birth": "2004-10-27",
  "color": ["black", "white"]
});

db.pets.insert({
  "animal": "dog",
  "owner_id": ted._id,
  "name": "Beeblebrox",
  "gender": "m",
  "date_of_birth": "2007-10-28",
  "color": ["brown", "white"],
  "visits": [
    {
      "date": "2008-01-02",
      "weight": 23
    },
    {
      "date": "2009-03-01",
      "weight": 34
    }
  ]
});

db.pets.insert({
  "animal": "ferret",
  "owner_id": bullock._id,
  "date_of_birth": "2010-10-31",
  "gender": "m",
  "name": "Snitch",
  "color": ["brown"],
  "visits": [
    {
      "date": "2011-10-31",
      "weight": 2
    }
  ]
});

db.pets.insert({
  "animal": "rabbit",
  "owner_id": harvey._id,
  "name": "Killer",
  "gender": "m",
  "date_of_birth": "2009-03-15"
});

db.pets.insert({
  "animal": "cat",
  "owner_id": selina._id,
  "name": "Isis",
  "gender": "f",
	"color": ["black"],
  "date_of_birth": "2008-04-01",
  "visits": [
    {
      "date": "2009-10-01",
      "weight": 2
    },
    {
      "date": "2010-08-30",
      "weight": 3
    },
    {
      "date": "2011-11-11",
      "weight": 4
    },
    {
      "date": "2013-09-30",
      "weight": 4
    }
  ]
});

db.pets.insert({
  "animal": "cat",
  "owner_id": selina._id,
  "name": "Artemis",
  "gender": "f",
	"color": ["white"],
  "date_of_birth": "2009-05-01",
  "visits": [
    {
      "date": "2009-12-01",
      "weight": 2
    },
    {
      "date": "2010-08-30",
      "weight": 3
    },
    {
      "date": "2011-11-11",
      "weight": 3
    },
    {
      "date": "2012-06-30",
      "weight": 4
    },
    {
      "date": "2013-09-30",
      "weight": 3
    }
  ]
});
