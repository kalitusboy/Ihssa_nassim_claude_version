# -*- coding: utf-8 -*-
"""
database.py — نفس منطق database_service.dart تماماً
القاعدة الذهبية: done=1 لا يُمحى أبداً
"""
import sqlite3
import os
import time
import json
from pathlib import Path

DB_PATH = os.path.join(os.path.dirname(__file__), 'ihsaa_2026.db')
TABLE   = 'beneficiaries'


def get_conn():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA cache_size=-32000")
    conn.execute("PRAGMA temp_store=MEMORY")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    """إنشاء الجدول والـ indexes عند أول تشغيل"""
    conn = get_conn()
    conn.execute(f'''
        CREATE TABLE IF NOT EXISTS {TABLE} (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            first_name      TEXT NOT NULL,
            last_name       TEXT NOT NULL,
            full_name       TEXT,
            birth_date      TEXT,
            birth_place     TEXT,
            address         TEXT,
            program         TEXT DEFAULT "عام",
            done            INTEGER DEFAULT 0,
            electricity     INTEGER DEFAULT 0,
            gas             INTEGER DEFAULT 0,
            water           INTEGER DEFAULT 0,
            sewage          INTEGER DEFAULT 0,
            status          TEXT DEFAULT "في طور الانجاز",
            image_path      TEXT,
            image_file_name TEXT,
            created_at      INTEGER,
            updated_at      INTEGER
        )
    ''')
    indexes = [
        f'CREATE INDEX IF NOT EXISTS idx_done           ON {TABLE}(done)',
        f'CREATE INDEX IF NOT EXISTS idx_program        ON {TABLE}(program)',
        f'CREATE INDEX IF NOT EXISTS idx_status         ON {TABLE}(status)',
        f'CREATE INDEX IF NOT EXISTS idx_address        ON {TABLE}(address)',
        f'CREATE INDEX IF NOT EXISTS idx_done_status    ON {TABLE}(done, status)',
        f'CREATE INDEX IF NOT EXISTS idx_done_program   ON {TABLE}(done, program)',
        f'CREATE INDEX IF NOT EXISTS idx_image          ON {TABLE}(image_file_name)',
        f'CREATE INDEX IF NOT EXISTS idx_first_name     ON {TABLE}(first_name COLLATE NOCASE)',
        f'CREATE INDEX IF NOT EXISTS idx_last_name      ON {TABLE}(last_name  COLLATE NOCASE)',
        f'CREATE INDEX IF NOT EXISTS idx_full_name      ON {TABLE}(full_name  COLLATE NOCASE)',
        f'CREATE INDEX IF NOT EXISTS idx_done_address   ON {TABLE}(done, address)',
        f'CREATE INDEX IF NOT EXISTS idx_done_updated   ON {TABLE}(done, updated_at DESC)',
        f'CREATE INDEX IF NOT EXISTS idx_lookup         ON {TABLE}(first_name, last_name, birth_date, address)',
    ]
    for sql in indexes:
        conn.execute(sql)
    conn.commit()
    conn.close()


def row_to_dict(row):
    return dict(row) if row else None


# ─────────────────────────────────────────────
# CRUD
# ─────────────────────────────────────────────

def get_all():
    conn = get_conn()
    rows = conn.execute(f'SELECT * FROM {TABLE} ORDER BY id DESC').fetchall()
    conn.close()
    return [dict(r) for r in rows]


def search(done_val, query='', address=None, limit=100, offset=0):
    conn   = get_conn()
    where  = ['done = ?']
    params = [done_val]

    if address:
        where.append('address = ?')
        params.append(address)

    q = query.strip()
    if q:
        like = f'{q}%'
        where.append('''(
            first_name LIKE ? COLLATE NOCASE OR
            last_name  LIKE ? COLLATE NOCASE OR
            full_name  LIKE ? COLLATE NOCASE OR
            address    LIKE ? COLLATE NOCASE OR
            program    LIKE ? COLLATE NOCASE
        )''')
        params.extend([like] * 5)

    order = 'updated_at DESC, id DESC' if done_val == 1 else 'id DESC'
    sql   = f"SELECT * FROM {TABLE} WHERE {' AND '.join(where)} ORDER BY {order} LIMIT ? OFFSET ?"
    params += [limit, offset]

    rows = conn.execute(sql, params).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_by_id(rid):
    conn = get_conn()
    row  = conn.execute(f'SELECT * FROM {TABLE} WHERE id=?', [rid]).fetchone()
    conn.close()
    return dict(row) if row else None


def insert_one(data):
    now = int(time.time() * 1000)
    data = {k: v for k, v in data.items() if k != 'id'}
    data['created_at'] = now
    data['updated_at'] = now
    conn = get_conn()
    keys = ', '.join(data.keys())
    vals = ', '.join(['?'] * len(data))
    cur  = conn.execute(f'INSERT INTO {TABLE} ({keys}) VALUES ({vals})', list(data.values()))
    conn.commit()
    rid = cur.lastrowid
    conn.close()
    return rid


def insert_many(records):
    if not records:
        return 0
    now  = int(time.time() * 1000)
    conn = get_conn()
    count = 0
    for data in records:
        data = {k: v for k, v in data.items() if k != 'id'}
        data['created_at'] = now
        data['updated_at'] = now
        keys = ', '.join(data.keys())
        vals = ', '.join(['?'] * len(data))
        conn.execute(f'INSERT INTO {TABLE} ({keys}) VALUES ({vals})', list(data.values()))
        count += 1
    conn.commit()
    conn.close()
    return count


def update_one(rid, data):
    data = {k: v for k, v in data.items() if k not in ('id', 'created_at')}
    data['updated_at'] = int(time.time() * 1000)
    conn  = get_conn()
    sets  = ', '.join([f'{k}=?' for k in data.keys()])
    conn.execute(f'UPDATE {TABLE} SET {sets} WHERE id=?', list(data.values()) + [rid])
    conn.commit()
    conn.close()


def delete_one(rid):
    conn = get_conn()
    row  = conn.execute(f'SELECT image_path FROM {TABLE} WHERE id=?', [rid]).fetchone()
    if row and row['image_path']:
        try:
            os.remove(row['image_path'])
        except Exception:
            pass
    conn.execute(f'DELETE FROM {TABLE} WHERE id=?', [rid])
    conn.commit()
    conn.close()


def get_addresses():
    conn = get_conn()
    rows = conn.execute(f'''
        SELECT DISTINCT address FROM {TABLE}
        WHERE address IS NOT NULL AND TRIM(address) != ""
        ORDER BY address COLLATE NOCASE
    ''').fetchall()
    conn.close()
    return [r['address'] for r in rows if r['address']]


def get_programs():
    conn = get_conn()
    rows = conn.execute(f'''
        SELECT program, MIN(created_at) AS first_added
        FROM {TABLE}
        WHERE program IS NOT NULL AND program != ""
        GROUP BY program ORDER BY first_added ASC
    ''').fetchall()
    conn.close()
    return [r['program'] for r in rows]


# ─────────────────────────────────────────────
# STATISTICS — نفس SQL من database_service.dart
# ─────────────────────────────────────────────

def dashboard_stats():
    conn = get_conn()
    row  = conn.execute(f'''
        SELECT
            COUNT(*)                                                        AS total,
            SUM(CASE WHEN done=1 THEN 1 ELSE 0 END)                        AS done,
            SUM(CASE WHEN done=0 THEN 1 ELSE 0 END)                        AS pending,
            SUM(CASE WHEN done=1 AND image_file_name IS NOT NULL
                     AND image_file_name != "" THEN 1 ELSE 0 END)          AS with_image,
            SUM(CASE WHEN done=1 AND (image_file_name IS NULL
                     OR image_file_name="") THEN 1 ELSE 0 END)             AS without_image,
            SUM(CASE WHEN done=1 AND status="منتهية ومشغولة"
                     THEN 1 ELSE 0 END)                                    AS occupied
        FROM {TABLE}
    ''').fetchone()
    conn.close()
    return dict(row)


def advanced_stats():
    conn = get_conn()

    totals = dict(conn.execute(f'''
        SELECT
            COUNT(*)                                                    AS total,
            SUM(CASE WHEN done=1 THEN 1 ELSE 0 END)                    AS done,
            SUM(CASE WHEN done=1 AND image_file_name IS NOT NULL
                     AND image_file_name != "" THEN 1 ELSE 0 END)      AS with_image,
            SUM(CASE WHEN done=1 AND (image_file_name IS NULL
                     OR image_file_name="") THEN 1 ELSE 0 END)         AS without_image,
            SUM(CASE WHEN done=1 AND electricity=1 THEN 1 ELSE 0 END)  AS elec,
            SUM(CASE WHEN done=1 AND gas=1         THEN 1 ELSE 0 END)  AS gas,
            SUM(CASE WHEN done=1 AND water=1       THEN 1 ELSE 0 END)  AS water,
            SUM(CASE WHEN done=1 AND sewage=1      THEN 1 ELSE 0 END)  AS sewage
        FROM {TABLE}
    ''').fetchone())

    by_program = [dict(r) for r in conn.execute(f'''
        SELECT
            program,
            COUNT(*)                                                                AS total,
            SUM(CASE WHEN done=1 THEN 1 ELSE 0 END)                                AS done,
            SUM(CASE WHEN done=1 AND status="في طور الانجاز"    THEN 1 ELSE 0 END)  AS s1,
            SUM(CASE WHEN done=1 AND status="على مستوى الاعمدة" THEN 1 ELSE 0 END)  AS s2,
            SUM(CASE WHEN done=1 AND status="منتهية غير مشغولة" THEN 1 ELSE 0 END)  AS s3,
            SUM(CASE WHEN done=1 AND status="منتهية ومشغولة"    THEN 1 ELSE 0 END)  AS s4,
            SUM(CASE WHEN done=1 AND electricity=1 THEN 1 ELSE 0 END)               AS elec,
            SUM(CASE WHEN done=1 AND gas=1         THEN 1 ELSE 0 END)               AS gas,
            SUM(CASE WHEN done=1 AND water=1       THEN 1 ELSE 0 END)               AS water,
            SUM(CASE WHEN done=1 AND sewage=1      THEN 1 ELSE 0 END)               AS sewage,
            SUM(CASE WHEN done=1 AND image_file_name IS NOT NULL
                     AND image_file_name != "" THEN 1 ELSE 0 END)                   AS with_image,
            MIN(created_at)                                                         AS first_added
        FROM {TABLE}
        WHERE program IS NOT NULL
        GROUP BY program
        ORDER BY first_added ASC
    ''').fetchall()]

    by_status = [dict(r) for r in conn.execute(f'''
        SELECT
            status,
            COUNT(*)                                                              AS total,
            SUM(CASE WHEN electricity=1 THEN 1 ELSE 0 END)                       AS elec,
            SUM(CASE WHEN gas=1         THEN 1 ELSE 0 END)                       AS gas,
            SUM(CASE WHEN water=1       THEN 1 ELSE 0 END)                       AS water,
            SUM(CASE WHEN sewage=1      THEN 1 ELSE 0 END)                       AS sewage,
            SUM(CASE WHEN electricity=1 AND gas=0 AND water=0 AND sewage=0
                     THEN 1 ELSE 0 END)                                           AS elec_only,
            SUM(CASE WHEN electricity=0 AND gas=1 AND water=0 AND sewage=0
                     THEN 1 ELSE 0 END)                                           AS gas_only,
            SUM(CASE WHEN electricity=0 AND gas=0 AND water=1 AND sewage=0
                     THEN 1 ELSE 0 END)                                           AS water_only,
            SUM(CASE WHEN electricity=0 AND gas=0 AND water=0 AND sewage=1
                     THEN 1 ELSE 0 END)                                           AS sewage_only,
            SUM(CASE WHEN electricity=1 AND gas=1 AND water=0 AND sewage=0
                     THEN 1 ELSE 0 END)                                           AS elec_gas,
            SUM(CASE WHEN electricity=1 AND gas=1 AND water=1 AND sewage=1
                     THEN 1 ELSE 0 END)                                           AS all_four,
            SUM(CASE WHEN electricity=0 AND gas=0 AND water=0 AND sewage=0
                     THEN 1 ELSE 0 END)                                           AS none,
            SUM(CASE WHEN image_file_name IS NOT NULL AND image_file_name != ""
                     THEN 1 ELSE 0 END)                                           AS with_image
        FROM {TABLE}
        WHERE done=1
        GROUP BY status
        ORDER BY CASE status
            WHEN "منتهية ومشغولة"    THEN 1
            WHEN "منتهية غير مشغولة" THEN 2
            WHEN "على مستوى الاعمدة" THEN 3
            ELSE 4 END
    ''').fetchall()]

    img_by_status = [dict(r) for r in conn.execute(f'''
        SELECT
            status,
            SUM(CASE WHEN image_file_name IS NOT NULL AND image_file_name != ""
                     THEN 1 ELSE 0 END) AS with_image,
            SUM(CASE WHEN image_file_name IS NULL OR image_file_name=""
                     THEN 1 ELSE 0 END) AS without_image
        FROM {TABLE}
        WHERE done=1
        GROUP BY status
    ''').fetchall()]

    conn.close()
    return {
        'totals': totals,
        'byProgram': by_program,
        'byStatus': by_status,
        'imageByStatus': img_by_status,
    }


def report_stats(program):
    conn = get_conn()
    general = dict(conn.execute(f'''
        SELECT
            COUNT(*)                                                                AS quota,
            SUM(CASE WHEN done=1 THEN 1 ELSE 0 END)                                AS done,
            SUM(CASE WHEN done=1 AND status="في طور الانجاز"    THEN 1 ELSE 0 END)  AS in_progress,
            SUM(CASE WHEN done=1 AND status="على مستوى الاعمدة" THEN 1 ELSE 0 END)  AS pillars,
            SUM(CASE WHEN done=1 AND status="منتهية غير مشغولة" THEN 1 ELSE 0 END)  AS finished_not_occupied,
            SUM(CASE WHEN done=1 AND status="منتهية ومشغولة"    THEN 1 ELSE 0 END)  AS finished_occupied
        FROM {TABLE} WHERE program=?
    ''', [program]).fetchone())

    networks = dict(conn.execute(f'''
        SELECT
            SUM(CASE WHEN electricity=1 THEN 1 ELSE 0 END) AS elec_occ,
            SUM(CASE WHEN gas=1         THEN 1 ELSE 0 END) AS gas_occ,
            SUM(CASE WHEN water=1       THEN 1 ELSE 0 END) AS water_occ,
            SUM(CASE WHEN sewage=1      THEN 1 ELSE 0 END) AS sew_occ,
            SUM(CASE WHEN electricity=1 AND gas=1 AND water=1 AND sewage=1
                     THEN 1 ELSE 0 END)                    AS fully_connected
        FROM {TABLE}
        WHERE program=? AND done=1 AND status="منتهية ومشغولة"
    ''', [program]).fetchone())

    conn.close()
    return {**general, **networks}


# ─────────────────────────────────────────────
# المزامنة — نفس منطق sync_service.dart
# القاعدة الذهبية: done=1 يفوز دائماً
# ─────────────────────────────────────────────

def _make_key(r):
    fn = (r.get('first_name') or '').strip().lower()
    ln = (r.get('last_name')  or '').strip().lower()
    bd = (r.get('birth_date') or '').strip()
    ad = (r.get('address')    or '').strip().lower()
    return f'{fn}|{ln}|{bd}|{ad}'


def merge_records(incoming):
    """
    يدمج السجلات الواردة مع القاعدة المحلية.
    القاعدة: done=1 لا يُكتب فوقه، الأحدث updated_at يفوز.
    """
    conn     = get_conn()
    local    = conn.execute(f'SELECT * FROM {TABLE}').fetchall()
    local_map = {_make_key(dict(r)): dict(r) for r in local}

    added = updated = 0

    for remote in incoming:
        key = _make_key(remote)
        if key not in local_map:
            # سجل جديد
            data = {k: v for k, v in remote.items() if k != 'id'}
            now  = int(time.time() * 1000)
            data.setdefault('created_at', now)
            data.setdefault('updated_at', now)
            keys = ', '.join(data.keys())
            vals = ', '.join(['?'] * len(data))
            conn.execute(f'INSERT INTO {TABLE} ({keys}) VALUES ({vals})',
                         list(data.values()))
            added += 1
        else:
            loc = local_map[key]
            # done=1 يفوز دائماً
            done = 1 if (loc.get('done') == 1 or remote.get('done') == 1) else 0
            # الأحدث updated_at يفوز
            loc_ts = loc.get('updated_at') or 0
            rem_ts = remote.get('updated_at') or 0
            winner = remote if rem_ts > loc_ts else loc
            data   = {k: v for k, v in winner.items() if k not in ('id', 'created_at')}
            data['done']       = done
            data['updated_at'] = int(time.time() * 1000)
            sets = ', '.join([f'{k}=?' for k in data.keys()])
            conn.execute(f'UPDATE {TABLE} SET {sets} WHERE id=?',
                         list(data.values()) + [loc['id']])
            updated += 1

    conn.commit()
    conn.close()
    return {'added': added, 'updated': updated}


def get_program_images(program, uploads_dir):
    conn = get_conn()
    rows = conn.execute(f'''
        SELECT image_file_name, image_path, first_name, last_name
        FROM {TABLE}
        WHERE program=? AND done=1
          AND image_file_name IS NOT NULL AND image_file_name != ""
    ''', [program]).fetchall()
    conn.close()
    result = []
    for r in rows:
        name = r['image_file_name'] or ''
        path = os.path.join(uploads_dir, name)
        if name and os.path.exists(path):
            result.append({'name': name, 'path': path,
                           'first_name': r['first_name'],
                           'last_name':  r['last_name']})
    return result
