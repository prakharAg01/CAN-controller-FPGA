#!/usr/bin/env python3
"""
=============================================================================
 Project    : Classical CAN 2.0A Protocol Controller on Artix-7 FPGA
 Module     : can_dashboard.py (Week 6, Day 39)
 Description: PC-Side CAN Bus Analyzer, Interactive Controller & Live Demo Tool
              Interfaces with Nexys 4 DDR USB-UART Gateway at 115,200 baud.
=============================================================================
"""

import sys
import time
import threading
import csv
import os
from datetime import datetime

try:
    import serial
    import serial.tools.list_ports as list_ports
except ImportError:
    print("\n[ERROR] 'pyserial' is not installed.")
    print("Please run: pip install pyserial\n")
    sys.exit(1)

# ANSI Terminal Colors
class Colors:
    RESET   = "\033[0m"
    BOLD    = "\033[1m"
    RED     = "\033[91m"
    GREEN   = "\033[92m"
    YELLOW  = "\033[93m"
    BLUE    = "\033[94m"
    MAGENTA = "\033[95m"
    CYAN    = "\033[96m"
    WHITE   = "\033[97m"

BANNER = f"""{Colors.CYAN}{Colors.BOLD}
=============================================================================
       CAN 2.0A Controller - PC Live Demo Dashboard (Day 39)
   Artix-7 FPGA (Nexys 4 DDR) <---> Arduino Uno / MCP2515 Physical Bus
============================================================================={Colors.RESET}"""

class CANDashboard:
    def __init__(self, port, baud=115200, log_prefix="can_traffic_log"):
        self.port_name = port
        self.baud_rate = baud
        self.ser = None
        self.running = False
        self.reader_thread = None

        # Statistics
        self.tx_count = 0
        self.rx_count = 0
        self.err_count = 0
        self.start_time = time.time()

        # CSV Logging
        timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.csv_filename = f"{log_prefix}_{timestamp_str}.csv"
        self.txt_filename = f"{log_prefix}_{timestamp_str}.txt"

        self.csv_file = open(self.csv_filename, mode="w", newline="", encoding="utf-8")
        self.csv_writer = csv.writer(self.csv_file)
        self.csv_writer.writerow(["Timestamp", "Direction", "ID", "DLC", "Payload", "Status_Notes"])
        self.csv_file.flush()

        self.txt_file = open(self.txt_filename, mode="w", encoding="utf-8")
        self.txt_file.write(f"=== CAN Traffic Session Log - {datetime.now()} ===\n")
        self.txt_file.flush()

    def connect(self):
        try:
            self.ser = serial.Serial(self.port_name, self.baud_rate, timeout=0.5)
            self.running = True
            print(f"{Colors.GREEN}[OK] Connected to {self.port_name} at {self.baud_rate} baud.{Colors.RESET}")
            print(f"{Colors.YELLOW}[LOG] Saving session logs to: {self.csv_filename}{Colors.RESET}")

            self.reader_thread = threading.Thread(target=self._rx_worker, daemon=True)
            self.reader_thread.start()
            return True
        except serial.SerialException as e:
            print(f"{Colors.RED}[ERROR] Failed to open port {self.port_name}: {e}{Colors.RESET}")
            return False

    def _rx_worker(self):
        """Background thread that continuously reads lines from UART."""
        buf = ""
        while self.running and self.ser and self.ser.is_open:
            try:
                line = self.ser.readline().decode("utf-8", errors="replace").replace("\r", "").strip()
                if line:
                    self._parse_and_display(line)
            except Exception as e:
                if self.running:
                    print(f"{Colors.RED}[RX Error] {e}{Colors.RESET}")
                break

    def _parse_and_display(self, line):
        now_ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]

        # Log raw line to text file
        self.txt_file.write(f"[{now_ts}] {line}\n")
        self.txt_file.flush()

        # 1. Received CAN Frame
        if "[CAN_RX]" in line:
            self.rx_count += 1
            # Format: "[CAN_RX] ID: 0x244 | DLC: 4 | DATA: DE AD BE EF"
            print(f"{Colors.GREEN}{Colors.BOLD}[RX #{self.rx_count:04d} @ {now_ts}] {line}{Colors.RESET}")

            # Parse fields for CSV
            try:
                parts = line.split("|")
                can_id = parts[0].split("ID:")[1].strip()
                dlc = parts[1].split("DLC:")[1].strip()
                payload = parts[2].split("DATA:")[1].strip()
                self.csv_writer.writerow([now_ts, "RX", can_id, dlc, payload, "OK"])
                self.csv_file.flush()
            except Exception:
                self.csv_writer.writerow([now_ts, "RX", "N/A", "N/A", line, "RAW"])
                self.csv_file.flush()

        # 2. Transmitted CAN Frame
        elif "[CAN_TX]" in line:
            self.tx_count += 1
            print(f"{Colors.CYAN}{Colors.BOLD}[TX #{self.tx_count:04d} @ {now_ts}] {line}{Colors.RESET}")
            try:
                parts = line.split("|")
                can_id = parts[0].split("ID:")[1].strip()
                dlc = parts[1].split("DLC:")[1].strip()
                payload = parts[2].split("DATA:")[1].strip()
                self.csv_writer.writerow([now_ts, "TX", can_id, dlc, payload, "SENT"])
                self.csv_file.flush()
            except Exception:
                self.csv_writer.writerow([now_ts, "TX", "N/A", "N/A", line, "SENT"])
                self.csv_file.flush()

        # 3. Status Report
        elif "[STAT]" in line:
            print(f"{Colors.YELLOW}{Colors.BOLD}[TELEMETRY @ {now_ts}] {line}{Colors.RESET}")
            self.csv_writer.writerow([now_ts, "STAT", "N/A", "N/A", "N/A", line])
            self.csv_file.flush()

        # 4. Gateway Banner
        elif "[CAN-GATEWAY" in line or "READY" in line:
            print(f"{Colors.MAGENTA}{Colors.BOLD}>>> {line} <<<{Colors.RESET}")
            self.csv_writer.writerow([now_ts, "SYS", "N/A", "N/A", "N/A", line])
            self.csv_file.flush()

        # 5. Generic or Debug line
        else:
            print(f"{Colors.WHITE}[FPGA @ {now_ts}] {line}{Colors.RESET}")

    def send_trigger(self):
        """Sends 't' command to trigger default test frame transmission."""
        if self.ser and self.ser.is_open:
            self.ser.write(b"t")
            self.ser.flush()

    def send_status_request(self):
        """Sends 's' command to request live status telemetry."""
        if self.ser and self.ser.is_open:
            self.ser.write(b"s")
            self.ser.flush()

    def send_burst(self, count, interval_ms):
        """Sends a burst of N frames spaced by interval_ms."""
        print(f"{Colors.YELLOW}[BURST] Starting burst of {count} frames with {interval_ms} ms delay...{Colors.RESET}")
        for i in range(count):
            self.send_trigger()
            time.sleep(interval_ms / 1000.0)
        print(f"{Colors.YELLOW}[BURST] Completed sending {count} frames.{Colors.RESET}")

    def print_summary(self):
        elapsed = time.time() - self.start_time
        print(f"\n{Colors.BOLD}{Colors.WHITE}=== Session Summary ==={Colors.RESET}")
        print(f" Elapsed Time    : {elapsed:.1f} seconds")
        print(f" Frames Sent (TX): {self.tx_count}")
        print(f" Frames Rcvd (RX): {self.rx_count}")
        print(f" Log Files       : {self.csv_filename}, {self.txt_filename}")
        print(f"{Colors.BOLD}{Colors.WHITE}======================={Colors.RESET}\n")

    def close(self):
        self.running = False
        if self.ser and self.ser.is_open:
            self.ser.close()
        if self.csv_file:
            self.csv_file.close()
        if self.txt_file:
            self.txt_file.close()
        print(f"{Colors.GREEN}[OK] Session closed and logs finalized.{Colors.RESET}")


def select_com_port():
    """Scans and prompts the user to select an active serial port."""
    ports = list(list_ports.comports())
    if not ports:
        print(f"{Colors.YELLOW}[!] No active COM ports detected automatically.{Colors.RESET}")
        manual_port = input("Enter COM port manually (e.g. COM3 or COM4): ").strip()
        return manual_port if manual_port else "COM3"

    print(f"\n{Colors.BOLD}Available Serial Ports:{Colors.RESET}")
    default_idx = 0
    for idx, p in enumerate(ports):
        is_fpga = ("USB Serial Port" in p.description or "FTDI" in p.description or "Digilent" in p.description)
        tag = f" {Colors.GREEN}{Colors.BOLD}[RECOMMENDED: FPGA]{Colors.RESET}" if is_fpga else ""
        if is_fpga:
            default_idx = idx
        print(f"  [{idx + 1}] {Colors.CYAN}{p.device}{Colors.RESET} - {p.description}{tag}")

    while True:
        choice = input(f"\nSelect port [1-{len(ports)}] (press Enter for default [{default_idx+1}]): ").strip()
        if not choice:
            return ports[default_idx].device
        if choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(ports):
                return ports[idx].device
        # User typed port name (e.g. COM4)
        return choice


def main():
    print(BANNER)
    port = select_com_port()
    dashboard = CANDashboard(port=port)

    if not dashboard.connect():
        sys.exit(1)

    print(f"""
{Colors.BOLD}Interactive Commands:{Colors.RESET}
  {Colors.CYAN}[t]{Colors.RESET} : Trigger single CAN frame transmission (ID: 0x155, DLC: 4)
  {Colors.CYAN}[b <count> <ms>]{Colors.RESET} : Send burst (e.g. 'b 10 50' sends 10 frames with 50ms interval)
  {Colors.CYAN}[s]{Colors.RESET} : Query live CAN Status & Error Counters (TEC, REC, FIFO)
  {Colors.CYAN}[l]{Colors.RESET} : Print live session statistics summary
  {Colors.CYAN}[c]{Colors.RESET} : Clear terminal screen
  {Colors.CYAN}[q]{Colors.RESET} : Quit and save log files
-----------------------------------------------------------------------------
""")

    # Initial status query to verify link
    time.sleep(0.5)
    dashboard.send_status_request()

    try:
        while True:
            cmd = input().strip()
            if not cmd:
                continue

            parts = cmd.split()
            c = parts[0].lower()

            if c == 'q':
                break
            elif c == 't':
                dashboard.send_trigger()
            elif c == 's':
                dashboard.send_status_request()
            elif c == 'l':
                dashboard.print_summary()
            elif c == 'c':
                os.system('cls' if os.name == 'nt' else 'clear')
                print(BANNER)
            elif c == 'b':
                count = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 5
                interval = int(parts[2]) if len(parts) > 2 and parts[2].isdigit() else 100
                dashboard.send_burst(count, interval)
            else:
                print(f"{Colors.YELLOW}[?] Unknown command: '{cmd}'. Use 't' (send), 's' (status), 'b' (burst), 'q' (quit).{Colors.RESET}")
    except (KeyboardInterrupt, EOFError):
        pass
    finally:
        dashboard.print_summary()
        dashboard.close()

if __name__ == "__main__":
    main()
