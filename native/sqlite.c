/* Narrow SQLite marshalling boundary for the pinned Bend runtime.
 * No application SQL or policy belongs here. Every argument is copied before
 * io_work; workers touch only their own C allocation and borrowed connection.
 * Every result is copied before statement finalization and packed on the loop.
 */
#include <sqlite3.h>
#include <inttypes.h>
#include <math.h>
#include <ctype.h>

#define JB_SQL_HANDLES 64
#define JB_SQL_BYTES (4u * 1024u * 1024u)
#define JB_SQL_ROWS 4096u
#define JB_SQL_COLUMNS 256u
#define JB_SQL_BINDINGS 4096u

typedef struct { sqlite3* db; u32 token; bool busy; } JbSqlHandle;
/* The IO loop alone touches this registry. Workers use the copied pointer in
 * their call, and busy keeps its slot alive until packing returns to the loop. */
static JbSqlHandle jb_sql_handles[JB_SQL_HANDLES];
static u64 jb_sql_next_token = 1; /* never wrap or reuse a public identity */

typedef struct {
  int kind;
  char* bytes;
  u64 len;
  sqlite3_int64 integer;
  double real;
} JbSqlCell;

typedef struct {
  int operation, code, slot;
  u32 token, max_rows, columns, rows, bindings;
  char* text;
  u64 text_len, input_bytes, output_bytes, deadline;
  sqlite3* db;
  JbSqlCell* args;
  JbSqlCell* cells;
} JbSqlCall;

static void jb_sql_free(JbSqlCall* p) {
  for (u32 i = 0; i < p->bindings; ++i) free(p->args[i].bytes);
  for (u32 i = 0; i < p->rows * p->columns; ++i) free(p->cells[i].bytes);
  free(p->args);
  free(p->cells);
  free(p->text);
  free(p);
}

/* Consume the complete affine list even when a limit or invalid byte is found.
 * Allocations are bounded; malformed external byte input never wraps to u8. */
static char* jb_sql_bytes(Env e, Term xs, bool text, u64* length, int* code) {
  u64 cap = 64, len = 0;
  char* bytes = io_mem(malloc(cap));
  u64 cons = CID(SCon);
#ifdef CID(query)
  if (!text) cons = CID(Con);
#endif
  while (term_aux(xs) == cons) {
    Term pair[2];
    spare_free(e, cls_fit(2), ctr_take(e, xs, 2, pair));
    char encoded[4];
    if (text && (pair[0] > 0x10ffff || (pair[0] >= 0xd800 && pair[0] <= 0xdfff)))
      *code = SQLITE_MISMATCH;
    u64 size = text ? io_utf8(encoded, pair[0]) : 1;
    if (!text) {
      if (pair[0] > 255) *code = SQLITE_MISMATCH;
      encoded[0] = (char)pair[0];
    }
    if (size > JB_SQL_BYTES - len) {
      *code = SQLITE_TOOBIG;
    } else if (*code == 0) {
      if (len + size + 1 > cap) {
        cap *= 2;
        bytes = io_mem(realloc(bytes, cap));
      }
      memcpy(bytes + len, encoded, size);
      len += size;
    }
    xs = pair[1];
  }
  bytes[len] = 0;
  *length = len;
  return bytes;
}

static bool jb_sql_i64(const char* s, u64 n, sqlite3_int64* result) {
  if (n == 0 || n > 20) return false;
  bool neg = s[0] == '-';
  u64 i = neg ? 1 : 0;
  if (i == n || (s[i] == '0' && (neg || n - i != 1))) return false;
  uint64_t value = 0;
  uint64_t max = neg ? UINT64_C(9223372036854775808)
                    : UINT64_C(9223372036854775807);
  for (; i < n; ++i) {
    if (s[i] < '0' || s[i] > '9') return false;
    u64 digit = (u64)(s[i] - '0');
    if (value > (max - digit) / 10) return false;
    value = value * 10 + digit;
  }
  *result = neg ? -(sqlite3_int64)(value - 1) - 1 : (sqlite3_int64)value;
  return true;
}

static bool jb_sql_real(const char* s, u64 n, double* result) {
  if (n == 0 || n > 128 || io_nul(s, n)) return false;
  /* Accept decimal notation only, never locale whitespace, NaN, Inf or hex. */
  u64 i = s[0] == '-' ? 1 : 0, digits = 0;
  for (; i < n && s[i] >= '0' && s[i] <= '9'; ++i) ++digits;
  if (i < n && s[i] == '.') {
    ++i;
    for (; i < n && s[i] >= '0' && s[i] <= '9'; ++i) ++digits;
  }
  if (digits == 0) return false;
  if (i < n && (s[i] == 'e' || s[i] == 'E')) {
    ++i;
    if (i < n && (s[i] == '+' || s[i] == '-')) ++i;
    u64 start = i;
    for (; i < n && s[i] >= '0' && s[i] <= '9'; ++i) {}
    if (i == start) return false;
  }
  if (i != n) return false;
  errno = 0;
  char* end;
  *result = strtod(s, &end);
  return end == s + n && errno != ERANGE && isfinite(*result);
}

static bool jb_sql_utf8(const char* p, u64 n) {
  u32 need = 0, lo = 0x80, hi = 0xbf;
  for (u64 i = 0; i < n; ++i) {
    u32 c = (uint8_t)p[i];
    if (need) {
      if (c < lo || c > hi) return false;
      --need; lo = 0x80; hi = 0xbf;
    } else if (c < 0x80) {
    } else if (c >= 0xc2 && c <= 0xf4) {
      need = c < 0xe0 ? 1 : c < 0xf0 ? 2 : 3;
      lo = c == 0xe0 ? 0xa0 : c == 0xf0 ? 0x90 : 0x80;
      hi = c == 0xed ? 0x9f : c == 0xf4 ? 0x8f : 0xbf;
    } else return false;
  }
  return need == 0;
}

static int jb_sql_progress(void* context) {
  return io_tick() >= ((JbSqlCall*)context)->deadline;
}

static void jb_sql_query_call(JbSqlCall* p) {
  sqlite3_stmt* stmt = NULL;
  sqlite3_stmt* extra = NULL;
  const char* tail = NULL;
  p->deadline = io_tick() + UINT64_C(2000000000);
  sqlite3_progress_handler(p->db, 1000, jb_sql_progress, p);
  p->code = sqlite3_prepare_v2(p->db, p->text, (int)p->text_len + 1, &stmt, &tail);
  if (p->code != SQLITE_OK) goto done;
  if (stmt == NULL) { p->code = SQLITE_MISUSE; goto done; }
  /* A second prepare permits trailing whitespace/comments but rejects another
   * statement before executing the first, so no partial mutation can occur. */
  p->code = sqlite3_prepare_v2(p->db, tail, -1, &extra, NULL);
  if (p->code != SQLITE_OK) goto done;
  if (extra != NULL) { p->code = SQLITE_MISUSE; goto done; }
  if ((u32)sqlite3_bind_parameter_count(stmt) != p->bindings) {
    p->code = SQLITE_RANGE; goto done;
  }
  for (u32 i = 0; i < p->bindings; ++i) {
    JbSqlCell* a = &p->args[i];
    int at = (int)i + 1;
    switch (a->kind) {
      case SQLITE_NULL: p->code = sqlite3_bind_null(stmt, at); break;
      case SQLITE_INTEGER: p->code = sqlite3_bind_int64(stmt, at, a->integer); break;
      case SQLITE_FLOAT: p->code = sqlite3_bind_double(stmt, at, a->real); break;
      case SQLITE_TEXT:
        p->code = sqlite3_bind_text(stmt, at, a->bytes, (int)a->len, SQLITE_TRANSIENT);
        break;
      case SQLITE_BLOB:
        /* Non-NULL allocation keeps the empty blob distinct from NULL. */
        p->code = sqlite3_bind_blob(stmt, at, a->bytes, (int)a->len, SQLITE_TRANSIENT);
        break;
    }
    if (p->code != SQLITE_OK) goto done;
  }
  p->columns = (u32)sqlite3_column_count(stmt);
  if (p->columns > JB_SQL_COLUMNS) { p->code = SQLITE_TOOBIG; goto done; }
  while ((p->code = sqlite3_step(stmt)) == SQLITE_ROW) {
    if (p->rows == p->max_rows) { p->code = SQLITE_TOOBIG; goto done; }
    u64 count = (u64)(p->rows + 1) * p->columns;
    /* Bound metadata too, even for all-NULL results. */
    if (count > JB_SQL_BYTES / sizeof(JbSqlCell)) {
      p->code = SQLITE_TOOBIG; goto done;
    }
    p->cells = io_mem(realloc(p->cells, count * sizeof(JbSqlCell)));
    memset(p->cells + p->rows * p->columns, 0, p->columns * sizeof(JbSqlCell));
    ++p->rows; /* includes partial row, so failure cleanup owns every cell */
    for (u32 col = 0; col < p->columns; ++col) {
      JbSqlCell* cell = &p->cells[(p->rows - 1) * p->columns + col];
      cell->kind = sqlite3_column_type(stmt, (int)col);
      if (cell->kind == SQLITE_NULL) continue;
      if (cell->kind == SQLITE_INTEGER) {
        cell->integer = sqlite3_column_int64(stmt, (int)col);
      } else {
        const void* data = cell->kind == SQLITE_BLOB
          ? sqlite3_column_blob(stmt, (int)col) : sqlite3_column_text(stmt, (int)col);
        int n = sqlite3_column_bytes(stmt, (int)col);
        if (data == NULL && n != 0) { p->code = SQLITE_NOMEM; goto done; }
        if ((u64)n > JB_SQL_BYTES - p->output_bytes) {
          p->code = SQLITE_TOOBIG; goto done;
        }
        if (cell->kind == SQLITE_TEXT && !jb_sql_utf8(data, (u64)n)) {
          p->code = SQLITE_MISMATCH; goto done;
        }
        cell->bytes = io_mem(malloc((size_t)n + 1));
        if (n) memcpy(cell->bytes, data, (size_t)n);
        cell->bytes[n] = 0;
        cell->len = (u64)n;
        p->output_bytes += (u64)n;
      }
    }
  }
  if (p->code == SQLITE_DONE) p->code = SQLITE_OK;
done:
  if (extra != NULL) sqlite3_finalize(extra);
  if (stmt != NULL) {
    int final = sqlite3_finalize(stmt);
    if (p->code == SQLITE_OK) p->code = final;
  }
  sqlite3_progress_handler(p->db, 0, NULL, NULL);
}

static void jb_sql_call(IoWork* w) {
  JbSqlCall* p = (JbSqlCall*)w->data;
  if (p->operation == 0) {
    if (sqlite3_threadsafe() == 0) { p->code = SQLITE_MISUSE; return; }
    p->code = sqlite3_open_v2(p->text, &p->db,
      SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, NULL);
    if (p->code == SQLITE_OK) {
      /* Reject huge SQLite values before their allocation/production, not just
       * when copying columns back. These are transport ceilings, not schema. */
      sqlite3_limit(p->db, SQLITE_LIMIT_LENGTH, JB_SQL_BYTES);
      sqlite3_limit(p->db, SQLITE_LIMIT_SQL_LENGTH, JB_SQL_BYTES);
      sqlite3_limit(p->db, SQLITE_LIMIT_COLUMN, JB_SQL_COLUMNS);
      sqlite3_limit(p->db, SQLITE_LIMIT_VARIABLE_NUMBER, JB_SQL_BINDINGS);
      p->code = sqlite3_busy_timeout(p->db, 250);
    }
    if (p->code != SQLITE_OK && p->db != NULL) {
      sqlite3_close(p->db); p->db = NULL;
    }
  } else if (p->operation == 1) {
    jb_sql_query_call(p);
  } else {
    p->code = sqlite3_close(p->db);
  }
}

#ifdef CID(query)
static Term jb_sql_cell_pack(Env e, JbSqlCell* cell) {
  char integer[32];
  switch (cell->kind) {
    case SQLITE_NULL: return term_pak(CID(Cell.Null), 0);
    case SQLITE_INTEGER:
      snprintf(integer, sizeof integer, "%" PRId64, (int64_t)cell->integer);
      return io_box(e, CID(Cell.Integer), io_str(e, integer, strlen(integer)));
    case SQLITE_TEXT:
      return io_box(e, CID(Cell.Text), io_str(e, cell->bytes, cell->len));
    case SQLITE_BLOB:
      return io_box(e, CID(Cell.Blob), io_list(e, cell->bytes, cell->len));
    default:
      return io_box(e, CID(Cell.Real), io_str(e, cell->bytes, cell->len));
  }
}
#endif

static Term jb_sql_pack(Env e, IoWork* w) {
  JbSqlCall* p = (JbSqlCall*)w->data;
  if (p->slot >= 0) {
    JbSqlHandle* h = &jb_sql_handles[p->slot];
    h->busy = false;
    if (p->operation == 0) {
      h->db = p->db;
      h->token = p->code == SQLITE_OK ? p->token : 0;
    } else if (p->operation == 2 && p->code == SQLITE_OK) {
      h->db = NULL;
      h->token = 0;
    }
  }
  Term result;
  if (p->code != SQLITE_OK) {
    result = io_fail(e, (u32)p->code, sqlite3_errstr(p->code));
  } else if (p->operation == 0) {
    result = io_done(e, (Term)p->token);
  } else if (p->operation == 2) {
    result = io_done(e, term_pak(CID(Unit), 0));
  } else {
#ifdef CID(query)
    Term rows = term_pak(CID(Nil), 0);
    for (u32 row = p->rows; row > 0; --row) {
      Term cols = term_pak(CID(Nil), 0);
      for (u32 col = p->columns; col > 0; --col) {
        Term cell = jb_sql_cell_pack(e, &p->cells[(row - 1) * p->columns + col - 1]);
        cols = io_node(e, CID(Con), cell, cols);
      }
      rows = io_node(e, CID(Con), cols, rows);
    }
    result = io_done(e, rows);
#else
    result = io_fail(e, SQLITE_MISUSE, sqlite3_errstr(SQLITE_MISUSE));
#endif
  }
  jb_sql_free(p);
  return result;
}

static JbSqlCall* jb_sql_new(IoWork* w, int operation) {
  JbSqlCall* p = io_mem(calloc(1, sizeof(JbSqlCall)));
  p->slot = -1;
  p->operation = operation;
  w->data = (char*)p;
  return p;
}

static void jb_sql_borrow(JbSqlCall* p, u32 token) {
  p->code = SQLITE_MISUSE;
  for (u32 i = 0; i < JB_SQL_HANDLES; ++i) {
    JbSqlHandle* h = &jb_sql_handles[i];
    if (token != 0 && h->token == token && h->db != NULL) {
      if (h->busy) { p->code = SQLITE_BUSY; return; }
      h->busy = true;
      p->slot = (int)i;
      p->db = h->db;
      p->code = SQLITE_OK;
      return;
    }
  }
}

#ifdef CID(open)
static Term jb_sql_open_run(Env e, Term* f, IoWork* w) {
  JbSqlCall* p = jb_sql_new(w, 0);
  p->text = jb_sql_bytes(e, f[0], true, &p->text_len, &p->code);
  if (p->text_len == 0 || io_nul(p->text, p->text_len)) p->code = SQLITE_MISUSE;
  if (jb_sql_next_token > UINT32_MAX) p->code = SQLITE_FULL;
  if (p->code == SQLITE_OK) {
    for (u32 i = 0; i < JB_SQL_HANDLES; ++i) {
      if (jb_sql_handles[i].db == NULL && !jb_sql_handles[i].busy) {
        p->slot = (int)i;
        p->token = (u32)jb_sql_next_token++;
        jb_sql_handles[i].busy = true;
        break;
      }
    }
    if (p->slot < 0) p->code = SQLITE_FULL;
  }
  return p->code ? jb_sql_pack(e, w) : io_work(w, jb_sql_call, jb_sql_pack);
}
static void __attribute__((constructor)) jb_sql_open_use(void) {
  io_eff(CID(open), jb_sql_open_run);
}
#endif

#ifdef CID(query)
static Term jb_sql_query_run(Env e, Term* f, IoWork* w) {
  JbSqlCall* p = jb_sql_new(w, 1);
  p->text = jb_sql_bytes(e, f[1], true, &p->text_len, &p->code);
  if (io_nul(p->text, p->text_len)) p->code = SQLITE_MISUSE;
  p->input_bytes = p->text_len;
  p->max_rows = (u32)f[3];
  if (p->max_rows > JB_SQL_ROWS) p->code = SQLITE_TOOBIG;
  Term xs = f[2];
  while (term_aux(xs) == CID(Con)) {
    Term pair[2], value[1];
    spare_free(e, cls_fit(2), ctr_take(e, xs, 2, pair));
    JbSqlCell cell = {0};
    u64 tag = term_aux(pair[0]);
    if (tag == CID(Cell.Null)) {
      cell.kind = SQLITE_NULL;
    } else {
      spare_free(e, cls_fit(1), ctr_take(e, pair[0], 1, value));
      cell.bytes = jb_sql_bytes(e, value[0], tag != CID(Cell.Blob), &cell.len, &p->code);
      if (cell.len > JB_SQL_BYTES - p->input_bytes) p->code = SQLITE_TOOBIG;
      else p->input_bytes += cell.len;
      if (tag == CID(Cell.Text)) cell.kind = SQLITE_TEXT;
      else if (tag == CID(Cell.Blob)) cell.kind = SQLITE_BLOB;
      else if (tag == CID(Cell.Integer)) {
        cell.kind = SQLITE_INTEGER;
        if (!jb_sql_i64(cell.bytes, cell.len, &cell.integer)) p->code = SQLITE_MISMATCH;
      } else {
        cell.kind = SQLITE_FLOAT;
        if (!jb_sql_real(cell.bytes, cell.len, &cell.real)) p->code = SQLITE_MISMATCH;
      }
    }
    if (p->bindings == JB_SQL_BINDINGS || p->code != SQLITE_OK) {
      if (p->bindings == JB_SQL_BINDINGS) p->code = SQLITE_TOOBIG;
      free(cell.bytes);
    } else {
      p->args = io_mem(realloc(p->args, (p->bindings + 1) * sizeof(JbSqlCell)));
      p->args[p->bindings++] = cell;
    }
    xs = pair[1];
  }
  if (p->code == SQLITE_OK) jb_sql_borrow(p, (u32)f[0]);
  return p->code ? jb_sql_pack(e, w) : io_work(w, jb_sql_call, jb_sql_pack);
}
static void __attribute__((constructor)) jb_sql_query_use(void) {
  io_eff(CID(query), jb_sql_query_run);
}
#endif

#ifdef CID(close)
static Term jb_sql_close_run(Env e, Term* f, IoWork* w) {
  JbSqlCall* p = jb_sql_new(w, 2);
  jb_sql_borrow(p, (u32)f[0]);
  return p->code ? jb_sql_pack(e, w) : io_work(w, jb_sql_call, jb_sql_pack);
}
static void __attribute__((constructor)) jb_sql_close_use(void) {
  io_eff(CID(close), jb_sql_close_run);
}
#endif
