#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["hidapi"]
# ///
"""Control the Logitech Litra Glow over USB HID."""
import argparse
import sys
import hid

VID, PID = 0x046D, 0xC900

BRIGHTNESS_MIN, BRIGHTNESS_MAX = 20, 250
TEMP_MIN, TEMP_MAX = 2700, 6500


def pad(data: list[int], size: int = 20) -> bytes:
    return bytes(data) + bytes(size - len(data))


def open_device():
    d = hid.device()
    try:
        d.open(VID, PID)
    except (OSError, IOError) as e:
        sys.exit(f"Litra Glow not found ({e}). Is it plugged in?")
    return d


def on(d):  d.write(pad([0x11, 0xff, 0x04, 0x1c, 0x01]))
def off(d): d.write(pad([0x11, 0xff, 0x04, 0x1c, 0x00]))


def brightness(d, level: int):
    if not BRIGHTNESS_MIN <= level <= BRIGHTNESS_MAX:
        sys.exit(f"brightness must be {BRIGHTNESS_MIN}..{BRIGHTNESS_MAX}")
    d.write(pad([0x11, 0xff, 0x04, 0x4c, 0x00, level & 0xff, (level >> 8) & 0xff]))


def temperature(d, kelvin: int):
    if not TEMP_MIN <= kelvin <= TEMP_MAX:
        sys.exit(f"temperature must be {TEMP_MIN}..{TEMP_MAX} K")
    d.write(pad([0x11, 0xff, 0x04, 0x9c, (kelvin >> 8) & 0xff, kelvin & 0xff]))


def main():
    p = argparse.ArgumentParser(prog="litra", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("on", help="turn light on")
    sub.add_parser("off", help="turn light off")
    b = sub.add_parser("bright", help=f"set brightness ({BRIGHTNESS_MIN}-{BRIGHTNESS_MAX})")
    b.add_argument("level", type=int)
    t = sub.add_parser("temp", help=f"set temperature in Kelvin ({TEMP_MIN}-{TEMP_MAX})")
    t.add_argument("kelvin", type=int)

    args = p.parse_args()
    d = open_device()
    try:
        if args.cmd == "on": on(d)
        elif args.cmd == "off": off(d)
        elif args.cmd == "bright": brightness(d, args.level)
        elif args.cmd == "temp": temperature(d, args.kelvin)
    finally:
        d.close()


if __name__ == "__main__":
    main()
