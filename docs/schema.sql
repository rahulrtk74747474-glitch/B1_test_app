PRAGMA foreign_keys = ON;

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  topic TEXT NOT NULL,
  question TEXT NOT NULL,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  answer TEXT NOT NULL CHECK(answer IN ('A','B','C','D')),
  explanation TEXT NOT NULL DEFAULT '',
  question_en TEXT NOT NULL DEFAULT '',
  option_a_en TEXT NOT NULL DEFAULT '',
  option_b_en TEXT NOT NULL DEFAULT '',
  option_c_en TEXT NOT NULL DEFAULT '',
  option_d_en TEXT NOT NULL DEFAULT '',
  explanation_en TEXT NOT NULL DEFAULT '',
  difficulty TEXT NOT NULL DEFAULT 'medium',
  source TEXT NOT NULL DEFAULT '',
  image_path TEXT,
  imported_at INTEGER NOT NULL
);
CREATE INDEX idx_questions_topic ON questions(topic);

CREATE TABLE progress (
  question_id INTEGER PRIMARY KEY,
  attempts INTEGER NOT NULL DEFAULT 0,
  correct_count INTEGER NOT NULL DEFAULT 0,
  last_answered INTEGER,
  first_answered INTEGER,
  next_due INTEGER NOT NULL DEFAULT 0,
  ease_factor REAL NOT NULL DEFAULT 2.5,
  interval_days INTEGER NOT NULL DEFAULT 0,
  repetitions INTEGER NOT NULL DEFAULT 0,
  bookmarked INTEGER NOT NULL DEFAULT 0,
  personal_note TEXT NOT NULL DEFAULT '',
  average_time_ms REAL NOT NULL DEFAULT 0,
  last_result INTEGER,
  last_rating TEXT,
  repeat_every INTEGER NOT NULL DEFAULT 0,
  next_repeat_review INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY(question_id) REFERENCES questions(id) ON DELETE CASCADE
);
CREATE INDEX idx_progress_due ON progress(next_due);

CREATE TABLE reviews (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  question_id INTEGER NOT NULL,
  answered_at INTEGER NOT NULL,
  correct INTEGER NOT NULL,
  rating TEXT NOT NULL,
  time_ms INTEGER NOT NULL,
  selected_answer TEXT NOT NULL,
  mode TEXT NOT NULL,
  FOREIGN KEY(question_id) REFERENCES questions(id) ON DELETE CASCADE
);
CREATE INDEX idx_reviews_answered ON reviews(answered_at);
