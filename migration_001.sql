-- =====================================================================
-- migration_001.sql  |  MySQL 8.0
-- Run order: schema.sql -> seed.sql -> roles.sql -> migration_001.sql -> seed_002.sql
-- Adds: login accounts, faculty in societies, VIP passes, role-change log,
-- saved events, new columns for Club and Event, new rules and views.
-- =====================================================================
USE society_events;

-- ---------------------------------------------------------------------
-- 1. New columns on Club
-- ---------------------------------------------------------------------
ALTER TABLE Club
  ADD COLUMN sub_category      VARCHAR(40)  NULL AFTER category,
  ADD COLUMN tagline           VARCHAR(150) NULL,
  ADD COLUMN about             TEXT         NULL,
  ADD COLUMN banner_url        VARCHAR(255) NULL,
  ADD COLUMN logo_url          VARCHAR(255) NULL,
  ADD COLUMN registration_open TINYINT(1)   NOT NULL DEFAULT 1,
  ADD COLUMN contact_email     VARCHAR(120) NULL,
  ADD CONSTRAINT chk_club_category CHECK (category IN ('Technical','Cultural','Other')),
  ADD CONSTRAINT chk_club_sub CHECK (sub_category IS NULL OR sub_category IN
    ('Technical','Cultural','Literary and debating','Business and finance','Social and sports'));

-- ---------------------------------------------------------------------
-- 2. New columns on Event
--    category      : College Event or Hackathon (landing page tabs)
--    event_type    : subject shown on the events page filters
--    run_by        : NSUT society or Outside brand
--    organiser_label: name to show when it is not a society (e.g. a brand)
-- ---------------------------------------------------------------------
ALTER TABLE Event
  ADD COLUMN category              VARCHAR(20)  NOT NULL DEFAULT 'College Event',
  ADD COLUMN event_type            VARCHAR(40)  NULL,
  ADD COLUMN run_by                VARCHAR(20)  NOT NULL DEFAULT 'NSUT society',
  ADD COLUMN organiser_label       VARCHAR(120) NULL,
  ADD COLUMN event_mode            VARCHAR(12)  NOT NULL DEFAULT 'On campus',
  ADD COLUMN description           TEXT         NULL,
  ADD COLUMN image_url             VARCHAR(255) NULL,
  ADD COLUMN registration_deadline DATETIME     NULL,
  ADD COLUMN vip_seats             INT          NOT NULL DEFAULT 0,
  ADD COLUMN prize_amount          DECIMAL(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN accent_color          CHAR(7)      NULL,
  ADD COLUMN bg_color              CHAR(7)      NULL,
  ADD COLUMN is_featured           TINYINT(1)   NOT NULL DEFAULT 0,
  ADD COLUMN featured_order        TINYINT      NULL,
  ADD CONSTRAINT chk_event_category CHECK (category IN ('College Event','Hackathon')),
  ADD CONSTRAINT chk_event_run_by   CHECK (run_by IN ('NSUT society','Outside brand')),
  ADD CONSTRAINT chk_event_mode     CHECK (event_mode IN ('On campus','Online')),
  ADD CONSTRAINT chk_event_vip      CHECK (vip_seats >= 0),
  ADD CONSTRAINT chk_event_prize    CHECK (prize_amount >= 0),
  ADD CONSTRAINT chk_event_event_type CHECK (event_type IS NULL OR event_type IN
    ('Gaming and esports','Quiz and trivia','Cultural','Literary and debating',
     'Business and case contests','Technical contests','Sports','Workshops and talks'));

-- ---------------------------------------------------------------------
-- 3. Account  (login). Passwords are stored as bcrypt hashes only.
--    student / external -> linked to a Student row
--    faculty            -> linked to a Faculty row, needs admin approval
--    admin              -> linked to nothing
-- ---------------------------------------------------------------------
CREATE TABLE Account (
  account_id    INT AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(120) NOT NULL UNIQUE,
  password_hash VARCHAR(100) NOT NULL,
  `role`        VARCHAR(10)  NOT NULL,
  student_id    INT NULL UNIQUE,
  faculty_id    INT NULL UNIQUE,
  is_approved   TINYINT(1) NOT NULL DEFAULT 1,
  created_on    DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_acc_role CHECK (`role` IN ('student','external','faculty','admin')),
  CONSTRAINT chk_acc_link CHECK (
       (`role` IN ('student','external') AND student_id IS NOT NULL AND faculty_id IS NULL)
    OR (`role` = 'faculty'               AND faculty_id IS NOT NULL AND student_id IS NULL)
    OR (`role` = 'admin'                 AND student_id IS NULL     AND faculty_id IS NULL)),
  CONSTRAINT fk_acc_student FOREIGN KEY (student_id) REFERENCES Student(student_id),
  CONSTRAINT fk_acc_faculty FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id)
);

-- ---------------------------------------------------------------------
-- 4. Faculty_Membership  (junction: Faculty M:N Club)
-- ---------------------------------------------------------------------
CREATE TABLE Faculty_Membership (
  faculty_id INT NOT NULL,
  club_id    INT NOT NULL,
  `role`     VARCHAR(40) NOT NULL DEFAULT 'Member',
  join_date  DATE NOT NULL DEFAULT (CURRENT_DATE),
  PRIMARY KEY (faculty_id, club_id),
  CONSTRAINT fk_fm_faculty FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fm_club    FOREIGN KEY (club_id)    REFERENCES Club(club_id)       ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 5. VIP_Pass  (faculty ask for a VIP seat; society President decides)
--    One request per faculty per event.
-- ---------------------------------------------------------------------
CREATE TABLE VIP_Pass (
  pass_id      INT AUTO_INCREMENT PRIMARY KEY,
  faculty_id   INT NOT NULL,
  event_id     INT NOT NULL,
  status       VARCHAR(10) NOT NULL DEFAULT 'Pending',
  requested_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  decided_by   INT NULL,
  decided_on   DATETIME NULL,
  CONSTRAINT chk_vip_status CHECK (status IN ('Pending','Approved','Rejected')),
  CONSTRAINT uq_vip_faculty_event UNIQUE (faculty_id, event_id),
  CONSTRAINT fk_vip_faculty FOREIGN KEY (faculty_id) REFERENCES Faculty(faculty_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_vip_event   FOREIGN KEY (event_id)   REFERENCES Event(event_id)     ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_vip_decider FOREIGN KEY (decided_by) REFERENCES Student(student_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 6. Role_Change_Log  (audit of every role change in a society)
-- ---------------------------------------------------------------------
CREATE TABLE Role_Change_Log (
  log_id     INT AUTO_INCREMENT PRIMARY KEY,
  club_id    INT NOT NULL,
  student_id INT NOT NULL,
  old_role   VARCHAR(40),
  new_role   VARCHAR(40) NOT NULL,
  changed_by INT NOT NULL,
  changed_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_rcl_club    FOREIGN KEY (club_id)    REFERENCES Club(club_id)       ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_rcl_student FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_rcl_by      FOREIGN KEY (changed_by) REFERENCES Student(student_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 7. Saved_Event  (bookmark + reminder setting; junction: Account M:N Event)
-- ---------------------------------------------------------------------
CREATE TABLE Saved_Event (
  account_id    INT NOT NULL,
  event_id      INT NOT NULL,
  remind_before VARCHAR(10) NOT NULL DEFAULT '1 day',
  saved_on      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (account_id, event_id),
  CONSTRAINT chk_saved_remind CHECK (remind_before IN ('1 day','1 hour','none')),
  CONSTRAINT fk_saved_account FOREIGN KEY (account_id) REFERENCES Account(account_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_saved_event   FOREIGN KEY (event_id)   REFERENCES Event(event_id)     ON DELETE CASCADE ON UPDATE CASCADE
);

-- =====================================================================
-- TRIGGERS
-- =====================================================================
DELIMITER $$

-- Faculty accounts always start unapproved; an admin approves them later
CREATE TRIGGER trg_account_faculty_pending BEFORE INSERT ON Account
FOR EACH ROW
BEGIN
  IF NEW.`role` = 'faculty' THEN
    SET NEW.is_approved = 0;
  END IF;
END$$

-- No new students while the society's forms are closed
CREATE TRIGGER trg_membership_forms_open BEFORE INSERT ON Membership
FOR EACH ROW
BEGIN
  DECLARE v_open TINYINT;
  SELECT registration_open INTO v_open FROM Club WHERE club_id = NEW.club_id;
  IF v_open = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Forms are closed for this society';
  END IF;
END$$

-- Same rule for faculty joining a society
CREATE TRIGGER trg_fmembership_forms_open BEFORE INSERT ON Faculty_Membership
FOR EACH ROW
BEGIN
  DECLARE v_open TINYINT;
  SELECT registration_open INTO v_open FROM Club WHERE club_id = NEW.club_id;
  IF v_open = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Forms are closed for this society';
  END IF;
END$$

-- A VIP request needs an event that has VIP seats
CREATE TRIGGER trg_vip_request BEFORE INSERT ON VIP_Pass
FOR EACH ROW
BEGIN
  DECLARE v_seats INT;
  DECLARE v_taken INT;
  SELECT vip_seats INTO v_seats FROM Event WHERE event_id = NEW.event_id;
  IF v_seats IS NULL OR v_seats = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This event has no VIP seats';
  END IF;
  IF NEW.status = 'Approved' THEN
    SELECT COUNT(*) INTO v_taken FROM VIP_Pass
     WHERE event_id = NEW.event_id AND status = 'Approved';
    IF v_taken >= v_seats THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No VIP seats left for this event';
    END IF;
  END IF;
END$$

-- Approved passes can never be more than the event's VIP seats
CREATE TRIGGER trg_vip_approve BEFORE UPDATE ON VIP_Pass
FOR EACH ROW
BEGIN
  DECLARE v_seats INT;
  DECLARE v_taken INT;
  IF NEW.status = 'Approved' AND OLD.status <> 'Approved' THEN
    SELECT vip_seats INTO v_seats FROM Event WHERE event_id = NEW.event_id;
    SELECT COUNT(*) INTO v_taken FROM VIP_Pass
     WHERE event_id = NEW.event_id AND status = 'Approved';
    IF v_taken >= v_seats THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No VIP seats left for this event';
    END IF;
  END IF;
END$$

-- =====================================================================
-- STORED PROCEDURE + TRANSACTION
-- Only the society President can change a member's role.
-- A society must always keep at least one President.
-- Every change is written to Role_Change_Log.
-- =====================================================================
CREATE PROCEDURE sp_update_member_role(
  IN p_actor    INT,
  IN p_club     INT,
  IN p_student  INT,
  IN p_new_role VARCHAR(40))
BEGIN
  DECLARE v_actor_role VARCHAR(40);
  DECLARE v_old_role   VARCHAR(40);
  DECLARE v_presidents INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
    SELECT `role` INTO v_actor_role FROM Membership
     WHERE student_id = p_actor AND club_id = p_club FOR UPDATE;
    IF v_actor_role IS NULL OR v_actor_role <> 'President' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only the society head can manage this society';
    END IF;

    IF p_new_role IS NULL OR TRIM(p_new_role) = '' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Role cannot be empty';
    END IF;

    SELECT `role` INTO v_old_role FROM Membership
     WHERE student_id = p_student AND club_id = p_club FOR UPDATE;
    IF v_old_role IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'That student is not a member of this society';
    END IF;

    IF v_old_role = 'President' AND p_new_role <> 'President' THEN
      SELECT COUNT(*) INTO v_presidents FROM Membership
       WHERE club_id = p_club AND `role` = 'President';
      IF v_presidents <= 1 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'A society needs at least one President. Promote someone else first.';
      END IF;
    END IF;

    UPDATE Membership SET `role` = TRIM(p_new_role)
     WHERE student_id = p_student AND club_id = p_club;
    INSERT INTO Role_Change_Log (club_id, student_id, old_role, new_role, changed_by)
    VALUES (p_club, p_student, v_old_role, TRIM(p_new_role), p_actor);
  COMMIT;
END$$

DELIMITER ;

-- =====================================================================
-- VIEWS
-- =====================================================================

-- Events starting in the next 24 hours (Spill the tea)
CREATE VIEW v_spill_the_tea AS
SELECT e.event_id, e.title, e.category, c.club_name, v.venue_name, v.building,
       v.capacity AS venue_capacity, e.event_date, e.fee, e.image_url,
       e.accent_color, e.bg_color,
       TIMESTAMPDIFF(MINUTE, NOW(), e.event_date) AS minutes_to_start,
       v.capacity - (SELECT COUNT(*) FROM Registration r
                      WHERE r.event_id = e.event_id AND r.status <> 'Cancelled') AS seats_left
  FROM Event e
  JOIN Club  c ON e.club_id  = c.club_id
  JOIN Venue v ON e.venue_id = v.venue_id
 WHERE e.status = 'Upcoming'
   AND e.event_date >= NOW()
   AND e.event_date <  NOW() + INTERVAL 24 HOUR
 ORDER BY e.event_date;

-- The 7 slides of the landing page carousel
CREATE VIEW v_featured_events AS
SELECT e.event_id, e.title, e.category, c.club_name, v.venue_name, v.building,
       v.capacity AS venue_capacity, e.event_date, e.fee, e.image_url,
       e.accent_color, e.bg_color, e.featured_order,
       (SELECT COUNT(*) FROM Registration r
         WHERE r.event_id = e.event_id AND r.status <> 'Cancelled') AS registered,
       v.capacity - (SELECT COUNT(*) FROM Registration r
                      WHERE r.event_id = e.event_id AND r.status <> 'Cancelled') AS seats_left
  FROM Event e
  JOIN Club  c ON e.club_id  = c.club_id
  JOIN Venue v ON e.venue_id = v.venue_id
 WHERE e.is_featured = 1 AND e.status = 'Upcoming'
 ORDER BY e.featured_order;

-- One row per society for the societies list and landing page cards
CREATE VIEW v_society_cards AS
SELECT c.club_id, c.club_name, c.tagline, c.category, c.sub_category,
       c.registration_open, c.about, c.logo_url, c.banner_url, c.contact_email,
       f.name AS faculty_in_charge,
       (SELECT COUNT(*) FROM Membership m WHERE m.club_id = c.club_id) AS members,
       (SELECT s.name FROM Membership m JOIN Student s ON s.student_id = m.student_id
         WHERE m.club_id = c.club_id AND m.`role` = 'President'
         ORDER BY m.join_date LIMIT 1) AS president,
       (SELECT e.title FROM Event e WHERE e.club_id = c.club_id AND e.status = 'Upcoming'
         ORDER BY e.event_date LIMIT 1) AS next_event_title,
       (SELECT e.event_date FROM Event e WHERE e.club_id = c.club_id AND e.status = 'Upcoming'
         ORDER BY e.event_date LIMIT 1) AS next_event_date
  FROM Club c
  JOIN Faculty f ON c.faculty_id = f.faculty_id;

-- VIP passes waiting for a decision, shown on the society's Manage page
CREATE VIEW v_vip_requests AS
SELECT p.pass_id, p.status, p.requested_on, f.name AS faculty_name, f.department,
       e.event_id, e.title AS event_title, e.club_id, e.vip_seats,
       (SELECT COUNT(*) FROM VIP_Pass x WHERE x.event_id = e.event_id AND x.status = 'Approved') AS vip_taken
  FROM VIP_Pass p
  JOIN Faculty f ON f.faculty_id = p.faculty_id
  JOIN Event   e ON e.event_id   = p.event_id;

-- =====================================================================
-- PERMISSIONS (DCL) for the new objects
-- =====================================================================
GRANT SELECT ON society_events.v_spill_the_tea    TO role_student;
GRANT SELECT ON society_events.v_featured_events  TO role_student;
GRANT SELECT ON society_events.v_society_cards    TO role_student;
GRANT INSERT, UPDATE, DELETE ON society_events.Saved_Event TO role_student;
GRANT EXECUTE ON PROCEDURE society_events.sp_update_member_role TO role_clubhead;
GRANT UPDATE ON society_events.VIP_Pass TO role_clubhead;
