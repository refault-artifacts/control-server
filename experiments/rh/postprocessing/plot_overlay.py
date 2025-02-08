import pandas as pd
import matplotlib.pyplot as plt

# Read data from CSV file
df0 = pd.read_csv('crucial0.csv')
df1 = pd.read_csv('crucial1.csv')

# Extract x and y columns
x0 = df0['row']
x1 = df1['row']
y0 = df0['hc_min']
y1 = df1['hc_min']

df1['row'] = df1['row'] + 1024

# Combine the two DataFrames
merged_df = pd.concat([df0, df1], ignore_index=True)
merged_df = merged_df.sort_values(by='row').reset_index(drop=True)

# Write the result to a new CSV file
merged_df.to_csv('merged_crucial.csv', index=False)

# Create plot
plt.plot(x0, y0)
plt.plot(x1, y1)
plt.xlabel('Row')
plt.ylabel('HC_min')
plt.title('Data Plot')
plt.grid(True)
plt.show()

