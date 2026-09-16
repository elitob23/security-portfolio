"""
Name:         Simple TCP Port Scanner
Purpose:      Check which TCP ports are open on a host you are authorized to test
Inputs:       Target hostname or IP address, optional start and end port
Outputs:      Console output listing open ports and their common service names
Requirements: Python 3.10+, standard library only (no third-party packages)
Usage:        python3 portscanner.py 127.0.0.1 1 1024
Status:       Draft
"""

import socket
import sys
from concurrent.futures import ThreadPoolExecutor

# Make sure the user gave us a target
if len(sys.argv) < 2:
    print("Usage: python3 portscanner.py <target> [start_port] [end_port]")
    sys.exit(1)

target = sys.argv[1]

# Default to ports 1-1024 unless the user picks their own
start_port = 1
end_port = 1024
if len(sys.argv) >= 3:
    start_port = int(sys.argv[2])
    end_port = start_port
if len(sys.argv) >= 4:
    end_port = int(sys.argv[3])

if start_port < 1 or end_port > 65535 or start_port > end_port:
    print("Ports must be between 1 and 65535, and start must be less than end")
    sys.exit(1)

# Turn a hostname like "localhost" into an IP address
try:
    ip = socket.gethostbyname(target)
except socket.gaierror:
    print("Could not find host:", target)
    sys.exit(1)

open_ports = []


def scan_port(port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(0.5)
    result = sock.connect_ex((ip, port))
    sock.close()
    if result == 0:
        open_ports.append(port)


print(f"Scanning {target} ({ip}) ports {start_port}-{end_port}...")

# Check 100 ports at a time so the scan is fast
with ThreadPoolExecutor(max_workers=100) as pool:
    pool.map(scan_port, range(start_port, end_port + 1))

if len(open_ports) == 0:
    print("No open ports found")

for port in sorted(open_ports):
    try:
        service = socket.getservbyport(port, "tcp")
    except OSError:
        service = "unknown"
    print(f"Port {port} is open ({service})")

print("Scan complete")
