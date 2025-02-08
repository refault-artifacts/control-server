#!/usr/bin/env python3
import sys
from collections import Counter
from pathlib import Path

FUNCS = [
    ("SUB", [0x3fffc0040]),
    ("RK", []),
    ("BG", [0x42100100, 0x84200200, 0x108401000]),
    ("BA", [0x210840400, 0x21080800])
]

ROW_SHIFT = 18
ROW_MASK = (1 << 16) - 1


def get_bits(addr):
    bits = []
    for label, funcs in FUNCS:
        value = 0
        for func in funcs[::-1]:
            value = (value << 1) | (bin((addr & func)).count("1") % 2)
        bits.append(value)
    bits.append((addr >> ROW_SHIFT) & ROW_MASK)
    return tuple(bits)


def addr_bits_to_str(bits):
    bits_str = [str(bit) for bit in bits]
    bits_str[-1] = f"0x{bits[-1]:04x}"
    return f"({','.join(bits_str)})"


file = Path(sys.argv[1])

print(f">>> {file.name}")
with file.open("r", encoding="utf8", errors="ignore") as f:
    lines = [line.rstrip("\n") for line in f]

    aggr_lines = [line for line in lines if line.startswith("a:") or line.startswith("b:")]
    aggr_addrs = [int(aggr.split(" ")[-1], 16) for aggr in aggr_lines]
    print("software aggressors:", ", ".join([addr_bits_to_str(get_bits(aggr)) for aggr in aggr_addrs]))
   
    actual_aggressors =  [get_bits(aggr)[4] | 0x82 for aggr in aggr_addrs]
    print("physical aggressors:", ", ".join(['{:02x}'.format(aggr) for aggr in actual_aggressors]))
    expected_victims = [aggr - 1 for aggr in actual_aggressors]  + [aggr + 1 for aggr in actual_aggressors]

    corruption_addrs = [int(line.split("0x")[1].split(":")[0], 16) for line in lines if line.startswith("addr 0x")]
    corruption_addr_bits = [get_bits(addr) for addr in corruption_addrs]
    counts = Counter(corruption_addr_bits).most_common()
    for addr_bits, count in counts:
        print(f"{count:3d}x: {addr_bits_to_str(addr_bits)}")
        if (addr_bits[4] not in expected_victims):
            print(f"==== UNEXPECTED VICTIM: 0x{addr_bits[4]:04x} ====")
            print("expected victims: 0x" + " 0x".join('{:02x}'.format(victim) for victim in expected_victims))
