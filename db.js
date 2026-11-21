// One shared MySQL connection pool for the whole backend
const mysql = require('mysql2/promise');

module.exports = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'society_events',
  waitForConnections: true,
  connectionLimit: 10,
});
