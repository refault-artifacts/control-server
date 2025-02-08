# Make a simple line plot for sanity checks

import pandas as pd
import matplotlib.pyplot as plt

# Read data from CSV file
df = pd.read_csv('data.csv')

# Extract x and y columns
x = df['x']
y = df['y']

# Create plot
plt.plot(x, y)
plt.xlabel('X')
plt.ylabel('Y')
plt.title('Data Plot')
plt.grid(True)
plt.show()

