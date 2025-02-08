import os
import re
import sys
from collections import defaultdict

def find_min_activations_with_good_file(directory):
    row_min_activations = defaultdict(lambda: float('inf'))

    for filename in os.listdir(directory):
        if not filename.endswith(".log"):
            continue

        file_path = os.path.join(directory, filename)

        with open(file_path, 'rb') as file:
            try:
                content = file.read().decode('utf-8', errors='ignore')
                if "expected" in content:
                    for line in content.splitlines():
                        m = re.search(r"expected (0x[0-9a-fA-F]+), got (0x[0-9a-fA-F]+)", line)
                        if m:
                            exp = int(m.group(1),16)
                            got = int(m.group(2),16)
                            bitflips = bin(exp ^ got).count('1')
                            if (bitflips < 8):
                                row_match = re.search(r"ROW_IDX=(\d+)", content)
                                activation_match = re.search(r"HAMMER_COUNT=(\d+)", content)
                                if row_match and activation_match:
                                    row_number = int(row_match.group(1))
                                    activations = int(activation_match.group(1))
                                    row_min_activations[row_number] = min(row_min_activations[row_number], activations)
            except Exception as e:
                print(f"Error reading file {filename}: {e}")

    result = sorted(row_min_activations.items())
    print(f"row,hc_min")
    for row, min_activations in result:
        print(f"{row},{min_activations}")


dir = sys.argv[1]
find_min_activations_with_good_file(dir)
