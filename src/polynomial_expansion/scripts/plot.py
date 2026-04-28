import matplotlib.pyplot as plt
from cycler import cycler
from matplotlib.backends.backend_pdf import PdfPages
import subprocess
import sys
import theory

def parse(filename):
    values=[]
    with open (filename, 'r') as file:
        for line in file:
            parts = line.split()
            
            if len(parts) == 3:
                #n d time
                values.append([int(parts[0]), int(parts[1]), float(parts[2])])
    return values

def flops(n,d,time):
    return 2*n*(d+1)/time

def filter_n(vals, n: int):
    filtered = [v for v in vals if v[0] == n]
    filtered.sort(key=lambda x: x[1])

    x = []
    y = []

    for v in filtered:
        x.append(v[1])
        y.append(flops(v[0], v[1], v[2]))
    return (x,y)

def filter_d(vals, d: int):
    filtered = [v for v in vals if v[1] == d]
    filtered.sort(key=lambda x: x[0])

    x = []
    y = []

    for v in filtered:
        x.append(v[0])
        y.append(flops(v[0], v[1], v[2]))
    return (x,y)


def plot_to_pdf_n(data, output_pdf, n):

    custom_colors = ['#264653', '#2a9d8f', '#e9c46a', '#f4a261', '#e76f51', '#4361ee', '#7209b7']
    custom_markers = ['o', 's', '^', 'D', 'x', '*', 'v']

    
    plt.rcParams['axes.prop_cycle'] = (cycler(color=custom_colors) + 
                                       cycler(marker=custom_markers))
    plt.clf()
    # Create the plot
    plt.figure(figsize=(8, 6))
    for s in data:
        plt.plot(s[0], s[1], label=s[2])
        
    plt.title(f'n={n:,}')
    plt.xlabel('Degree')
    plt.ylabel('Flops')
    plt.yscale('log')
    plt.xscale('log')
    plt.legend()
    plt.grid(True)

    output_pdf.savefig()
    plt.close() 

def plot_to_pdf_d(data, output_pdf, d):
        
    custom_colors = ['#264653', '#2a9d8f', '#e9c46a', '#f4a261', '#e76f51', '#4361ee', '#7209b7']
    custom_markers = ['o', 's', '^', 'D', 'x', '*', 'v']

    
    plt.rcParams['axes.prop_cycle'] = (cycler(color=custom_colors) + 
                                       cycler(marker=custom_markers))
    plt.clf()
    # Create the plot
    plt.figure(figsize=(8, 6))
    for s in data:
        plt.plot(s[0], s[1], label=s[2])
        
    plt.title(f'd={d:,}')
    plt.xlabel('Array Size (in element)')
    plt.ylabel('Flops')
    plt.yscale('log')
    plt.xscale('log')
    plt.legend()
    plt.grid(True)

    output_pdf.savefig()
    plt.close() 

def key_perf(machine):
    result = subprocess.run(['./analysis.sh', machine], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    peak_flops = float(lines[0].split()[1])
    gpu_bw = float(lines[1].split()[1])
    interconnect_bw = float(lines[2].split()[1])
    uvm_bw = float(lines[3].split()[1])
    return [peak_flops, gpu_bw, interconnect_bw, uvm_bw]
    
    
machine=sys.argv[1]
    
codes = ['gpu_pinned', 'gpu_basic', 'gpu_uvm_basic', 'gpu_stream']

results = {}
for c in codes:
    vals = parse(f"../results/{machine}/{c}")
    results[c] = vals

arrayssizes = set()
degrees = set()

for c in codes:
    for v in results[c]:
        arrayssizes.add(v[0])
        degrees.add(v[1])

arrayssizes = sorted(list(arrayssizes))
degrees=sorted(list(degrees))

perf_info = key_perf(machine)

if 'gpu_pinned' in results:
    th = []
    for v in results['gpu_pinned']:
        n = v[0]
        d = v[1]
        interbw = perf_info[2]
        peak_flops = perf_info[0]
        gpu_bw = perf_info[1]
        t = theory.nonoverlapped_prediction(n, d, interbw, gpu_bw, peak_flops)
        th.append([n, d, t])
    results['predict_gpu_pinned'] = th
    codes.append('predict_gpu_pinned')

if 'gpu_stream' in results:
    th = []
    for v in results['gpu_stream']:
        n = v[0]
        d = v[1]
        interbw = perf_info[2]
        peak_flops = perf_info[0]
        gpu_bw = perf_info[1]
        t = theory.overlapped_prediction(n, d, interbw, gpu_bw, peak_flops)
        th.append([n, d, t])
    results['predict_gpu_stream'] = th
    codes.append('predict_gpu_stream')

if 'gpu_uvm_basic' in results:
    th = []
    for v in results['gpu_uvm_basic']:
        n = v[0]
        d = v[1]
        interbw = perf_info[3]
        peak_flops = perf_info[0]
        gpu_bw = perf_info[1]
        t = theory.overlapped_prediction(n, d, interbw, gpu_bw, peak_flops)
        th.append([n, d, t])
    results['predict_gpu_uvm'] = th
    codes.append('predict_gpu_uvm')
    
pdf = PdfPages(f'analysis-{machine}.pdf')

for size in arrayssizes:
    to_plot = []
    for c in codes:
        filtered = filter_n(results[c], size)
        print (filtered)
        to_plot.append([filtered[0], filtered[1], c])

    plot_to_pdf_n (to_plot, pdf, size)

for degree in degrees:
    to_plot = []
    for c in codes:
        filtered = filter_d(results[c], degree)
        print (filtered)
        to_plot.append([filtered[0], filtered[1], c])

    plot_to_pdf_d (to_plot, pdf, degree)

    

pdf.close()
