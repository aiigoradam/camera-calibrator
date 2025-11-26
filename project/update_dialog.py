#!/usr/bin/env python3
"""Update notification dialog using tkinter."""

import tkinter as tk
from tkinter import scrolledtext


class UpdateDialog:
    def __init__(self, update_info):
        self.update_info = update_info
        self.user_choice = None
        self._closed = False

        self.root = tk.Tk()
        self.root.title("Update Available")
        self.root.geometry("550x450")
        self.root.resizable(False, False)

        self.root.update_idletasks()
        x = (self.root.winfo_screenwidth() // 2) - (550 // 2)
        y = (self.root.winfo_screenheight() // 2) - (450 // 2)
        self.root.geometry(f"550x450+{x}+{y}")

        self.root.attributes("-topmost", True)
        self.root.focus_force()

        self._create_widgets()
        self.root.protocol("WM_DELETE_WINDOW", self._on_reject)

    def _create_widgets(self):
        title_frame = tk.Frame(self.root)
        title_frame.pack(fill=tk.X, padx=10, pady=10)

        title_label = tk.Label(title_frame, text="Update Available", font=("Arial", 16, "bold"))
        title_label.pack()

        version_frame = tk.Frame(self.root)
        version_frame.pack(fill=tk.X, padx=10, pady=5)

        current_label = tk.Label(
            version_frame, text=f"Current: {self.update_info.get('current_version', 'Unknown')}", font=("Arial", 10)
        )
        current_label.pack(side=tk.LEFT)

        latest_label = tk.Label(
            version_frame,
            text=f"Latest: {self.update_info.get('latest_version', 'Unknown')}",
            font=("Arial", 10, "bold"),
            fg="green",
        )
        latest_label.pack(side=tk.LEFT, padx=20)

        notes_label = tk.Label(self.root, text="Release Notes:", font=("Arial", 10, "bold"))
        notes_label.pack(anchor=tk.W, padx=10, pady=(10, 5))

        notes_text = scrolledtext.ScrolledText(self.root, height=12, wrap=tk.WORD, state=tk.DISABLED)
        notes_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)

        notes_text.config(state=tk.NORMAL)
        notes = self.update_info.get("release_notes", "No release notes available.")
        notes_text.insert("1.0", notes)
        notes_text.config(state=tk.DISABLED)

        button_frame = tk.Frame(self.root)
        button_frame.pack(fill=tk.X, padx=10, pady=10)

        reject_btn = tk.Button(button_frame, text="Skip This Update", command=self._on_reject, width=15, bg="#f0f0f0")
        reject_btn.pack(side=tk.RIGHT, padx=5)

        accept_btn = tk.Button(
            button_frame,
            text="Update Now",
            command=self._on_accept,
            width=15,
            bg="#4CAF50",
            fg="white",
            font=("Arial", 10, "bold"),
        )
        accept_btn.pack(side=tk.RIGHT, padx=5)

    def _on_accept(self):
        """User accepted the update."""
        if self._closed:
            return
        self._closed = True
        self.user_choice = "accept"
        self.root.quit()
        self.root.destroy()

    def _on_reject(self):
        """User rejected the update."""
        if self._closed:
            return
        self._closed = True
        self.user_choice = "reject"
        self.root.quit()
        self.root.destroy()

    def show(self):
        """Show dialog and return user choice."""
        self.root.mainloop()
        return {"choice": self.user_choice}
