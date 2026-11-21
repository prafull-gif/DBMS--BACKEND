-- DCL: three roles. Run as a MySQL admin after schema.sql + seed.sql.
-- Demo passwords only: change them before using this outside a lab.
USE society_events;

CREATE ROLE IF NOT EXISTS role_admin, role_clubhead, role_student;

-- Admin: everything in this database
GRANT ALL PRIVILEGES ON society_events.* TO role_admin;

-- Club head: read most things, manage events (through the checked view),
-- organizers, guests, sponsors and expenses
GRANT SELECT ON society_events.* TO role_clubhead;
GRANT INSERT, UPDATE ON society_events.v_open_events  TO role_clubhead;
GRANT INSERT, UPDATE, DELETE ON society_events.Organizer     TO role_clubhead;
GRANT INSERT, UPDATE, DELETE ON society_events.Event_Guest   TO role_clubhead;
GRANT INSERT, UPDATE, DELETE ON society_events.Event_Sponsor TO role_clubhead;
GRANT INSERT, UPDATE, DELETE ON society_events.Expense       TO role_clubhead;
GRANT INSERT, UPDATE         ON society_events.Result        TO role_clubhead;

-- Student: browse public views, register through the procedure, give feedback
GRANT SELECT ON society_events.v_upcoming_events TO role_student;
GRANT SELECT ON society_events.v_club_summary    TO role_student;
GRANT SELECT ON society_events.Club              TO role_student;
GRANT SELECT ON society_events.Venue             TO role_student;
GRANT EXECUTE ON PROCEDURE society_events.sp_register_and_pay TO role_student;
GRANT INSERT ON society_events.Feedback          TO role_student;

CREATE USER IF NOT EXISTS 'admin_user'@'localhost'    IDENTIFIED BY 'Admin@123';
CREATE USER IF NOT EXISTS 'clubhead_user'@'localhost' IDENTIFIED BY 'Head@123';
CREATE USER IF NOT EXISTS 'student_user'@'localhost'  IDENTIFIED BY 'Stud@123';

GRANT role_admin    TO 'admin_user'@'localhost';
GRANT role_clubhead TO 'clubhead_user'@'localhost';
GRANT role_student  TO 'student_user'@'localhost';
SET DEFAULT ROLE ALL TO 'admin_user'@'localhost', 'clubhead_user'@'localhost', 'student_user'@'localhost';
