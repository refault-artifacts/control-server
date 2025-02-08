import os
import re
from collections import defaultdict

# Dictionary to store data: {row: {hammer_count: bit_errors}}
data = defaultdict(lambda: defaultdict(int))

# Regex to extract relevant information
filename_pattern = re.compile(r"\d+-\d+-cn\d+-(\d+)-(\d+)-")
bit_error_pattern = re.compile(r"FOUND (\d+) BIT ERRORS")

# Parse log files in the current directory
for filename in os.listdir():
    if filename.endswith(".log"):
        match = filename_pattern.search(filename)
        if match:
            row = int(match.group(1))
            hammer_count = int(match.group(2))

            # Read the file content, handling potential binary data
            with open(filename, 'rb') as file:
                for line in file:
                    try:
                        decoded_line = line.decode('utf-8')
                    except UnicodeDecodeError:
                        continue
                    bit_error_match = bit_error_pattern.search(decoded_line)
                    if bit_error_match:
                        bit_errors = int(bit_error_match.group(1))
                        data[row][hammer_count] += bit_errors

# Find the lowest hammer count with zero bit flips and the lowest overall hammer count for each row
result = {}
for row, hammer_data in data.items():
    all_hammers = sorted(hammer_data.keys())
    zero_bit_hammers = [hc for hc in all_hammers if hammer_data[hc] > 0]

    lowest_zero = zero_bit_hammers[0] if zero_bit_hammers else None
    lowest_overall = all_hammers[0] if all_hammers else None

    result[row] = (lowest_zero, lowest_overall)

# Print the results
print("Row | Lowest Hammer Count | Lowest Overall Hammer Count | Difference ")
print("-------------------------------------------------------------------")
for row, (lowest_zero, lowest_overall) in sorted(result.items()):
          print(f"{row:3} | {lowest_zero:30} | {lowest_overall} | {lowest_zero-lowest_overall}")

