-- =====================================================================
-- migration_002.sql  |  MySQL 8.0
-- Run order: schema.sql -> seed.sql -> roles.sql -> migration_001.sql -> seed_002.sql -> migration_002.sql
-- Fixes and additions found when checking the 6 Stitch pages against the database:
--   1. Club.category was a 3NF problem (it is decided by sub_category). Dropped.
--   2. Team events (hackathons, BGMI squads): team size on Event, Team and Team_Member tables.
--   3. "Pending forms / applicants" on the society Manage tab: Membership_Request + approval procedure.
--      The old trigger on Membership blocked approving applicants after intake was paused, so the
--      forms-open check now lives on the request instead.
--   4. Winners and gallery on society pages: Event_Photo.
-- =====================================================================
USE society_events;

-- ---------------------------------------------------------------------
-- 1. Normalisation fix: drop Club.category
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_society_cards;
ALTER TABLE Club DROP CHECK chk_club_category;
ALTER TABLE Club DROP COLUMN category;

CREATE VIEW v_society_cards AS
SELECT c.club_id, c.club_name, c.tagline, c.sub_category AS society_group,
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

-- ---------------------------------------------------------------------
-- 2. Team events
-- ---------------------------------------------------------------------
ALTER TABLE Event
  ADD COLUMN team_min TINYINT NOT NULL DEFAULT 1,
  ADD COLUMN team_max TINYINT NOT NULL DEFAULT 1,
  ADD CONSTRAINT chk_event_team CHECK (team_min >= 1 AND team_max >= team_min);

CREATE TABLE Team (
  team_id    INT AUTO_INCREMENT PRIMARY KEY,
  event_id   INT NOT NULL,
  team_name  VARCHAR(80) NOT NULL,
  leader_id  INT NOT NULL,
  created_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_team_name  UNIQUE (event_id, team_name),
  CONSTRAINT uq_team_event UNIQUE (team_id, event_id),      -- lets Team_Member point at (team, event)
  CONSTRAINT fk_team_event  FOREIGN KEY (event_id)  REFERENCES Event(event_id)     ON DELETE CASCADE  ON UPDATE CASCADE,
  CONSTRAINT fk_team_leader FOREIGN KEY (leader_id) REFERENCES Student(student_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- A student can be in only one team per event: UNIQUE (event_id, student_id)
CREATE TABLE Team_Member (
  team_id    INT NOT NULL,
  event_id   INT NOT NULL,
  student_id INT NOT NULL,
  PRIMARY KEY (team_id, student_id),
  CONSTRAINT uq_member_event UNIQUE (event_id, student_id),
  CONSTRAINT fk_tm_team    FOREIGN KEY (team_id, event_id) REFERENCES Team(team_id, event_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_tm_student FOREIGN KEY (student_id)        REFERENCES Student(student_id)     ON DELETE CASCADE ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 3. Society applications
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_membership_forms_open;

CREATE TABLE Membership_Request (
  request_id   INT AUTO_INCREMENT PRIMARY KEY,
  student_id   INT NOT NULL,
  club_id      INT NOT NULL,
  message      VARCHAR(300),
  status       VARCHAR(10) NOT NULL DEFAULT 'Pending',
  requested_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  decided_by   INT NULL,
  decided_on   DATETIME NULL,
  CONSTRAINT chk_mr_status CHECK (status IN ('Pending','Approved','Rejected')),
  CONSTRAINT uq_mr UNIQUE (student_id, club_id),
  CONSTRAINT fk_mr_student FOREIGN KEY (student_id) REFERENCES Student(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_mr_club    FOREIGN KEY (club_id)    REFERENCES Club(club_id)       ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_mr_decider FOREIGN KEY (decided_by) REFERENCES Student(student_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------
-- 4. Gallery
-- ---------------------------------------------------------------------
CREATE TABLE Event_Photo (
  photo_id  INT AUTO_INCREMENT PRIMARY KEY,
  event_id  INT NOT NULL,
  image_url VARCHAR(255) NOT NULL,
  caption   VARCHAR(150),
  added_on  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_photo_event FOREIGN KEY (event_id) REFERENCES Event(event_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- =====================================================================
-- TRIGGERS AND PROCEDURE
-- =====================================================================
DELIMITER $$

-- Team size and registration rules
CREATE TRIGGER trg_team_member_rules BEFORE INSERT ON Team_Member
FOR EACH ROW
BEGIN
  DECLARE v_max TINYINT;
  DECLARE v_cnt INT;
  IF NOT EXISTS (SELECT 1 FROM Registration
                  WHERE student_id = NEW.student_id AND event_id = NEW.event_id
                    AND status <> 'Cancelled') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Register for the event before joining a team';
  END IF;
  SELECT team_max INTO v_max FROM Event WHERE event_id = NEW.event_id;
  SELECT COUNT(*) INTO v_cnt FROM Team_Member WHERE team_id = NEW.team_id;
  IF v_cnt >= v_max THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This team is already full';
  END IF;
END$$

-- Applications: blocked while intake is paused, and for existing members
CREATE TRIGGER trg_request_rules BEFORE INSERT ON Membership_Request
FOR EACH ROW
BEGIN
  DECLARE v_open TINYINT;
  SELECT registration_open INTO v_open FROM Club WHERE club_id = NEW.club_id;
  IF v_open = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Forms are closed for this society';
  END IF;
  IF EXISTS (SELECT 1 FROM Membership
              WHERE student_id = NEW.student_id AND club_id = NEW.club_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You are already a member of this society';
  END IF;
END$$

-- Only the society President can approve or reject; approval creates the Membership
CREATE PROCEDURE sp_decide_request(
  IN p_actor    INT,
  IN p_request  INT,
  IN p_decision VARCHAR(10))
BEGIN
  DECLARE v_club       INT;
  DECLARE v_student    INT;
  DECLARE v_status     VARCHAR(10);
  DECLARE v_actor_role VARCHAR(40);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_decision NOT IN ('Approved','Rejected') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Decision must be Approved or Rejected';
  END IF;

  START TRANSACTION;
    SELECT club_id, student_id, status INTO v_club, v_student, v_status
      FROM Membership_Request WHERE request_id = p_request FOR UPDATE;
    IF v_club IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request not found';
    END IF;
    IF v_status <> 'Pending' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This request was already decided';
    END IF;

    SELECT `role` INTO v_actor_role FROM Membership
     WHERE student_id = p_actor AND club_id = v_club;
    IF v_actor_role IS NULL OR v_actor_role <> 'President' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only the society head can decide requests';
    END IF;

    UPDATE Membership_Request
       SET status = p_decision, decided_by = p_actor, decided_on = NOW()
     WHERE request_id = p_request;
    IF p_decision = 'Approved' THEN
      INSERT INTO Membership (student_id, club_id, `role`) VALUES (v_student, v_club, 'Member');
    END IF;
  COMMIT;
END$$

DELIMITER ;

-- =====================================================================
-- VIEW for the Manage tab
-- =====================================================================
CREATE VIEW v_pending_requests AS
SELECT r.request_id, r.club_id, r.status, r.message, r.requested_on,
       s.student_id, s.roll_no, s.name, s.branch, s.`year`
  FROM Membership_Request r
  JOIN Student s ON s.student_id = r.student_id
 WHERE r.status = 'Pending';

-- =====================================================================
-- DCL
-- =====================================================================
GRANT SELECT ON society_events.v_society_cards   TO role_student;
GRANT INSERT ON society_events.Membership_Request TO role_student;
GRANT SELECT ON society_events.v_pending_requests TO role_clubhead;
GRANT EXECUTE ON PROCEDURE society_events.sp_decide_request TO role_clubhead;
