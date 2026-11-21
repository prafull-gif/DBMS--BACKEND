// Batch 1: register, login, who am I, and admin approval of faculty accounts.
// Passwords are stored only as bcrypt hashes. The logged-in user always comes
// from the signed token, never from the request body.
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('./db');

if (!process.env.JWT_SECRET) {
  console.error('JWT_SECRET is missing. Add it to your .env file.');
  process.exit(1);
}
const SECRET = process.env.JWT_SECRET;

const router = express.Router();
const wrap = (fn) => (req, res, next) => fn(req, res, next).catch(next);
const emailOk = (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e || '');

function signToken(acc) {
  return jwt.sign(
    { account_id: acc.account_id, role: acc.role, student_id: acc.student_id || null, faculty_id: acc.faculty_id || null },
    SECRET,
    { expiresIn: '7d' }
  );
}

function publicUser(acc) {
  return {
    account_id: acc.account_id, role: acc.role, name: acc.name, email: acc.email,
    roll_no: acc.roll_no || null, student_id: acc.student_id || null, faculty_id: acc.faculty_id || null,
  };
}

// ---------- middleware (other route files will import these) ----------
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Please log in' });
  try {
    req.user = jwt.verify(token, SECRET);
    next();
  } catch (e) {
    res.status(401).json({ error: 'Your session has expired. Please log in again.' });
  }
}

const requireRole = (...roles) => (req, res, next) =>
  roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'You do not have access to this' });

// ---------- POST /api/auth/register ----------
router.post('/auth/register', wrap(async (req, res) => {
  const b = req.body || {};
  const role = b.role;
  if (!['student', 'faculty', 'external'].includes(role))
    return res.status(400).json({ error: 'Choose Student, Faculty or External participant' });
  if (!b.name || !b.name.trim()) return res.status(400).json({ error: 'Full name is required' });
  if (!emailOk(b.email)) return res.status(400).json({ error: 'Enter a valid email address' });
  if (!b.password || b.password.length < 8) return res.status(400).json({ error: 'Password must be at least 8 characters' });
  if (role === 'student' && !(b.roll_no || '').trim()) return res.status(400).json({ error: 'College roll number is required' });
  if (role === 'faculty' && !(b.department || '').trim()) return res.status(400).json({ error: 'Department is required' });
  if (role === 'external' && !(b.college_name || '').trim()) return res.status(400).json({ error: 'College name is required' });

  const email = b.email.trim().toLowerCase();
  const hash = await bcrypt.hash(b.password, 10);
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    let student_id = null;
    let faculty_id = null;

    if (role === 'faculty') {
      const [f] = await conn.query(
        'INSERT INTO Faculty (name, department, email, phone, designation) VALUES (?,?,?,?,?)',
        [b.name.trim(), b.department.trim(), email, b.phone || null, b.designation || null]
      );
      faculty_id = f.insertId;
    } else {
      const [s] = await conn.query(
        'INSERT INTO Student (roll_no, name, branch, `year`, email, is_external, college_name) VALUES (?,?,?,?,?,?,?)',
        [
          role === 'student' ? b.roll_no.trim().toUpperCase() : null,
          b.name.trim(), b.branch || null, b.year || null, email,
          role === 'external' ? 1 : 0,
          role === 'external' ? b.college_name.trim() : null,
        ]
      );
      student_id = s.insertId;
    }

    // a trigger sets is_approved = 0 for faculty
    const [a] = await conn.query(
      'INSERT INTO Account (email, password_hash, `role`, student_id, faculty_id) VALUES (?,?,?,?,?)',
      [email, hash, role, student_id, faculty_id]
    );
    await conn.commit();

    if (role === 'faculty') {
      return res.status(201).json({ pending: true, message: 'Account created. An admin must approve it before you can log in.' });
    }
    const acc = { account_id: a.insertId, role, student_id, faculty_id, name: b.name.trim(), email, roll_no: role === 'student' ? b.roll_no.trim().toUpperCase() : null };
    res.status(201).json({ token: signToken(acc), user: publicUser(acc) });
  } catch (err) {
    await conn.rollback();
    if (err.code === 'ER_DUP_ENTRY') {
      const msg = err.sqlMessage || '';
      return res.status(409).json({ error: msg.includes('roll_no') ? 'This roll number is already registered' : 'This email is already registered' });
    }
    throw err;
  } finally {
    conn.release();
  }
}));

// ---------- POST /api/auth/login  (roll number OR email) ----------
router.post('/auth/login', wrap(async (req, res) => {
  const { identifier, password } = req.body || {};
  if (!identifier || !password)
    return res.status(400).json({ error: 'Enter your roll number or email and your password' });
  const id = identifier.trim();

  const [rows] = await pool.query(
    'SELECT a.account_id, a.password_hash, a.`role`, a.student_id, a.faculty_id, a.is_approved, a.email, ' +
    "       COALESCE(s.name, f.name, 'Admin') AS name, s.roll_no " +
    '  FROM Account a ' +
    '  LEFT JOIN Student s ON s.student_id = a.student_id ' +
    '  LEFT JOIN Faculty f ON f.faculty_id = a.faculty_id ' +
    ' WHERE a.email = ? OR s.roll_no = ?',
    [id.toLowerCase(), id.toUpperCase()]
  );
  const acc = rows[0];
  const ok = acc && (await bcrypt.compare(password, acc.password_hash));
  if (!ok) return res.status(401).json({ error: 'Wrong roll number, email or password' });
  if (!acc.is_approved) return res.status(403).json({ error: 'Your account is waiting for admin approval' });

  res.json({ token: signToken(acc), user: publicUser(acc) });
}));

// ---------- GET /api/me  (header menu and dashboard need this) ----------
router.get('/me', requireAuth, wrap(async (req, res) => {
  const { account_id, student_id, faculty_id } = req.user;
  const [rows] = await pool.query(
    'SELECT a.account_id, a.`role`, a.student_id, a.faculty_id, a.email, ' +
    "       COALESCE(s.name, f.name, 'Admin') AS name, s.roll_no, s.branch, s.`year`, f.department, f.designation " +
    '  FROM Account a ' +
    '  LEFT JOIN Student s ON s.student_id = a.student_id ' +
    '  LEFT JOIN Faculty f ON f.faculty_id = a.faculty_id ' +
    ' WHERE a.account_id = ?',
    [account_id]
  );
  if (!rows.length) return res.status(404).json({ error: 'Account not found' });

  let societies = [];
  if (student_id) {
    [societies] = await pool.query(
      'SELECT c.club_id, c.club_name, m.`role`, m.join_date ' +
      '  FROM Membership m JOIN Club c ON c.club_id = m.club_id ' +
      ' WHERE m.student_id = ? ORDER BY c.club_name',
      [student_id]
    );
  } else if (faculty_id) {
    [societies] = await pool.query(
      'SELECT c.club_id, c.club_name, fm.`role`, fm.join_date ' +
      '  FROM Faculty_Membership fm JOIN Club c ON c.club_id = fm.club_id ' +
      ' WHERE fm.faculty_id = ? ORDER BY c.club_name',
      [faculty_id]
    );
  }
  res.json({
    user: rows[0],
    societies,
    president_of: societies.filter((s) => s.role === 'President').map((s) => s.club_id),
  });
}));

// ---------- Admin: approve faculty accounts ----------
router.get('/admin/pending-faculty', requireAuth, requireRole('admin'), wrap(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT a.account_id, f.name, f.department, f.designation, f.email, a.created_on ' +
    '  FROM Account a JOIN Faculty f ON f.faculty_id = a.faculty_id ' +
    " WHERE a.`role` = 'faculty' AND a.is_approved = 0 ORDER BY a.created_on"
  );
  res.json(rows);
}));

router.put('/admin/faculty/:accountId/approve', requireAuth, requireRole('admin'), wrap(async (req, res) => {
  const [r] = await pool.query(
    "UPDATE Account SET is_approved = 1 WHERE account_id = ? AND `role` = 'faculty'",
    [req.params.accountId]
  );
  if (!r.affectedRows) return res.status(404).json({ error: 'Faculty account not found' });
  res.json({ approved: true });
}));

module.exports = { router, requireAuth, requireRole };
