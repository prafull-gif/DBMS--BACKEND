-- =====================================================================
-- Society & Event Management System  |  MySQL 8.0
-- Run order: schema.sql -> seed.sql -> roles.sql
-- =====================================================================
DROP DATABASE IF EXISTS society_events;
CREATE DATABASE society_events CHARACTER SET utf8mb4;
USE society_events;

-- ---------------------------------------------------------------------
-- 1. Student  (external participants live here too: is_external = 1)
-- ---------------------------------------------------------------------
CREATE TABLE Student (
  student_id   INT AUTO_INCREMENT PRIMARY KEY,
  roll_no      VARCHAR(20)  UNIQUE,
  name         VARCHAR(100) NOT NULL,
  branch       VARCHAR(50),
  `year`       TINYINT,
  email        VARCHAR(120) NOT NULL UNIQUE,
  is_external  TINYINT(1)   NOT NULL DEFAULT 0,
  college_name VARCHAR(120),
  CONSTRAINT chk_student_year CHECK (`year` IS NULL OR `year` BETWEEN 1 AND 5),
  CONSTRAINT chk_student_kind CHECK (
       (is_external = 0 AND roll_no IS NOT NULL AND college_name IS NULL)
    OR (is_external = 1 AND roll_no IS NULL     AND college_name IS NOT NULL))
);

-- ---------------------------------------------------------------------
-- 2. Faculty
-- ---------------------------------------------------------------------
CREATE TABLE Faculty (
  faculty_id  INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  department  VARCHAR(80),
  email       VARCHAR(120) NOT NULL UNIQUE,
  phone       VARCHAR(15),
  designation VARCHAR(50)
);

-- ---------------------------------------------------------------------
-- 3. Club  (total participation in 'supervises': faculty_id NOT NULL)
-- ---------------------------------------------------------------------
CREATE TABLE Club (
  club_id    INT AUTO_INCREMENT PRIMARY KEY,
  club_name  VARCHAR(100) NOT NULL UNIQUE,
  faculty_id INT NOT NULL,
  category   VARCHAR(50),
  created_on DATE NOT NULL DEFAULT (CURRENT_DATE),
  CONSTRAINT fk_club_faculty FOREIGN KEY (faculty_id)
    REFERENCES Faculty(faculty_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 4. Membership  (junction: Student M:N Club)
-- ---------------------------------------------------------------------
CREATE TABLE Membership (
  student_id INT NOT NULL,
  club_id    INT NOT NULL,
  `role`     VARCHAR(40) NOT NULL DEFAULT 'Member',
  join_date  DATE NOT NULL DEFAULT (CURRENT_DATE),
  PRIMARY KEY (student_id, club_id),
  CONSTRAINT fk_mem_student FOREIGN KEY (student_id)
    REFERENCES Student(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_mem_club FOREIGN KEY (club_id)
    REFERENCES Club(club_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 5. Venue
-- ---------------------------------------------------------------------
CREATE TABLE Venue (
  venue_id   INT AUTO_INCREMENT PRIMARY KEY,
  venue_name VARCHAR(100) NOT NULL,
  building   VARCHAR(60),
  capacity   INT NOT NULL,
  CONSTRAINT chk_venue_capacity CHECK (capacity > 0),
  CONSTRAINT uq_venue UNIQUE (venue_name, building)
);

-- ---------------------------------------------------------------------
-- 6. Event
-- ---------------------------------------------------------------------
CREATE TABLE Event (
  event_id   INT AUTO_INCREMENT PRIMARY KEY,
  title      VARCHAR(150) NOT NULL,
  club_id    INT NOT NULL,
  venue_id   INT NOT NULL,
  event_date DATETIME NOT NULL,
  fee        DECIMAL(8,2) NOT NULL DEFAULT 0,
  status     VARCHAR(15)  NOT NULL DEFAULT 'Upcoming',
  CONSTRAINT chk_event_fee    CHECK (fee >= 0),
  CONSTRAINT chk_event_status CHECK (status IN ('Upcoming','Ongoing','Completed','Cancelled')),
  CONSTRAINT fk_event_club  FOREIGN KEY (club_id)  REFERENCES Club(club_id)   ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_event_venue FOREIGN KEY (venue_id) REFERENCES Venue(venue_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_event_date (event_date)
);

-- ---------------------------------------------------------------------
-- 7. Organizer  (junction: Student M:N Event)
-- ---------------------------------------------------------------------
CREATE TABLE Organizer (
  event_id   INT NOT NULL,
  student_id INT NOT NULL,
  duty       VARCHAR(60),
  PRIMARY KEY (event_id, student_id),
  CONSTRAINT fk_org_event   FOREIGN KEY (event_id)   REFERENCES Event(event_id)     ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_org_student FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 8. Registration
-- ---------------------------------------------------------------------
CREATE TABLE Registration (
  reg_id     INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT NOT NULL,
  event_id   INT NOT NULL,
  reg_date   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status     VARCHAR(15) NOT NULL DEFAULT 'Pending',
  CONSTRAINT chk_reg_status CHECK (status IN ('Pending','Paid','Confirmed','Cancelled')),
  CONSTRAINT uq_reg_student_event UNIQUE (student_id, event_id),
  CONSTRAINT fk_reg_student FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_reg_event   FOREIGN KEY (event_id)   REFERENCES Event(event_id)     ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 9. Payment  (1:1 with Registration via UNIQUE reg_id)
-- ---------------------------------------------------------------------
CREATE TABLE Payment (
  payment_id   INT AUTO_INCREMENT PRIMARY KEY,
  reg_id       INT NOT NULL UNIQUE,
  amount       DECIMAL(8,2) NOT NULL,
  `mode`       VARCHAR(20)  NOT NULL,
  payment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_pay_amount CHECK (amount > 0),
  CONSTRAINT chk_pay_mode   CHECK (`mode` IN ('UPI','Cash','Card','NetBanking')),
  CONSTRAINT fk_pay_reg FOREIGN KEY (reg_id) REFERENCES Registration(reg_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 10. Guest
-- ---------------------------------------------------------------------
CREATE TABLE Guest (
  guest_id     INT AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(100) NOT NULL,
  `type`       VARCHAR(10)  NOT NULL,
  organization VARCHAR(120),
  contact      VARCHAR(120),
  bio          TEXT,
  CONSTRAINT chk_guest_type CHECK (`type` IN ('Artist','Guest','Judge','Speaker'))
);

-- ---------------------------------------------------------------------
-- 11. Event_Guest  (junction: Event M:N Guest)
-- ---------------------------------------------------------------------
CREATE TABLE Event_Guest (
  event_id   INT NOT NULL,
  guest_id   INT NOT NULL,
  `role`     VARCHAR(60),
  honorarium DECIMAL(10,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (event_id, guest_id),
  CONSTRAINT chk_eg_honorarium CHECK (honorarium >= 0),
  CONSTRAINT fk_eg_event FOREIGN KEY (event_id) REFERENCES Event(event_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_eg_guest FOREIGN KEY (guest_id) REFERENCES Guest(guest_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 12. Sponsor
-- ---------------------------------------------------------------------
CREATE TABLE Sponsor (
  sponsor_id     INT AUTO_INCREMENT PRIMARY KEY,
  company_name   VARCHAR(120) NOT NULL,
  industry       VARCHAR(60),
  contact_person VARCHAR(100),
  phone          VARCHAR(15),
  email          VARCHAR(120)
);

-- ---------------------------------------------------------------------
-- 13. Event_Sponsor  (junction: Event M:N Sponsor)
-- ---------------------------------------------------------------------
CREATE TABLE Event_Sponsor (
  event_id   INT NOT NULL,
  sponsor_id INT NOT NULL,
  amount     DECIMAL(10,2) NOT NULL,
  tier       VARCHAR(10),
  PRIMARY KEY (event_id, sponsor_id),
  CONSTRAINT chk_es_amount CHECK (amount >= 0),
  CONSTRAINT chk_es_tier   CHECK (tier IS NULL OR tier IN ('Title','Gold','Silver','Bronze')),
  CONSTRAINT fk_es_event   FOREIGN KEY (event_id)   REFERENCES Event(event_id)     ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_es_sponsor FOREIGN KEY (sponsor_id) REFERENCES Sponsor(sponsor_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 14. Expense
-- ---------------------------------------------------------------------
CREATE TABLE Expense (
  expense_id   INT AUTO_INCREMENT PRIMARY KEY,
  event_id     INT NOT NULL,
  category     VARCHAR(50) NOT NULL,
  amount       DECIMAL(10,2) NOT NULL,
  expense_date DATE NOT NULL DEFAULT (CURRENT_DATE),
  note         VARCHAR(255),
  CONSTRAINT chk_exp_amount CHECK (amount > 0),
  CONSTRAINT fk_exp_event FOREIGN KEY (event_id) REFERENCES Event(event_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 15. Feedback
-- ---------------------------------------------------------------------
CREATE TABLE Feedback (
  feedback_id INT AUTO_INCREMENT PRIMARY KEY,
  event_id    INT NOT NULL,
  student_id  INT NOT NULL,
  rating      TINYINT NOT NULL,
  comments    VARCHAR(500),
  CONSTRAINT chk_fb_rating CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT uq_fb_student_event UNIQUE (student_id, event_id),
  CONSTRAINT fk_fb_event   FOREIGN KEY (event_id)   REFERENCES Event(event_id)     ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fb_student FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 16. Result
-- ---------------------------------------------------------------------
CREATE TABLE Result (
  result_id  INT AUTO_INCREMENT PRIMARY KEY,
  event_id   INT NOT NULL,
  reg_id     INT NOT NULL,
  `position` INT NOT NULL,
  prize      VARCHAR(100),
  CONSTRAINT chk_res_position CHECK (`position` > 0),
  CONSTRAINT uq_res_event_reg UNIQUE (event_id, reg_id),
  CONSTRAINT fk_res_event FOREIGN KEY (event_id) REFERENCES Event(event_id)        ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT fk_res_reg   FOREIGN KEY (reg_id)   REFERENCES Registration(reg_id)   ON DELETE RESTRICT ON UPDATE CASCADE
);

-- =====================================================================
-- TRIGGERS
-- =====================================================================
DELIMITER $$

-- Blocks a registration if the venue is full; free events are auto-confirmed
CREATE TRIGGER trg_check_capacity BEFORE INSERT ON Registration
FOR EACH ROW
BEGIN
  DECLARE cap INT;
  DECLARE cnt INT;
  DECLARE ev_fee DECIMAL(8,2);

  SELECT v.capacity, e.fee INTO cap, ev_fee
    FROM Event e JOIN Venue v ON e.venue_id = v.venue_id
   WHERE e.event_id = NEW.event_id;

  SELECT COUNT(*) INTO cnt
    FROM Registration
   WHERE event_id = NEW.event_id AND status <> 'Cancelled';

  IF cnt >= cap THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Venue capacity full';
  END IF;

  IF ev_fee = 0 THEN
    SET NEW.status = 'Confirmed';
  END IF;
END$$

-- A payment must match the event fee
CREATE TRIGGER trg_payment_amount BEFORE INSERT ON Payment
FOR EACH ROW
BEGIN
  DECLARE ev_fee DECIMAL(8,2);
  SELECT e.fee INTO ev_fee
    FROM Registration r JOIN Event e ON r.event_id = e.event_id
   WHERE r.reg_id = NEW.reg_id;
  IF NEW.amount <> ev_fee THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount does not match event fee';
  END IF;
END$$

-- After a payment, mark the registration as Paid
CREATE TRIGGER trg_payment_done AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
  UPDATE Registration SET status = 'Paid' WHERE reg_id = NEW.reg_id;
END$$

-- Only registered students can leave feedback
CREATE TRIGGER trg_feedback_registered BEFORE INSERT ON Feedback
FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM Registration
                  WHERE student_id = NEW.student_id
                    AND event_id   = NEW.event_id
                    AND status <> 'Cancelled') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only registered students can give feedback';
  END IF;
END$$

-- Result.event_id must match the event of the linked registration
CREATE TRIGGER trg_result_consistent BEFORE INSERT ON Result
FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM Registration
                  WHERE reg_id = NEW.reg_id AND event_id = NEW.event_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Result registration does not belong to this event';
  END IF;
END$$

-- =====================================================================
-- STORED PROCEDURE + TRANSACTION (TCL)
-- Register (and pay, if the event has a fee) as one atomic unit.
-- FOR UPDATE on the Event row serialises concurrent sign-ups, so two
-- students cannot both grab the last seat.
-- =====================================================================
CREATE PROCEDURE sp_register_and_pay(
  IN  p_student INT,
  IN  p_event   INT,
  IN  p_mode    VARCHAR(20),
  OUT p_reg_id  INT)
BEGIN
  DECLARE v_fee DECIMAL(8,2);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
    SELECT fee INTO v_fee FROM Event WHERE event_id = p_event FOR UPDATE;
    INSERT INTO Registration (student_id, event_id) VALUES (p_student, p_event);
    SET p_reg_id = LAST_INSERT_ID();
    IF v_fee > 0 THEN
      INSERT INTO Payment (reg_id, amount, `mode`) VALUES (p_reg_id, v_fee, p_mode);
    END IF;
  COMMIT;
END$$

DELIMITER ;

-- =====================================================================
-- VIEWS
-- =====================================================================
CREATE VIEW v_unpaid_registrations AS
SELECT r.reg_id, s.name, e.title, e.fee
  FROM Registration r
  JOIN Student s ON r.student_id = s.student_id
  JOIN Event   e ON r.event_id   = e.event_id
  LEFT JOIN Payment p ON p.reg_id = r.reg_id
 WHERE p.payment_id IS NULL AND e.fee > 0 AND r.status = 'Pending';

CREATE VIEW v_upcoming_events AS
SELECT e.event_id, e.title, c.club_name, v.venue_name, v.building,
       e.event_date, e.fee, v.capacity,
       v.capacity - (SELECT COUNT(*) FROM Registration r
                      WHERE r.event_id = e.event_id AND r.status <> 'Cancelled') AS seats_left
  FROM Event e
  JOIN Club  c ON e.club_id  = c.club_id
  JOIN Venue v ON e.venue_id = v.venue_id
 WHERE e.status = 'Upcoming';

CREATE VIEW v_club_summary AS
SELECT c.club_id, c.club_name, f.name AS faculty_head, COUNT(m.student_id) AS members
  FROM Club c
  JOIN Faculty f ON c.faculty_id = f.faculty_id
  LEFT JOIN Membership m ON m.club_id = c.club_id
 GROUP BY c.club_id, c.club_name, f.name;

CREATE VIEW v_event_finance AS
SELECT e.event_id, e.title,
  COALESCE((SELECT SUM(p.amount) FROM Payment p JOIN Registration r ON p.reg_id = r.reg_id
             WHERE r.event_id = e.event_id), 0)                              AS fees_collected,
  COALESCE((SELECT SUM(amount)     FROM Event_Sponsor WHERE event_id = e.event_id), 0) AS sponsorship,
  COALESCE((SELECT SUM(amount)     FROM Expense       WHERE event_id = e.event_id), 0) AS expenses,
  COALESCE((SELECT SUM(honorarium) FROM Event_Guest   WHERE event_id = e.event_id), 0) AS honorariums
  FROM Event e;

-- Club heads can add/edit only events that stay Upcoming/Ongoing
CREATE VIEW v_open_events AS
SELECT event_id, title, club_id, venue_id, event_date, fee, status
  FROM Event
 WHERE status IN ('Upcoming','Ongoing')
WITH CHECK OPTION;
