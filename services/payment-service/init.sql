-- Payment Service Database Schema

CREATE TABLE IF NOT EXISTS payments (
  id SERIAL PRIMARY KEY,
  trip_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  driver_id INTEGER,
  amount DECIMAL(10, 2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'VND',
  status VARCHAR(50) DEFAULT 'pending',
  payment_method VARCHAR(50),
  transaction_id VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payments_trip_id ON payments(trip_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
