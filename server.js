// Module 1: Student & Membership (plus the Faculty/Club reads it depends on)
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db');
const { router: authRouter, requireAuth, requireRole } = require('./auth');
const dataRouter = require('./routes');

const app = express();
app.use(cors());
app.use(express.json());
app.use('/api', authRouter);   // /api/auth/register, /api/auth/login, /api/me, /api/admin/...
app.use('/api', dataRouter);   // landing, events, societies, hackathons, actions

// lets us use async handlers without try/catch in every route
const wrap = (fn) => (req, res, next) => fn(req, res, next).catch(next);

app.get('/api/health', wrap(async (req, res) => {
  await pool.query('SELECT 1');
  res.json({ ok: true });
}));

// ---------- Students ----------
app.get('/api/students', wrap(async (req, res) => {
  const like = `%${req.query.q || ''}%`;
  const [rows] = await pool.query(
    'SELECT student_id, roll_no, name, branch, `year`, email, is_external, college_name ' +
    'FROM Student WHERE name LIKE ? OR roll_no LIKE ? ORDER BY name',
    [like, like]
  );
  res.json(rows);
}));

app.get('/api/students/:id', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM Student WHERE student_id = ?', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Student not found' });
  res.json(rows[0]);
}));

app.post('/api/students', requireAuth, requireRole('admin'), wrap(async (req, res) => {
  const { roll_no = null, name, branch = null, year = null, email,
          is_external = 0, college_name = null } = req.body;
  const [r] = await pool.query(
    'INSERT INTO Student (roll_no, name, branch, `year`, email, is_external, college_name) VALUES (?,?,?,?,?,?,?)',
    [roll_no, name, branch, year, email, is_external ? 1 : 0, college_name]
  );
  res.status(201).json({ student_id: r.insertId });
}));

app.put('/api/students/:id', requireAuth, requireRole('admin'), wrap(async (req, res) => {
  const { name, branch, year, email } = req.body;
  const [r] = await pool.query(
    'UPDATE Student SET name = ?, branch = ?, `year` = ?, email = ? WHERE student_id = ?',
    [name, branch, year, email, req.params.id]
  );
  if (!r.affectedRows) return res.status(404).json({ error: 'Student not found' });
  res.json({ updated: true });
}));

app.delete('/api/students/:id', requireAuth, requireRole('admin'), wrap(async (req, res) => {
  const [r] = await pool.query('DELETE FROM Student WHERE student_id = ?', [req.params.id]);
  if (!r.affectedRows) return res.status(404).json({ error: 'Student not found' });
  res.json({ deleted: true });
}));

app.get('/api/students/:id/memberships', wrap(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT c.club_id, c.club_name, c.sub_category, m.`role`, m.join_date ' +
    'FROM Membership m JOIN Club c ON c.club_id = m.club_id ' +
    'WHERE m.student_id = ? ORDER BY m.join_date DESC',
    [req.params.id]
  );
  res.json(rows);
}));

// ---------- Faculty & Clubs ----------
app.get('/api/faculty', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT faculty_id, name, department, designation FROM Faculty ORDER BY name');
  res.json(rows);
}));

app.get('/api/clubs', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM v_club_summary ORDER BY club_name');
  res.json(rows);
}));

app.post('/api/clubs', requireAuth, requireRole('admin'), wrap(async (req, res) => {
  const { club_name, faculty_id, category = null } = req.body; // 'category' now means the society group
  const [r] = await pool.query(
    'INSERT INTO Club (club_name, faculty_id, sub_category) VALUES (?,?,?)',
    [club_name, faculty_id, category]
  );
  res.status(201).json({ club_id: r.insertId });
}));

app.get('/api/clubs/:id/members', wrap(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT s.student_id, s.roll_no, s.name, s.branch, m.`role`, m.join_date ' +
    'FROM Membership m JOIN Student s ON s.student_id = m.student_id ' +
    'WHERE m.club_id = ? ORDER BY m.join_date',
    [req.params.id]
  );
  res.json(rows);
}));

app.post('/api/clubs/:id/join', requireAuth, requireRole('admin'), wrap(async (req, res) => {
  const { student_id, role = 'Member' } = req.body;
  await pool.query(
    'INSERT INTO Membership (student_id, club_id, `role`) VALUES (?,?,?)',
    [student_id, req.params.id, role]
  );
  res.status(201).json({ joined: true });
}));

app.delete('/api/clubs/:id/members/:studentId', requireAuth, requireRole('admin'), wrap(async (req, res) => {
  const [r] = await pool.query(
    'DELETE FROM Membership WHERE club_id = ? AND student_id = ?',
    [req.params.id, req.params.studentId]
  );
  if (!r.affectedRows) return res.status(404).json({ error: 'Membership not found' });
  res.json({ left: true });
}));

// ---------- Error handler: turn MySQL errors into clean API errors ----------
app.use((err, req, res, next) => {
  const map = {
    ER_DUP_ENTRY:                 [409, 'Duplicate entry'],
    ER_NO_REFERENCED_ROW_2:       [400, 'Referenced record does not exist'],
    ER_ROW_IS_REFERENCED_2:       [409, 'Record is still in use elsewhere'],
    ER_CHECK_CONSTRAINT_VIOLATED: [400, 'Value breaks a table constraint'],
    ER_BAD_NULL_ERROR:            [400, 'A required field is missing'],
  };
  if (map[err.code]) return res.status(map[err.code][0]).json({ error: map[err.code][1], detail: err.sqlMessage });
  if (err.sqlState === '45000') return res.status(400).json({ error: err.sqlMessage }); // our triggers
  console.error(err);
  res.status(500).json({ error: 'Server error' });
});

const port = process.env.PORT || 5000;
app.listen(port, () => console.log(`API running on http://localhost:${port}`));
