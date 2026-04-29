# -*- coding: utf-8 -*-
import os, io, csv, json, time, zipfile, socket, logging
from pathlib import Path
from functools import wraps
from flask import Flask, request, jsonify, send_file, send_from_directory, make_response
from flask_cors import CORS
import database as db

BASE_DIR    = Path(__file__).parent
UPLOADS_DIR = BASE_DIR / 'uploads'
WEB_DIR     = BASE_DIR / 'web'
UPLOADS_DIR.mkdir(exist_ok=True)

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
app = Flask(__name__)
CORS(app)

SERVER_PASSWORD = os.environ.get('IHSAA_PASSWORD', '1234')
db.init_db()

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        pw = request.headers.get('x-password') or request.args.get('password') or ''
        if pw != SERVER_PASSWORD:
            return jsonify({'ok': False, 'error': 'غير مصرح'}), 401
        return f(*args, **kwargs)
    return decorated

# ── Flutter Web ──────────────────────────────────────────────────────────────
@app.route('/', defaults={'path': ''})
@app.route('/app', defaults={'path': ''})
@app.route('/app/<path:path>')
def serve_web(path=''):
    if WEB_DIR.exists():
        target = WEB_DIR / path
        if path and target.exists() and target.is_file():
            return send_from_directory(str(WEB_DIR), path)
        idx = WEB_DIR / 'index.html'
        if idx.exists():
            return send_from_directory(str(WEB_DIR), 'index.html')
    return jsonify({'error': 'Flutter Web غير مبني'}), 404

# ── Auth ─────────────────────────────────────────────────────────────────────
@app.route('/api/ping')
def ping(): return jsonify({'ok': True})

@app.route('/api/auth', methods=['POST'])
def auth():
    body = request.get_json(force=True) or {}
    if body.get('password') == SERVER_PASSWORD:
        return jsonify({'ok': True})
    return jsonify({'ok': False}), 403

# ── Beneficiaries ────────────────────────────────────────────────────────────
@app.route('/api/beneficiaries')
@require_auth
def get_list():
    done    = int(request.args.get('done', 0))
    query   = request.args.get('q', '')
    address = request.args.get('address') or None
    limit   = int(request.args.get('limit', 100))
    offset  = int(request.args.get('offset', 0))
    data    = db.search(done, query, address, limit, offset)
    return jsonify({'ok': True, 'data': data, 'count': len(data)})

@app.route('/api/beneficiaries/<int:rid>')
@require_auth
def get_one(rid):
    row = db.get_by_id(rid)
    return jsonify({'ok': True, 'data': row}) if row else (jsonify({'ok': False}), 404)

@app.route('/api/beneficiaries', methods=['POST'])
@require_auth
def create_one():
    rid = db.insert_one(request.get_json(force=True) or {})
    return jsonify({'ok': True, 'id': rid}), 201

@app.route('/api/beneficiaries/batch', methods=['POST'])
@require_auth
def create_many():
    count = db.insert_many(request.get_json(force=True) or [])
    return jsonify({'ok': True, 'inserted': count})

@app.route('/api/beneficiaries/<int:rid>', methods=['PUT'])
@require_auth
def update_one(rid):
    db.update_one(rid, request.get_json(force=True) or {})
    return jsonify({'ok': True})

@app.route('/api/beneficiaries/<int:rid>', methods=['DELETE'])
@require_auth
def delete_one(rid):
    db.delete_one(rid)
    return jsonify({'ok': True})

# ── Filters ──────────────────────────────────────────────────────────────────
@app.route('/api/addresses')
@require_auth
def addresses(): return jsonify({'ok': True, 'data': db.get_addresses()})

@app.route('/api/programs')
@require_auth
def programs(): return jsonify({'ok': True, 'data': db.get_programs()})

# ── Stats ─────────────────────────────────────────────────────────────────────
@app.route('/api/stats/dashboard')
@require_auth
def dashboard(): return jsonify({'ok': True, 'data': db.dashboard_stats()})

@app.route('/api/stats/advanced')
@require_auth
def advanced(): return jsonify({'ok': True, 'data': db.advanced_stats()})

@app.route('/api/stats/report/<program>')
@require_auth
def report(program): return jsonify({'ok': True, 'data': db.report_stats(program)})

# ── Images ────────────────────────────────────────────────────────────────────
@app.route('/api/images/list')
@require_auth
def images_list():
    files = [f.name for f in UPLOADS_DIR.iterdir()
             if f.suffix.lower() in ('.jpg','.jpeg','.png')]
    return jsonify({'ok': True, 'filenames': files})

@app.route('/api/images/<name>', methods=['POST'])
@require_auth
def upload_image(name):
    data = request.get_data()
    if not data: return jsonify({'ok': False}), 400
    (UPLOADS_DIR / name).write_bytes(data)
    return jsonify({'ok': True})

@app.route('/api/images/<name>')
@require_auth
def get_image(name):
    p = UPLOADS_DIR / name
    if not p.exists(): return jsonify({'error': 'غير موجود'}), 404
    return send_file(str(p), mimetype='image/png' if name.endswith('.png') else 'image/jpeg')

@app.route('/api/images/zip/<program>')
@require_auth
def images_zip(program):
    images = db.get_program_images(program, str(UPLOADS_DIR))
    if not images: return jsonify({'error': 'لا توجد صور'}), 404
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
        for img in images:
            zf.write(img['path'], img['name'])
    buf.seek(0)
    return send_file(buf, mimetype='application/zip', as_attachment=True,
                     download_name=f'صور_{program}.zip')

# ── Sync (mobile agents) ──────────────────────────────────────────────────────
@app.route('/api/sync', methods=['POST'])
@require_auth
def sync():
    body     = request.get_json(force=True) or {}
    incoming = body.get('records', [])
    stats    = db.merge_records(incoming)
    all_rec  = db.get_all()
    return jsonify({'ok': True, 'records': all_rec, 'stats': stats})

# ── Export CSV ────────────────────────────────────────────────────────────────
@app.route('/api/export/csv')
@require_auth
def export_csv():
    rows = db.get_all()
    if not rows: return jsonify({'error': 'لا بيانات'}), 404
    out = io.StringIO()
    w = csv.DictWriter(out, fieldnames=rows[0].keys())
    w.writeheader(); w.writerows(rows)
    resp = make_response(out.getvalue().encode('utf-8-sig'))
    resp.headers['Content-Type']        = 'text/csv; charset=utf-8'
    resp.headers['Content-Disposition'] = 'attachment; filename=ihsaa_2026.csv'
    return resp

@app.route('/api/export/stats/csv')
@require_auth
def export_stats_csv():
    s   = db.advanced_stats()
    t   = s['totals']
    out = io.StringIO()
    out.write('=== الإجمالي العام ===\n')
    for k in ('total','done','with_image','without_image','elec','gas','water','sewage'):
        out.write(f"{k},{t.get(k,'')}\n")
    out.write('\n=== حسب البرنامج ===\n')
    cols = ['program','total','done','s1','s2','s3','s4','elec','gas','water','sewage','with_image']
    out.write(','.join(cols)+'\n')
    for r in s['byProgram']:
        out.write(','.join(str(r.get(c,'')) for c in cols)+'\n')
    out.write('\n=== حسب الحالة ===\n')
    cols2 = ['status','total','elec','gas','water','sewage','all_four','none','with_image']
    out.write(','.join(cols2)+'\n')
    for r in s['byStatus']:
        out.write(','.join(str(r.get(c,'')) for c in cols2)+'\n')
    resp = make_response(out.getvalue().encode('utf-8-sig'))
    resp.headers['Content-Type']        = 'text/csv; charset=utf-8'
    resp.headers['Content-Disposition'] = 'attachment; filename=stats_ihsaa.csv'
    return resp

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80)); ip = s.getsockname()[0]; s.close(); return ip
    except: return '127.0.0.1'

if __name__ == '__main__':
    ip   = get_local_ip()
    port = int(os.environ.get('PORT', 8080))
    print(f'\n✅ السيرفر: http://{ip}:{port}  |  كلمة المرور: {SERVER_PASSWORD}\n')
    app.run(host='0.0.0.0', port=port, debug=False, threaded=True)
