# -*- coding: utf-8 -*-
"""
مشغّل سيرفر إحصاء 2026 — Windows 7
نقرة مزدوجة → نافذة بسيطة → تشغيل السيرفر
"""
import sys, os, socket, threading, subprocess, webbrowser
import tkinter as tk
from tkinter import font as tkfont

BASE  = os.path.dirname(os.path.abspath(__file__))
PORT  = 8080

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return '127.0.0.1'

class Launcher(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('إحصاء السكن الريفي 2026')
        self.geometry('380x300')
        self.resizable(False, False)
        self.configure(bg='#0D47A1')
        self.protocol('WM_DELETE_WINDOW', self._on_close)
        self._proc   = None
        self._running= False
        self._build_ui()

    def _build_ui(self):
        bold = tkfont.Font(family='Arial', size=13, weight='bold')
        sm   = tkfont.Font(family='Arial', size=10)

        tk.Label(self, text='🏠 إحصاء السكن الريفي 2026',
                 bg='#0D47A1', fg='white', font=bold).pack(pady=(18,2))
        tk.Label(self, text='نسيم — الحوضان',
                 bg='#0D47A1', fg='#90CAF9', font=sm).pack()

        frm = tk.Frame(self, bg='white', bd=0)
        frm.pack(fill='x', padx=20, pady=16)

        self._status_dot  = tk.Label(frm, text='⬤', fg='#EF5350',
                                     bg='white', font=tkfont.Font(size=14))
        self._status_dot.pack(side='left', padx=10, pady=10)

        self._status_lbl  = tk.Label(frm, text='السيرفر متوقف',
                                     bg='white', font=sm, anchor='w')
        self._status_lbl.pack(side='left', expand=True, fill='x')

        self._ip_lbl = tk.Label(self, text='', bg='#0D47A1',
                                fg='#B3E5FC', font=sm)
        self._ip_lbl.pack()

        btn_frm = tk.Frame(self, bg='#0D47A1')
        btn_frm.pack(pady=14)

        self._btn_toggle = tk.Button(
            btn_frm, text='▶  تشغيل', width=14, height=2,
            bg='#43A047', fg='white', font=bold, relief='flat',
            cursor='hand2', command=self._toggle)
        self._btn_toggle.pack(side='left', padx=6)

        self._btn_open = tk.Button(
            btn_frm, text='🌐  فتح المتصفح', width=14, height=2,
            bg='#1565C0', fg='white', font=sm, relief='flat',
            cursor='hand2', state='disabled', command=self._open_browser)
        self._btn_open.pack(side='left', padx=6)

        tk.Label(self, text='اضغط "تشغيل" ثم افتح المتصفح على الأجهزة الأخرى',
                 bg='#0D47A1', fg='#90CAF9',
                 font=tkfont.Font(family='Arial', size=9)).pack(pady=(0,10))

    def _toggle(self):
        if self._running:
            self._stop()
        else:
            self._start()

    def _start(self):
        app_py = os.path.join(BASE, 'app.py')
        if not os.path.exists(app_py):
            self._set_status('❌ app.py غير موجود', '#EF5350')
            return
        try:
            self._proc = subprocess.Popen(
                [sys.executable, app_py],
                cwd=BASE,
                creationflags=subprocess.CREATE_NO_WINDOW
                if hasattr(subprocess,'CREATE_NO_WINDOW') else 0
            )
            self._running = True
            ip = get_local_ip()
            self._set_status(f'يعمل  — المنفذ {PORT}', '#66BB6A')
            self._ip_lbl.config(
                text=f'الكمبيوتر: http://localhost:{PORT}\n'
                     f'الهواتف: http://{ip}:{PORT}')
            self._btn_toggle.config(text='■  إيقاف', bg='#E53935')
            self._btn_open.config(state='normal')
        except Exception as e:
            self._set_status(f'خطأ: {e}', '#EF5350')

    def _stop(self):
        if self._proc:
            self._proc.terminate()
            self._proc = None
        self._running = False
        self._set_status('السيرفر متوقف', '#EF5350')
        self._ip_lbl.config(text='')
        self._btn_toggle.config(text='▶  تشغيل', bg='#43A047')
        self._btn_open.config(state='disabled')

    def _open_browser(self):
        webbrowser.open(f'http://localhost:{PORT}')

    def _set_status(self, msg, color):
        self._status_dot.config(fg=color)
        self._status_lbl.config(text=msg)

    def _on_close(self):
        self._stop()
        self.destroy()

if __name__ == '__main__':
    Launcher().mainloop()
