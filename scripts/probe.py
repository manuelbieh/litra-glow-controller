#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["hidapi"]
# ///
"""Probe different brightness command variants for Litra Glow.
Run this with the light ON. Watch for brightness changes.
"""
import hid
import time
import sys

VID, PID = 0x046D, 0xC900

def pad(data, size=20):
    return bytes(data) + bytes(size - len(data))

def open_dev():
    d = hid.device()
    d.open(VID, PID)
    return d

VARIANTS = [
    ("A: current (BE, 0x4c 0x00 MSB LSB)",    lambda lvl: [0x11, 0xff, 0x04, 0x4c, 0x00, (lvl>>8)&0xff, lvl&0xff]),
    ("B: LE (0x4c 0x00 LSB MSB)",             lambda lvl: [0x11, 0xff, 0x04, 0x4c, 0x00, lvl&0xff, (lvl>>8)&0xff]),
    ("C: no pad (0x4c MSB LSB)",              lambda lvl: [0x11, 0xff, 0x04, 0x4c, (lvl>>8)&0xff, lvl&0xff]),
    ("D: single byte (0x4c 0x00 VAL)",        lambda lvl: [0x11, 0xff, 0x04, 0x4c, 0x00, lvl&0xff]),
    ("E: single byte after 0x4c (0x4c VAL)",  lambda lvl: [0x11, 0xff, 0x04, 0x4c, lvl&0xff]),
    ("F: percent (0x4c 0x00 0x00 percent)",   lambda pct: [0x11, 0xff, 0x04, 0x4c, 0x00, 0x00, pct]),
    ("G: opcode 0x5c",                        lambda lvl: [0x11, 0xff, 0x04, 0x5c, 0x00, (lvl>>8)&0xff, lvl&0xff]),
    ("H: opcode 0x8c",                        lambda lvl: [0x11, 0xff, 0x04, 0x8c, 0x00, (lvl>>8)&0xff, lvl&0xff]),
]

def main():
    d = open_dev()
    # ensure on
    d.write(pad([0x11, 0xff, 0x04, 0x1c, 0x01]))
    time.sleep(1)
    try:
        for name, mk in VARIANTS:
            for level in (20, 250, 20, 250):
                pkt = pad(mk(level))
                print(f"{name} level={level} bytes={pkt[:10].hex(' ')}")
                d.write(pkt)
                time.sleep(0.8)
            print("--- pause 2s ---")
            time.sleep(2)
    finally:
        d.close()

if __name__ == "__main__":
    main()
