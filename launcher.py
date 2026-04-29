# -*- coding: utf-8 -*-
"""
launcher.py — واجهة تشغيل السيرفر على Windows 7
نقرة واحدة → يشتغل كل شيء
"""
import tkinter as tk
from tkinter import ttk, messagebox
import subprocess
import threading
import socket
import sys
import os
import webbrowser
import time

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SERVER_DIR = os.path.join(BASE_DIR, 'server')
APP_PY = os.path.join(SERVER_DIR, 'app.py')

# ── إعدادات ──────────────────────────────────────────
DEFAULT_PORT = 8080
DEFAULT_PW   = '1234'

# ── تحديد Python ─────────────────────────────────────
def find_python():
    for py in ('python', 'python3', 'py'):
        try:
            r = subprocess.run([py, '--version'],
                               capture_output=True, text=True)
            if r.returncode == 0:
                return py
        except FileNotFoundError:
            continue
    return None

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return '127.0.0.1'


class LauncherApp:
    def __init__(self, root):
        self.root    = root
        self.process = None
        self.running = False
        self._build_ui()

    def _build_ui(self):
        self.root.title('إحصاء السكن الريفي 2026')
        self.root.geometry('400x500')
        self.root.resizable(False, False)
        self.root.configure(bg='#F1F5F9')

        # ── ترويسة ──────────────────────────────────
        hdr = tk.Frame(self.root, bg='#0D47A1', height=80)
        hdr.pack(fill='x')
        tk.Label(hdr, text='🏠 إحصاء السكن الريفي',
                 bg='#0D47A1', fg='white',
                 font=('Arial', 14, 'bold')).pack(pady=(14, 2))
        tk.Label(hdr, text='نسيم — الحوضان · 2026',
                 bg='#0D47A1', fg='#90CAF9',
                 font=('Arial', 10)).pack()

        body = tk.Frame(self.root, bg='#F1F5F9')
        body.pack(fill='both', expand=True, padx=20, pady=16)

        # ── كلمة المرور ─────────────────────────────
        tk.Label(body, text='كلمة المرور:', bg='#F1F5F9',
                 font=('Arial', 11, 'bold'),
                 anchor='e').pack(fill='x')
        pw_frame = tk.Frame(body, bg='#F1F5F9')
        pw_frame.pack(fill='x', pady=(4, 12))
        self.pw_var = tk.StringVar(value=DEFAULT_PW)
        self.pw_entry = tk.Entry(pw_frame, textvariable=self.pw_var,
                                  show='*', font=('Arial', 12),
                                  bd=1, relief='solid')
        self.pw_entry.pack(side='left', fill='x', expand=True, ipady=4)
        self.show_btn = tk.Button(pw_frame, text='👁',
                                   command=self._toggle_pw,
                                   bg='#E2E8F0', relief='flat',
                                   font=('Arial', 11), cursor='hand2')
        self.show_btn.pack(side='left', padx=(4, 0))

        # ── المنفذ ───────────────────────────────────
        tk.Label(body, text='المنفذ (Port):', bg='#F1F5F9',
                 font=('Arial', 11, 'bold'),
                 anchor='e').pack(fill='x')
        self.port_var = tk.StringVar(value=str(DEFAULT_PORT))
        tk.Entry(body, textvariable=self.port_var,
                 font=('Arial', 12), bd=1, relief='solid').pack(
            fill='x', pady=(4, 12), ipady=4)

        # ── حالة السيرفر ─────────────────────────────
        self.status_var = tk.StringVar(value='⏸ السيرفر متوقف')
        self.status_lbl = tk.Label(body, textvariable=self.status_var,
                                    bg='#FEF3C7', fg='#92400E',
                                    font=('Arial', 11, 'bold'),
                                    relief='solid', bd=1, pady=8)
        self.status_lbl.pack(fill='x', pady=(0, 12))

        # ── IP ───────────────────────────────────────
        ip = get_local_ip()
        self.ip_var = tk.StringVar(value=f'العنوان: {ip}:{DEFAULT_PORT}')
        tk.Label(body, textvariable=self.ip_var,
                 bg='#F1F5F9', fg='#475569',
                 font=('Courier', 10)).pack()

        # ── أزرار ────────────────────────────────────
        btn_frame = tk.Frame(body, bg='#F1F5F9')
        btn_frame.pack(fill='x', pady=14)

        self.start_btn = tk.Button(
            btn_frame, text='▶  تشغيل السيرفر',
            command=self._start,
            bg='#0D47A1', fg='white',
            font=('Arial', 12, 'bold'),
            relief='flat', cursor='hand2', pady=10)
        self.start_btn.pack(fill='x', pady=(0, 8))

        self.stop_btn = tk.Button(
            btn_frame, text='■  إيقاف السيرفر',
            command=self._stop,
            bg='#DC2626', fg='white',
            font=('Arial', 12, 'bold'),
            relief='flat', cursor='hand2', pady=10,
            state='disabled')
        self.stop_btn.pack(fill='x', pady=(0, 8))

        self.open_btn = tk.Button(
            btn_frame, text='🌐  فتح في المتصفح',
            command=self._open_browser,
            bg='#059669', fg='white',
            font=('Arial', 12, 'bold'),
            relief='flat', cursor='hand2', pady=10,
            state='disabled')
        self.open_btn.pack(fill='x')

        # ── سجل الأحداث ──────────────────────────────
        tk.Label(body, text='السجل:', bg='#F1F5F9',
                 font=('Arial', 9), anchor='w').pack(fill='x', pady=(12, 2))
        self.log = tk.Text(body, height=5, font=('Courier', 8),
                           bg='#1E293B', fg='#94A3B8',
                           state='disabled', bd=1, relief='solid')
        self.log.pack(fill='x')

        self.root.protocol('WM_DELETE_WINDOW', self._on_close)

    def _toggle_pw(self):
        cur = self.pw_entry.cget('show')
        self.pw_entry.config(show='' if cur == '*' else '*')

    def _log(self, msg):
        self.log.config(state='normal')
        self.log.insert('end', f'{time.strftime("%H:%M:%S")} {msg}\n')
        self.log.see('end')
        self.log.config(state='disabled')

    def _start(self):
        py = find_python()
        if not py:
            messagebox.showerror('خطأ', 'Python غير مثبت!\nحمّله من python.org')
            return

        port = self.port_var.get().strip()
        pw   = self.pw_var.get().strip()
        if not port.isdigit():
            messagebox.showerror('خطأ', 'المنفذ يجب أن يكون رقماً')
            return
        if len(pw) < 4:
            messagebox.showerror('خطأ', 'كلمة المرور 4 أحرف على الأقل')
            return

        env = os.environ.copy()
        env['IHSAA_PASSWORD'] = pw
        env['PORT']           = port

        try:
            self.process = subprocess.Popen(
                [py, APP_PY],
                env=env, cwd=SERVER_DIR,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                creationflags=subprocess.CREATE_NO_WINDOW
                if sys.platform == 'win32' else 0
            )
            self.running = True

            # قراءة الـ output في thread منفصل
            threading.Thread(target=self._read_output,
                             daemon=True).start()

            ip = get_local_ip()
            self.ip_var.set(f'العنوان: {ip}:{port}')
            self._set_running(True)
            self._log(f'✅ السيرفر يعمل على {ip}:{port}')
        except Exception as e:
            self._log(f'❌ {e}')
            messagebox.showerror('خطأ', str(e))

    def _read_output(self):
        for line in self.process.stdout:
            line = line.strip()
            if line:
                self.root.after(0, self._log, line)
        self.root.after(0, self._set_running, False)

    def _stop(self):
        if self.process:
            self.process.terminate()
            self.process = None
        self.running = False
        self._set_running(False)
        self._log('■ السيرفر متوقف')

    def _set_running(self, is_running):
        self.running = is_running
        if is_running:
            self.status_var.set('🟢 السيرفر يعمل')
            self.status_lbl.config(bg='#D1FAE5', fg='#065F46')
            self.start_btn.config(state='disabled')
            self.stop_btn.config(state='normal')
            self.open_btn.config(state='normal')
        else:
            self.status_var.set('⏸ السيرفر متوقف')
            self.status_lbl.config(bg='#FEF3C7', fg='#92400E')
            self.start_btn.config(state='normal')
            self.stop_btn.config(state='disabled')
            self.open_btn.config(state='disabled')

    def _open_browser(self):
        port = self.port_var.get().strip()
        webbrowser.open(f'http://localhost:{port}')

    def _on_close(self):
        if self.running:
            if messagebox.askyesno('إغلاق',
                                    'السيرفر يعمل. هل تريد إيقافه والخروج؟'):
                self._stop()
                self.root.destroy()
        else:
            self.root.destroy()


def main():
    root = tk.Tk()
    LauncherApp(root)
    root.mainloop()


if __name__ == '__main__':
    main()
