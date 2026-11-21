// Batch 2 + 3 (short version): public data and the actions we demo.
// The logged-in user always comes from the signed token (req.user), never from the request body.
const express = require('express');
const pool = require('./db');
const { requireAuth, requireRole } = require('./auth');

const router = express.Router();
const wrap = (fn) => (req, res, next) => fn(req, res, next).catch(next);

// ---------- helpers ----------
const EVENT_SELECT =
  'SELECT e.event_id, e.title, e.category, e.event_type, e.event_date, e.fee, e.status, ' +
  '       e.image_url, e.accent_color, e.bg_color, e.organiser_label, e.run_by, e.description, ' +
  '       e.prize_amount, e.vip_seats, e.registration_deadline, e.team_min, e.team_max, ' +
  '       c.club_id, c.club_name, v.venue_name, v.building, v.capacity AS venue_capacity, ' +
  '       (SELECT COUNT(*) FROM Registration r WHERE r.event_id = e.event_id AND r.status <> \'Cancelled\') AS registered ' +
  '  FROM Event e ' +
  '  JOIN Club  c ON c.club_id  = e.club_id ' +
  '  JOIN Venue v ON v.venue_id = e.venue_id ';

const withSeats = (rows) =>
  rows.map((r) => ({ ...r, seats_left: Math.max(0, r.venue_capacity - r.registered) }));

// is this user the President of this society?
async function isPresident(user, clubId) {
  if (!user.student_id) return false;
  const [rows] = await pool.query(
    "SELECT 1 FROM Membership WHERE student_id = ? AND club_id = ? AND `role` = 'President'",
    [user.student_id, clubId]
  );
  return rows.length > 0;
}

// =====================================================================
// PUBLIC ROUTES (no login)
// =====================================================================

// Landing page: carousel, spill the tea, society count
router.get('/landing', wrap(async (req, res) => {
  const [featured] = await pool.query('SELECT * FROM v_featured_events');
  const [tea] = await pool.query('SELECT * FROM v_spill_the_tea');
  const [[cnt]] = await pool.query('SELECT COUNT(*) AS societies FROM Club');
  res.json({ featured, tea, societies: cnt.societies });
}));

// Events list. Filters: category, type, when, free, q, page
router.get('/events', wrap(async (req, res) => {
  const { category, type, when, free, q } = req.query;
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const size = 12;
  const where = ["e.status = 'Upcoming'"];
  const params = [];
  if (category) { where.push('e.category = ?'); params.push(category); }
  if (type)     { where.push('e.event_type = ?'); params.push(type); }
  if (free === '1') where.push('e.fee = 0');
  if (q) { where.push('(e.title LIKE ? OR c.club_name LIKE ?)'); params.push(`%${q}%`, `%${q}%`); }
  if (when === 'today')   where.push('DATE(e.event_date) = CURDATE()');
  if (when === 'week')    where.push('e.event_date >= NOW() AND e.event_date < NOW() + INTERVAL 7 DAY');
  if (when === 'weekend') where.push('DAYOFWEEK(e.event_date) IN (1,7) AND e.event_date >= NOW() AND e.event_date < NOW() + INTERVAL 7 DAY');
  if (when === 'month')   where.push('YEAR(e.event_date) = YEAR(NOW()) AND MONTH(e.event_date) = MONTH(NOW())');

  const [rows] = await pool.query(
    EVENT_SELECT + ' WHERE ' + where.join(' AND ') + ' ORDER BY e.event_date LIMIT ? OFFSET ?',
    [...params, size, (page - 1) * size]
  );
  res.json({ page, events: withSeats(rows) });
}));

// One event
router.get('/events/:id', wrap(async (req, res) => {
  const [rows] = await pool.query(EVENT_SELECT + ' WHERE e.event_id = ?', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Event not found' });
  res.json(withSeats(rows)[0]);
}));

// Hackathons tab and page
router.get('/hackathons', wrap(async (req, res) => {
  const [rows] = await pool.query(
    EVENT_SELECT + " WHERE e.category = 'Hackathon' ORDER BY e.event_date DESC"
  );
  res.json(withSeats(rows));
}));

// Societies directory. Filters: group, open=1, q
router.get('/societies', wrap(async (req, res) => {
  const { group, open, q } = req.query;
  const where = ['1=1'];
  const params = [];
  if (group) { where.push('sub_category = ?'); params.push(group); }
  if (open === '1') where.push('registration_open = 1');
  if (q) { where.push('(club_name LIKE ? OR tagline LIKE ?)'); params.push(`%${q}%`, `%${q}%`); }
  const [rows] = await pool.query(
    'SELECT * FROM v_society_cards WHERE ' + where.join(' AND ') + ' ORDER BY club_name',
    params
  );
  res.json(rows);
}));

// One society: card data plus its upcoming events
router.get('/societies/:id', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM v_society_cards WHERE club_id = ?', [req.params.id]);
  if (!rows.length) return res.status(404).json({ error: 'Society not found' });
  const [events] = await pool.query(
    EVENT_SELECT + " WHERE e.club_id = ? AND e.status = 'Upcoming' ORDER BY e.event_date",
    [req.params.id]
  );
  res.json({ ...rows[0], events: withSeats(events) });
}));

// =====================================================================
// ACTIONS (login needed)
// =====================================================================

// Register for an event. Calls the stored procedure (one transaction: registration + payment).
router.post('/events/:id/register', requireAuth, wrap(async (req, res) => {
  if (!req.user.student_id)
    return res.status(403).json({ error: 'Only students and external participants can register for events' });
  const mode = ['UPI', 'Cash', 'Card', 'NetBanking'].includes(req.body && req.body.mode) ? req.body.mode : 'UPI';
  const conn = await pool.getConnection();
  try {
    await conn.query('CALL sp_register_and_pay(?, ?, ?, @rid)', [req.user.student_id, req.params.id, mode]);
    const [[out]] = await conn.query('SELECT @rid AS reg_id');
    const [[reg]] = await conn.query('SELECT reg_id, status FROM Registration WHERE reg_id = ?', [out.reg_id]);
    res.status(201).json(reg);
  } finally {
    conn.release();
  }
}));

// My registrations
router.get('/my/registrations', requireAuth, wrap(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT r.reg_id, r.status, r.reg_date, e.event_id, e.title, e.event_date, e.fee, c.club_name ' +
    '  FROM Registration r JOIN Event e ON e.event_id = r.event_id JOIN Club c ON c.club_id = e.club_id ' +
    ' WHERE r.student_id = ? ORDER BY e.event_date',
    [req.user.student_id || 0]
  );
  res.json(rows);
}));

// Apply to join a society (needs the society's forms to be open: trigger checks it)
router.post('/societies/:id/apply', requireAuth, requireRole('student'), wrap(async (req, res) => {
  const msg = ((req.body && req.body.message) || '').slice(0, 300) || null;
  await pool.query(
    'INSERT INTO Membership_Request (student_id, club_id, message) VALUES (?,?,?)',
    [req.user.student_id, req.params.id, msg]
  );
  res.status(201).json({ applied: true });
}));

// ---------- Manage tab (President only) ----------
router.get('/societies/:id/manage', requireAuth, wrap(async (req, res) => {
  if (!(await isPresident(req.user, req.params.id)))
    return res.status(403).json({ error: 'Only the society President can open this page' });
  const [members] = await pool.query(
    'SELECT s.student_id, s.roll_no, s.name, s.branch, m.`role`, m.join_date ' +
    '  FROM Membership m JOIN Student s ON s.student_id = m.student_id ' +
    ' WHERE m.club_id = ? ORDER BY m.join_date',
    [req.params.id]
  );
  const [requests] = await pool.query('SELECT * FROM v_pending_requests WHERE club_id = ? ORDER BY requested_on', [req.params.id]);
  const [vip] = await pool.query("SELECT * FROM v_vip_requests WHERE club_id = ? AND status = 'Pending'", [req.params.id]);
  const [[club]] = await pool.query('SELECT registration_open FROM Club WHERE club_id = ?', [req.params.id]);
  res.json({ registration_open: club.registration_open, members, requests, vip });
}));

// Change a member's role (procedure checks President + at least one President)
router.put('/societies/:id/members/:studentId/role', requireAuth, wrap(async (req, res) => {
  await pool.query('CALL sp_update_member_role(?,?,?,?)', [
    req.user.student_id || 0, req.params.id, req.params.studentId, (req.body && req.body.role) || '',
  ]);
  res.json({ updated: true });
}));

// Approve or reject an application (procedure checks President)
router.put('/requests/:requestId/decide', requireAuth, wrap(async (req, res) => {
  await pool.query('CALL sp_decide_request(?,?,?)', [
    req.user.student_id || 0, req.params.requestId, (req.body && req.body.decision) || '',
  ]);
  res.json({ decided: true });
}));

// Pause or open intake
router.put('/societies/:id/intake', requireAuth, wrap(async (req, res) => {
  if (!(await isPresident(req.user, req.params.id)))
    return res.status(403).json({ error: 'Only the society President can do this' });
  await pool.query('UPDATE Club SET registration_open = ? WHERE club_id = ?', [req.body && req.body.open ? 1 : 0, req.params.id]);
  res.json({ updated: true });
}));

// ---------- VIP passes ----------
// Faculty ask for a VIP seat (trigger checks that the event has VIP seats)
router.post('/events/:id/vip', requireAuth, requireRole('faculty'), wrap(async (req, res) => {
  await pool.query('INSERT INTO VIP_Pass (faculty_id, event_id) VALUES (?,?)', [req.user.faculty_id, req.params.id]);
  res.status(201).json({ requested: true });
}));

// President approves or rejects (trigger checks seats left)
router.put('/vip/:passId/decide', requireAuth, wrap(async (req, res) => {
  const decision = req.body && req.body.decision;
  if (!['Approved', 'Rejected'].includes(decision))
    return res.status(400).json({ error: 'Decision must be Approved or Rejected' });
  const [[p]] = await pool.query('SELECT club_id FROM v_vip_requests WHERE pass_id = ?', [req.params.passId]);
  if (!p) return res.status(404).json({ error: 'Pass request not found' });
  if (!(await isPresident(req.user, p.club_id)))
    return res.status(403).json({ error: 'Only the society President can decide this' });
  await pool.query(
    "UPDATE VIP_Pass SET status = ?, decided_by = ?, decided_on = NOW() WHERE pass_id = ? AND status = 'Pending'",
    [decision, req.user.student_id, req.params.passId]
  );
  res.json({ decided: true });
}));

module.exports = router;
