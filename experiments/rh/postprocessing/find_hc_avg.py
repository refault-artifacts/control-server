import pandas as pd
import sys


df = pd.read_csv(sys.argv[1])
print(f'min={min(df['hc_min'])}')
print(f'max={max(df['hc_min'])}')
print(f'avg={sum(df['hc_min'])/len(df['hc_min'])}')
