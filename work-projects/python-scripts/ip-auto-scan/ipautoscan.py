"""
Name:         AbuseIPDB IP Reputation Lookup
Purpose:      Check an IP address against AbuseIPDB during triage, without
              leaving the console or pasting it into a browser
Inputs:       An IPv4 or IPv6 address typed into the window
Outputs:      Abuse confidence score, report count, country, ISP, whitelist
              status and last report date, printed to the window
Requirements: Python 3.10+, requests, an AbuseIPDB API key in the
              ABUSEIPDB_API_KEY environment variable
Usage:        python ipautoscan.py
Status:       Draft
"""

import ipaddress
import json
import os
import requests
import tkinter as tk
from threading import Thread
from tkinter import scrolledtext

API_KEY = os.environ.get('ABUSEIPDB_API_KEY', 'your_API_here')

def scan_ip(ip):
    url = 'https://api.abuseipdb.com/api/v2/check'
    headers = {
        "Key": API_KEY,
        "Accept": "application/json"
    }
    params = {
        "ipAddress": ip,
        "maxAgeInDays": 90
    }
    response = requests.get(url, headers=headers, params=params, timeout=15)
    return response.json()

def update_text(text_widget, text):
    text_widget.config(state=tk.NORMAL)
    text_widget.insert(tk.END, text + '\n')
    text_widget.config(state=tk.DISABLED)
    # Auto scroll to the end
    text_widget.see(tk.END)

def post(text_widget, text):
    # Worker threads must not touch widgets directly, so hand the update
    # back to the main loop.
    text_widget.after(0, update_text, text_widget, text)

def run_scan(text_widget, ip, on_done):
    try:
        result = scan_ip(ip)
        # The API reports bad keys, bad input and quota limits in "errors"
        # rather than by raising, so surface those instead of empty fields.
        errors = result.get("errors")
        if errors:
            for error in errors:
                post(text_widget, f"Error {error.get('status', '')}: {error.get('detail', error)}")
        else:
            data = result.get("data", {})
            # Filter the result to only show relevant information
            filtered_result = {
                "IP": data.get("ipAddress"),
                "Abuse Confidence Score": data.get("abuseConfidenceScore"),
                "Total Reports": data.get("totalReports"),
                "Country": data.get("countryCode"),
                "ISP": data.get("isp"),
                "Is Whitelisted": data.get("isWhitelisted"),
                "Last Reported At": data.get("lastReportedAt"),
            }
            post(text_widget, json.dumps(filtered_result, indent=4))
    except Exception as e:
        post(text_widget, f"Error: {e}")
    finally:
        text_widget.after(0, on_done)

def submit(entry, button, text_widget):
    ip = entry.get().strip()
    if not ip:
        return
    try:
        ipaddress.ip_address(ip)
    except ValueError:
        update_text(text_widget, f"Error: '{ip}' is not a valid IPv4 or IPv6 address.")
        return

    button.config(state=tk.DISABLED)
    update_text(text_widget, f"> scanning {ip} ...")
    entry.delete(0, tk.END)

    def on_done():
        button.config(state=tk.NORMAL)
        entry.focus_set()

    Thread(target=run_scan, args=(text_widget, ip, on_done), daemon=True).start()

if __name__ == "__main__":
    root = tk.Tk()
    root.title("IP Scanner (AbuseIPDB)")
    root.geometry("500x500")

    bar = tk.Frame(root)
    bar.pack(fill=tk.X, padx=5, pady=5)
    tk.Label(bar, text="IP:").pack(side=tk.LEFT)
    entry = tk.Entry(bar, font=("Courier", 10))
    entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=5)
    button = tk.Button(bar, text="Scan")
    button.pack(side=tk.LEFT)

    text = scrolledtext.ScrolledText(root, bg='black', fg='light green', font=("Courier", 10))
    text.pack(fill=tk.BOTH, expand=True)
    text.config(state=tk.DISABLED)

    button.config(command=lambda: submit(entry, button, text))
    entry.bind("<Return>", lambda event: submit(entry, button, text))
    entry.focus_set()

    root.mainloop()
