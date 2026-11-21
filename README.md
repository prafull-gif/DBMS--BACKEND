# Society & Event Management System

## 1. Database (MySQL 8.0)
```
mysql -u root -p < schema.sql
mysql -u root -p < seed.sql
mysql -u root -p < roles.sql
```
Quick checks inside the mysql shell:
```
USE society_events;
SELECT * FROM v_club_summary;
SELECT * FROM v_unpaid_registrations;
INSERT INTO Registration (student_id, event_id) VALUES (7,3);   -- Venue capacity full
```

## 2. Backend
```
cd backend
npm install
copy .env.example to .env and set DB_PASSWORD
npm run dev
```
Test in the browser or Postman:
- GET  http://localhost:5000/api/health
- GET  http://localhost:5000/api/clubs
- GET  http://localhost:5000/api/students?q=aarav
- GET  http://localhost:5000/api/clubs/1/members
- POST http://localhost:5000/api/clubs/2/join   body: {"student_id": 3, "role": "Member"}

## 3. Next
Frontend (React + Tailwind, dark Railway-style) calling these routes.
