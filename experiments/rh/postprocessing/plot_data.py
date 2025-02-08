import pandas as pd
import matplotlib.pyplot as plt

# Read data from CSV file
df = pd.read_csv('data.csv')

# Extract x and y columns
x = df['row']
y = df['hc_min']

# Create plot
plt.plot(x[:64], y[:64])
plt.plot(x[64:]-1024, y[64:])
plt.xlabel('Row')
plt.ylabel('HC_min')
plt.title('Data Plot')
plt.grid(True)
plt.show()

