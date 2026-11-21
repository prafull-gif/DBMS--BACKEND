-- =====================================================================
-- seed_002.sql  |  MySQL 8.0
-- Run AFTER migration_001.sql.
-- Real NSUT societies (46), events for the landing page, demo accounts.
-- Demo password for every account: Demo@123
-- Things marked DEMO are sample data. Replace them with real data later.
-- =====================================================================
USE society_events;

-- ---------------------------------------------------------------------
-- 1. Rename the 4 clubs from seed.sql to real societies (keeps their members and events)
-- ---------------------------------------------------------------------
UPDATE Club SET club_name='DevComm', tagline='Development community', category='Technical', sub_category='Technical', about='Development community. Workshops, contests and events run through the year.', contact_email='devcomm@nsut.example' WHERE club_id=1;
UPDATE Club SET club_name='Ashwamedh', tagline='Dramatic society', category='Cultural', sub_category='Cultural', about='Dramatic society. Workshops, contests and events run through the year.', contact_email='ashwamedh@nsut.example' WHERE club_id=2;
UPDATE Club SET club_name='Crescendo', tagline='Music society', category='Cultural', sub_category='Cultural', about='Music society. Workshops, contests and events run through the year.', contact_email='crescendo@nsut.example' WHERE club_id=3;
UPDATE Club SET club_name='ARES Robotics', tagline='Robotics society', category='Technical', sub_category='Technical', about='Robotics society. Workshops, contests and events run through the year.', contact_email='aresrobotics@nsut.example' WHERE club_id=4;

-- ---------------------------------------------------------------------
-- 2. The other 42 societies. faculty_id is spread over the 4 faculty
--    members as a DEMO (every club needs one faculty in charge).
-- ---------------------------------------------------------------------
INSERT INTO Club (club_name, faculty_id, category, sub_category, tagline, about, contact_email, registration_open) VALUES
('IEEE NSUT',1,'Technical','Technical','IEEE student branch','IEEE student branch. Workshops, contests and events run through the year.','ieeensut@nsut.example',0),
('The Debugging Society',2,'Technical','Technical','The Debugging Society','The Debugging Society. Workshops, contests and events run through the year.','thedebuggingsociety@nsut.example',0),
('GDG NSUT',3,'Technical','Technical','Google Developer Group (earlier GDSC)','Google Developer Group (earlier GDSC). Workshops, contests and events run through the year.','gdgnsut@nsut.example',1),
('ASN',4,'Technical','Technical','Algorithm Society of NSUT','Algorithm Society of NSUT. Workshops, contests and events run through the year.','asn@nsut.example',1),
('Nakshatra',1,'Technical','Technical','Astronomy and mathematics society','Astronomy and mathematics society. Workshops, contests and events run through the year.','nakshatra@nsut.example',1),
('Team Kalpana',2,'Technical','Technical','Astronomy club','Astronomy club. Workshops, contests and events run through the year.','teamkalpana@nsut.example',1),
('D''Code NSUT',3,'Technical','Technical','D''Code NSUT','D''Code NSUT. Workshops, contests and events run through the year.','dcodensut@nsut.example',0),
('WASD',4,'Technical','Technical','Game development society','Game development society. Workshops, contests and events run through the year.','wasd@nsut.example',1),
('TDR',1,'Technical','Technical','Automotive society','Automotive society. Workshops, contests and events run through the year.','tdr@nsut.example',1),
('Intaglios',2,'Technical','Technical','Designing society','Designing society. Workshops, contests and events run through the year.','intaglios@nsut.example',1),
('COE HHTRF',3,'Technical','Technical','Hydroponics research facility','Hydroponics research facility. Workshops, contests and events run through the year.','coehhtrf@nsut.example',1),
('Venatus',4,'Technical','Technical','Gaming society','Gaming society. Workshops, contests and events run through the year.','venatus@nsut.example',0),
('Capella',1,'Cultural','Cultural','Contemporary dance and choreography society','Contemporary dance and choreography society. Workshops, contests and events run through the year.','capella@nsut.example',1),
('Mirage',2,'Cultural','Cultural','Western dance society','Western dance society. Workshops, contests and events run through the year.','mirage@nsut.example',1),
('Canvas',3,'Cultural','Cultural','Fine arts society','Fine arts society. Workshops, contests and events run through the year.','canvas@nsut.example',1),
('Junoon',4,'Cultural','Cultural','Photography society','Photography society. Workshops, contests and events run through the year.','junoon@nsut.example',1),
('Mudrakala',1,'Cultural','Cultural','Classical dance society','Classical dance society. Workshops, contests and events run through the year.','mudrakala@nsut.example',1),
('Clitch',2,'Cultural','Cultural','Fashion society','Fashion society. Workshops, contests and events run through the year.','clitch@nsut.example',0),
('Shakesjeer',3,'Cultural','Cultural','Open mic and performing society','Open mic and performing society. Workshops, contests and events run through the year.','shakesjeer@nsut.example',1),
('Aagaz',4,'Cultural','Literary and debating','Poetry society','Poetry society. Workshops, contests and events run through the year.','aagaz@nsut.example',1),
('DebSoc',1,'Cultural','Literary and debating','Debating society','Debating society. Workshops, contests and events run through the year.','debsoc@nsut.example',1),
('Alliance',2,'Cultural','Literary and debating','Official newspaper of NSUT','Official newspaper of NSUT. Workshops, contests and events run through the year.','alliance@nsut.example',1),
('Axiom',3,'Cultural','Literary and debating','Philosophy society','Philosophy society. Workshops, contests and events run through the year.','axiom@nsut.example',1),
('Subhasha',4,'Cultural','Literary and debating','Literary chapter of NSUT','Literary chapter of NSUT. Workshops, contests and events run through the year.','subhasha@nsut.example',1),
('Tatsam',1,'Cultural','Literary and debating','Hindi cultural and literary society','Hindi cultural and literary society. Workshops, contests and events run through the year.','tatsam@nsut.example',1),
('Crosslinks',2,'Cultural','Literary and debating','Public relations and community service society','Public relations and community service society. Workshops, contests and events run through the year.','crosslinks@nsut.example',0),
('NSUT Quiz Club',3,'Cultural','Literary and debating','Quiz club','Quiz club. Workshops, contests and events run through the year.','nsutquizclub@nsut.example',1),
('FES',4,'Other','Business and finance','Finance and economics society','Finance and economics society. Workshops, contests and events run through the year.','fes@nsut.example',1),
('FinSoc',1,'Other','Business and finance','Finance society','Finance society. Workshops, contests and events run through the year.','finsoc@nsut.example',1),
('E-Cell',2,'Other','Business and finance','Entrepreneurship cell','Entrepreneurship cell. Workshops, contests and events run through the year.','ecell@nsut.example',1),
('Enactus NSUT',3,'Other','Business and finance','Entrepreneurship society','Entrepreneurship society. Workshops, contests and events run through the year.','enactusnsut@nsut.example',0),
('180 Degrees Consulting',4,'Other','Business and finance','Consulting society','Consulting society. Workshops, contests and events run through the year.','180degreesconsulting@nsut.example',1),
('IIF NSUT',1,'Other','Business and finance','Incubation and innovation foundation','Incubation and innovation foundation. Workshops, contests and events run through the year.','iifnsut@nsut.example',1),
('IGTS',2,'Other','Business and finance','Indian Game Theory Society','Indian Game Theory Society. Workshops, contests and events run through the year.','igts@nsut.example',1),
('Humanica',3,'Other','Business and finance','HR and OB society','HR and OB society. Workshops, contests and events run through the year.','humanica@nsut.example',1),
('Rotaract',4,'Other','Social and sports','Rotaract club of NSUT','Rotaract club of NSUT. Workshops, contests and events run through the year.','rotaract@nsut.example',1),
('NSS NSUT',1,'Other','Social and sports','National Service Scheme','National Service Scheme. Workshops, contests and events run through the year.','nssnsut@nsut.example',0),
('NCC NSUT',2,'Other','Social and sports','National Cadet Corps','National Cadet Corps. Workshops, contests and events run through the year.','nccnsut@nsut.example',0),
('NSUT Sports',3,'Other','Social and sports','Sports council','Sports council. Workshops, contests and events run through the year.','nsutsports@nsut.example',1),
('Prayas',4,'Other','Social and sports','Social welfare society','Social welfare society. Workshops, contests and events run through the year.','prayas@nsut.example',1),
('NALUM',1,'Other','Social and sports','Alumni portal of NSUT','Alumni portal of NSUT. Workshops, contests and events run through the year.','nalum@nsut.example',0),
('Shatranj',2,'Other','Social and sports','Chess club','Chess club. Workshops, contests and events run through the year.','shatranj@nsut.example',1);

-- DEMO: forms closed for some societies (the 4 renamed ones stay open)
-- (already set above through registration_open)

-- ---------------------------------------------------------------------
-- 3. More venues
-- ---------------------------------------------------------------------
INSERT INTO Venue (venue_name, building, capacity) VALUES
('SAC Room 102',    'SAC Building', 100),
('Central Lawn',    'Central Lawn', 150),
('Robotics Lab',    'Block E',       60),
('Seminar Hall',    'Block B',      120),
('SAC Gaming Room', 'SAC Building',  40),
('Online',          'Online',     10000);

-- ---------------------------------------------------------------------
-- 4. Featured events (the 7 slides). Events 1, 2 and 3 already exist in seed.sql.
-- ---------------------------------------------------------------------
UPDATE Event SET category='Hackathon', is_featured=1, featured_order=1, vip_seats=5,
  image_url='/images/events/featured-1.jpg', accent_color='#C8102E', bg_color='#1A0A0E',
  registration_deadline='2026-12-04 23:59:00',
  description='A 24-hour university-wide hackathon. Teams of up to 4 build a working project and present it to a panel of judges.'
 WHERE event_id=1;
UPDATE Event SET event_type='Cultural', is_featured=1, featured_order=2,
  image_url='/images/events/featured-2.jpg', accent_color='#E8B04A', bg_color='#1A1008',
  description='Sing, play, recite or perform stand-up. Three minutes on stage, open to every branch.'
 WHERE event_id=2;
UPDATE Event SET event_type='Technical contests', is_featured=1, featured_order=3,
  image_url='/images/events/featured-3.jpg', accent_color='#22C3EE', bg_color='#061418',
  description='A quiz round on robotics, sensors and control. Teams of 3.'
 WHERE event_id=3;

INSERT INTO Event (title, club_id, venue_id, event_date, fee, prize_amount, event_type, is_featured, featured_order, image_url, accent_color, bg_color, description) VALUES
('Nukkad Natak Showcase',(SELECT club_id FROM Club WHERE club_name='Ashwamedh'),(SELECT venue_id FROM Venue WHERE venue_name='Main Auditorium' AND building='Admin Block'),'2026-12-03 18:00:00',0,0,'Cultural',1,4,'/images/events/featured-4.jpg','#C8102E','#1D0A10','Street plays by NSUT societies, followed by a short talk from the chief judge.'),
('Photo Walk and Contest',(SELECT club_id FROM Club WHERE club_name='Junoon'),(SELECT venue_id FROM Venue WHERE venue_name='Central Lawn' AND building='Central Lawn'),'2026-12-04 08:00:00',0,0,'Cultural',1,5,'/images/events/featured-5.jpg','#E8B04A','#0F0F10','A morning walk across campus with a photo contest. Bring a camera or a phone.'),
('Quizzaholic',(SELECT club_id FROM Club WHERE club_name='NSUT Quiz Club'),(SELECT venue_id FROM Venue WHERE venue_name='SAC Room 102' AND building='SAC Building'),'2026-12-05 15:00:00',30,0,'Quiz and trivia',1,6,'/images/events/featured-6.jpg','#3DDBB0','#08150F','General quiz in teams of 2. Five rounds, one trophy.'),
('Taal: Inter-college Dance Battle',(SELECT club_id FROM Club WHERE club_name='Capella'),(SELECT venue_id FROM Venue WHERE venue_name='Open Amphitheatre' AND building='Central Lawn'),'2026-12-06 18:30:00',300,20000,'Cultural',1,7,'/images/events/featured-7.jpg','#FF6B5A','#1A0C0A','Dance crews from colleges across Delhi compete on one stage.');

-- ---------------------------------------------------------------------
-- 5. Spill the tea: 3 events that start within 24 hours of the moment you run this
--    (DEMO. Re-run this block any time to refresh them.)
-- ---------------------------------------------------------------------
INSERT INTO Event (title, club_id, venue_id, event_date, fee, event_type) VALUES
('RoboWars Inspection',(SELECT club_id FROM Club WHERE club_name='ARES Robotics'),(SELECT venue_id FROM Venue WHERE venue_name='Robotics Lab' AND building='Block E'),DATE_ADD(NOW(), INTERVAL 3 HOUR),50,'Technical contests'),
('Debate Pre-Round',(SELECT club_id FROM Club WHERE club_name='DebSoc'),(SELECT venue_id FROM Venue WHERE venue_name='SAC Room 102' AND building='SAC Building'),DATE_ADD(NOW(), INTERVAL 7 HOUR),0,'Literary and debating'),
('Kavita Open Mic',(SELECT club_id FROM Club WHERE club_name='Aagaz'),(SELECT venue_id FROM Venue WHERE venue_name='Open Amphitheatre' AND building='Central Lawn'),DATE_ADD(NOW(), INTERVAL 12 HOUR),0,'Literary and debating');

-- ---------------------------------------------------------------------
-- 6. Competitions for the events page (DEMO sample events, brand names are sample data)
-- ---------------------------------------------------------------------
INSERT INTO Event (title, club_id, venue_id, event_date, fee, prize_amount, event_type, run_by, organiser_label, event_mode, description) VALUES
('BGMI Campus Showdown',(SELECT club_id FROM Club WHERE club_name='Venatus'),(SELECT venue_id FROM Venue WHERE venue_name='Open Amphitheatre' AND building='Central Lawn'),'2026-11-29 18:00:00',200,25000,'Gaming and esports','NSUT society',NULL,'On campus','Squad tournament on campus. Teams of 4.'),
('FIFA Knockout Cup',(SELECT club_id FROM Club WHERE club_name='NSUT Sports'),(SELECT venue_id FROM Venue WHERE venue_name='SAC Gaming Room' AND building='SAC Building'),'2026-11-30 14:00:00',100,10000,'Gaming and esports','NSUT society',NULL,'On campus','Single-elimination console tournament.'),
('Red Bull Campus Clutch',(SELECT club_id FROM Club WHERE club_name='Venatus'),(SELECT venue_id FROM Venue WHERE venue_name='Online' AND building='Online'),'2026-12-03 16:00:00',0,50000,'Gaming and esports','Outside brand','Red Bull','Online','Brand-run gaming contest, open to all colleges.'),
('Valorant Inter-Branch League',(SELECT club_id FROM Club WHERE club_name='Venatus'),(SELECT venue_id FROM Venue WHERE venue_name='SAC Gaming Room' AND building='SAC Building'),'2026-12-05 17:00:00',150,0,'Gaming and esports','NSUT society',NULL,'On campus','Branch against branch, 5 players a team.'),
('Case Cracker',(SELECT club_id FROM Club WHERE club_name='E-Cell'),(SELECT venue_id FROM Venue WHERE venue_name='Seminar Hall' AND building='Block B'),'2026-12-07 10:00:00',100,15000,'Business and case contests','NSUT society',NULL,'On campus','A live business case. Teams of 3 present to a panel.');

-- ---------------------------------------------------------------------
-- 7. Faculty in societies, VIP pass requests (DEMO)
-- ---------------------------------------------------------------------
INSERT INTO Faculty_Membership (faculty_id, club_id, `role`) VALUES
(1, 1, 'Member'),
(3, 2, 'Member');

INSERT INTO VIP_Pass (faculty_id, event_id, status) VALUES
(1, 1, 'Pending'),
(2, 1, 'Pending');

-- ---------------------------------------------------------------------
-- 8. Demo accounts. Password for all of them: Demo@123
--    1 Aarav Mehta     student, President of DevComm  (2025UCS1001)
--    2 Diya Singh      student, plain member          (2025UCS1002)
--    3 Dr. Anita Sharma faculty (approved)
--    4 Tanvi Bhatia    external participant
--    5 Admin
-- ---------------------------------------------------------------------
INSERT INTO Account (email, password_hash, `role`, student_id, faculty_id) VALUES
('aarav.m@college.example',      '$2b$10$YNDVnfeXW9mR4vwCY2YtPOC5KYMgqpe.XkVDOfSaqbU1olMh2jyW.', 'student',  1,    NULL),
('diya.s@college.example',       '$2b$10$YNDVnfeXW9mR4vwCY2YtPOC5KYMgqpe.XkVDOfSaqbU1olMh2jyW.', 'student',  2,    NULL),
('anita.sharma@college.example', '$2b$10$YNDVnfeXW9mR4vwCY2YtPOC5KYMgqpe.XkVDOfSaqbU1olMh2jyW.', 'faculty',  NULL, 1),
('tanvi.b@other.example',        '$2b$10$YNDVnfeXW9mR4vwCY2YtPOC5KYMgqpe.XkVDOfSaqbU1olMh2jyW.', 'external', 13,   NULL),
('admin@nsut.example',           '$2b$10$YNDVnfeXW9mR4vwCY2YtPOC5KYMgqpe.XkVDOfSaqbU1olMh2jyW.', 'admin',    NULL, NULL);
-- faculty start unapproved (trigger); approve the demo faculty
UPDATE Account SET is_approved = 1 WHERE email = 'anita.sharma@college.example';

