import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import glob
from matplotlib import rcParams
import numpy as np
from matplotlib.ticker import ScalarFormatter
from matplotlib.ticker import EngFormatter

# Configure font
rcParams['font.family'] = 'CMU Serif'
rcParams['font.size'] = 10
rcParams['mathtext.fontset'] = 'cm'
rcParams['text.usetex'] = True

# Define colors for the violin plots
colors = ["red", "blue", "green"]

# Read multiple CSV files and create violin plot
def create_violin_plot(csv_files):
    data = []

    for idx, file in enumerate(csv_files):
        df = pd.read_csv(file)
        df['source'] = idx  # Label data by index
        print(min(df['hc_min']))
        data.append(df)

    combined_data = pd.concat(data, ignore_index=True)

    plt.figure(figsize=(4, 2.5))
    sns.violinplot(
        x='source',
        y='hc_min',
        data=combined_data,
        palette=colors,
        alpha=0.5,
        linewidth=1.5
    )

    #plt.gca().yaxis.set_major_formatter(EngFormatter(useMathText=True))
    plt.gca().yaxis.set_major_formatter(EngFormatter(unit=''))
    #plt.ticklabel_format(axis='y', style='scientific', scilimits=(0, 0))

    # Customize the labels
    plt.ylabel(r'HC$_\mathrm{min}$')
    plt.xlabel(r'DRAM vendor')
    plt.yticks(np.arange(0,34000,4000))
    plt.xticks(ticks=range(len(csv_files)), labels=[r'Micron','Samsung'])

    plt.gca().set_axisbelow(True)
    plt.grid(axis='y', linestyle='--', alpha=0.7)

    # Save to PDF
    plt.tight_layout()
    plt.savefig("violin_plot.pdf")

# Example usage
if __name__ == "__main__":
    csv_files = ['merged_crucial_patched.csv', 'merged_corsair_patched.csv']  # Adjust pattern as needed
    create_violin_plot(csv_files)

