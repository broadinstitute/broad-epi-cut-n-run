import matplotlib.pyplot as plt
import sys
from matplotlib.ticker import FuncFormatter


def thousands_formatter(x, pos):
    return '%1.0fk' % (x * 1e-3)


hist_file = sys.argv[1]
output_prefix = sys.argv[2]

sizes = []
counts = []
# Load the data
with open(hist_file, 'r') as f:
    for line in f:
        count, size = line.strip().split()
        counts.append(int(count))
        sizes.append(int(size))

# Sum all the element in the counts list whose respective size is lower than cutoff
total_counts = sum(counts)
nucleosome_free_counts = sum([count for count, size in zip(counts, sizes) if size < 120])
mononucleosome_counts = sum([count for count, size in zip(counts, sizes) if size >= 120 and size <= 200])
multinucleosome_counts = sum([count for count, size in zip(counts, sizes) if size > 200])
usable_counts = total_counts - nucleosome_free_counts

# Write the counts to a file
with open(f'{output_prefix}_summary_counts.txt', 'w') as f:
    f.write(f'Total number of fragments: {total_counts}\n')
    f.write(f'Nucleosome-free: {nucleosome_free_counts}\n')
    f.write(f'Mononucleosome: {mononucleosome_counts}\n')
    f.write(f'Multinucleosome: {multinucleosome_counts}\n')
    f.write(f'Usable fragments: {usable_counts}\n')

# Plot the data
# color all the numbers lower than a cutoff with a different color and add a label with the number of fragments lower than the cutoff

# Define pastel colors
pastel_colors = ['#78b7e4', '#437fa7', '#004c6d']

# Assign colors based on size ranges using list comprehension
colors = [
    pastel_colors[0] if size < 120 else pastel_colors[2] if size > 200 else pastel_colors[1]
    for size in sizes
]

# Increase the plot size
plt.figure(dpi=300)

plt.bar(sizes, counts, width=1.0, color=colors, edgecolor='none')
plt.title('Histogram of sizes - Total number of fragments: ' + f'{total_counts:,}')
plt.xlabel('Fragment size')
plt.ylabel('Number of fragments')
plt.gca().yaxis.set_major_formatter(FuncFormatter(thousands_formatter))
plt.legend(handles=[
    plt.Line2D([0], [0], color=pastel_colors[0], lw=4, label='Nucleosome-free: ' + f'{nucleosome_free_counts:,}'),
    plt.Line2D([0], [0], color=pastel_colors[1], lw=4, label='Mononucleosome: ' + f'{mononucleosome_counts:,}'),
    plt.Line2D([0], [0], color=pastel_colors[2], lw=4, label='Multinucleosome: ' + f'{multinucleosome_counts:,}')
], loc='upper right')
#save the plot
plt.savefig(f'{output_prefix}.pdf')
plt.savefig(f'{output_prefix}.png')
