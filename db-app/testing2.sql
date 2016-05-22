﻿--updat home bay stored procedure
--------------------------------------------------------
CREATE OR REPLACE FUNCTION updateHomebay(e_mail VARCHAR,bname VARCHAR)
RETURNS VARCHAR
AS $$
DECLARE
bid INT;
bn VARCHAR;
BEGIN
  bid:=(SELECT bayid FROM carsharing.carbay WHERE name =bname) ;
  UPDATE carsharing.member SET homebay = bid  
  WHERE email = e_mail;
  bn := (SELECT name FROM carsharing.carbay WHERE bayid=bid);
  RETURN bn;
END;
$$LANGUAGE 'plpgsql';
DROP FUNCTION updatehomebay(character varying,character varying)
SELECT updateHomebay('MrajayBains@gmail.com','Darlinghurst - Crown Street')

--------------------------------------------------------



CREATE OR REPLACE FUNCTION makeBooking(car_rego VARCHAR,e_mail VARCHAR,date varchar,hour int,duration int)
RETURNS BOOLEAN 
AS $$
DECLARE
member INT;
stime TIMESTAMP;
etime TIMESTAMP;
nrb INT;
BEGIN 
  stime := (SELECT to_timestamp(date,'YYYY-MM-DD') + hour *interval'1 hour');
  --add starttime checking constraint in table to forbid member book car in the past
  IF(stime>now()) THEN
    etime := (stime + duration *interval '1 hour');
    member := (SELECT memberno FROM carsharing.member WHERE email=e_mail);
    nrb := (SELECT stat_nrofbookings FROM carsharing.member WHERE email = $2);
    INSERT INTO carsharing.Booking(car,madeby,whenbooked,starttime,endtime)
    VALUES (car_rego,member,now(),stime,etime);
  ELSE
    RAISE EXCEPTION 'No booking made in past';
  END IF;
  RETURN true;
END;
$$LANGUAGE 'plpgsql';

---check overlapping booking
CREATE OR REPLACE
FUNCTION OverlappingTime()
RETURNS trigger AS $$
DECLARE
rec RECORD;
BEGIN
    --refresh my view everytime I need to insert my table.
    REFRESH MATERIALIZED VIEW CONCURRENTLY carsharing.reservation;
    --refactor this carsharing.booking to my materialised view reservation
     FOR rec IN SELECT starttime,  endtime FROM reservation WHERE car = NEW.car
    LOOP
        IF (rec.starttime, rec.endtime) OVERLAPS (NEW.starttime, NEW.endtime) THEN
            RAISE EXCEPTION 'Overlapping booking';
        END IF;
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

---triger check overlap trigger and refresh the materialised view---
CREATE TRIGGER CheckOverlappingTime
BEFORE INSERT OR UPDATE ON carsharing.Booking
FOR EACH ROW
EXECUTE PROCEDURE OverlappingTime();

CREATE OR REPLACE FUNCTION incrementNumberOfBooking()
RETURNS trigger AS $$
DECLARE
nrb INT;
BEGIN
    nrb := (SELECT stat_nrofbookings FROM carsharing.member WHERE memberno = NEW.madeby);
    UPDATE carsharing.member SET stat_nrofbookings=nrb+1 WHERE memberno = NEW.madeby;
    return old;
END;
$$ LANGUAGE plpgsql;

---triger update member statistic number of booking ---
CREATE TRIGGER updateMemberStatOfBooking
AFTER INSERT ON carsharing.Booking
FOR EACH ROW
EXECUTE PROCEDURE incrementNumberOfBooking();


SELECT * from makebooking('AT61LA','MrajayBains@gmail.com','2019-05-20',12,4);

SELECT stat_nrofbookings FROM CARSHARING.MEMBER WHERE EMAIL = 'MrajayBains@gmail.com'

delete from carsharing.booking where car='AT61LA' 

SELECT * from carsharing.booking where car='AT61LA'

SELECT (to_timestamp('2017-05-20','YYYY-MM-DD') + 17 *interval'1hour')

--------------------------------------------------------

CREATE OR REPLACE FUNCTION getCarsInBay(bname VARCHAR)
RETURNS TABLE(reg REGOTYPE,cn VARCHAR)
AS $$
BEGIN
 RETURN QUERY SELECT regno, name 
 FROM carsharing.car 
 WHERE parkedat = ( 
 SELECT bayid 
 FROM carsharing.carbay 
 WHERE name = bname);
END;
$$LANGUAGE 'plpgsql';


select * from getCarsInBay('Erskineville - Erskineville Road')

--------------------------------------------------------
CREATE OR REPLACE FUNCTION getAllBooking(e_mail varchar)
RETURNS table(car regotype,name varchar,date date,hour int,stime timestamp) 
AS $$
BEGIN
  Return QUERY SELECT b.car AS car, c.name AS name , 
  cast(b.starttime as date) 
  AS date ,
  cast( EXTRACT(HOUR FROM starttime) as int )AS hour ,b.starttime
  FROM carsharing.Booking AS b join carsharing.Car As C ON b.car = regno 
            WHERE b.madeby = (SELECT memberno FROM carsharing.member WHERE email=e_mail)
  ORDER BY b.starttime DESC;
END;
$$  
LANGUAGE 'plpgsql'


drop function getAllBooking(varchar)
SELECT * from getAllBooking('MrajayBains@gmail.com') ;

--------------------------------------------------------
CREATE OR REPLACE FUNCTION fetchBays(searchTerm text)
RETURNS TABLE(name VARCHAR, address VARCHAR, nrOfCar BIGINT)
AS $$
BEGIN
  searchTerm := '%'||searchTerm||'%';
  RETURN QUERY SELECT b.name , b.address, 
  count(c.regno) FROM carsharing.carbay as b JOIN carsharing.car as c
  ON b.bayid = c.parkedat WHERE b.name ILIKE searchTerm or 
  b.address ILIKE searchTerm
  GROUP BY bayid ;
 END;
 $$LANGUAGE 'plpgsql';

select cast(now() as date)


SELECT * from fetchBays('Road') 


--------------------------------------------------------
CREATE OR REPLACE FUNCTION getBay(n VARCHAR)
RETURNS TABLE( bname VARCHAR, descr text,
 addr VARCHAR,gpsLat FLOAT,gpsLong FLOAT,walkscore INT) AS $$
BEGIN
 RETURN QUERY 
 SELECT name ,description,address,gps_lat,gps_long, cb.walkscore
 FROM carbay cb WhERE cb.name =n;
 END;
 $$LANGUAGE 'plpgsql';

SELECT *from getBay('Erskineville - Erskineville Road') AS (name ,description, address,gps_lat,gps_long)

DROP FUNCTION getbay(character varying)


--------------------------------------------------------
CREATE OR REPLACE FUNCTION getAllBays()
RETURNS TABLE(name VARCHAR,address VARCHAR, nrOfCar BIGINT)
AS $$
BEGIN
  RETURN QUERY SELECT carsharing.carbay.name , carsharing.carbay.address, 
  count(carsharing.car.regno) FROM carsharing.carbay  JOIN carsharing.car 
  ON bayid = parkedat GROUP BY bayid;
 END;
 $$LANGUAGE 'plpgsql';

SELECT * FROM GETALLBAYS();



--------------------------------------------------------
CREATE OR REPLACE FUNCTION getCarDetail(rego varchar)
RETURNS TABLE(regno regotype,name varchar,make varchar,
model varchar,year int,transmission varchar,category varchar,
capacity int,bay varchar,walkscore int,mapurl varchar)
AS $$
BEGIN
  RETURN QUERY SELECT c.regno,c.name, c.make, c.model, c.year,c.transmission, 
  m.category,m.capacity, b.name, b.walkscore,b.mapurl 
  FROM carsharing.car AS c NATURAL JOIN carsharing.carmodel as m
  JOIN carsharing.carbay AS b ON parkedat=bayid WHERE c.regno = rego;
 END;
 $$LANGUAGE 'plpgsql';


Select * From getCarDetail('AN83WT');

--------------------------------------------------------
CREATE OR REPLACE FUNCTION fetchbooking(b_car char(6),b_date date,b_hour int)
RETURNS TABLE (
  mname text, 
  car regotype,
  cname varchar,
  date date,
  hour int,
  duration int,
  madeday text,
  bay varchar,
  cost float)
AS $$
BEGIN
  RETURN QUERY 
 SELECT m.namegiven||' '||m.namefamily, b.car, c.name, 
    cast(b.starttime as date) AS date, 
    cast(EXTRACT(HOUR FROM starttime) as int) as hour ,
    cast(EXTRACT(EPOCH FROM endtime-starttime) as int)/3600 AS duration,
    to_char(b.whenbooked,'DD-MM-YYYY')  AS madeday , cb.name as bay 
    , cast(EXTRACT(EPOCH FROM endtime-starttime) as float)/3600*(
      SELECT hourly_rate FROM carsharing.membershipplan
      WHERE title =m.subscribed 
    ) as cost
    FROM carsharing.booking AS b 
      JOIN carsharing.car AS C ON b.car=regno 
      JOIN carsharing.member AS m ON b.madeby= m.memberno 
      JOIN carsharing.carbay as cb ON c.parkedat=cb.bayid 
    WHERE b.car=$1 AND cast(b.starttime as date) =$2 
      AND EXTRACT(HOUR FROM starttime) = $3;


END;
$$ LANGUAGE 'plpgsql'

DROP FUNCTION fetchbooking(character,character varying,integer)

SELECT * FROM fetchbooking('AN83WT','3424-02-03',17) ;


CREATE MATERIALIZED VIEW carsharing.Reservation
AS
 SELECT car,starttime,endtime
   FROM carsharing.booking
   WHERE starttime > now()
   order by starttime desc
  with data;

CREATE UNIQUE INDEX DATE_TIME ON RESERVATION (car,starttime);

SELECT car,starttime,  endtime FROM carsharing.Reservation --WHERE car ='AT61LA'

DROP MATERIALIZED VIEW Reservation