# Script: sine.py
#
# Generate a series of data points to be saved to a .csv file to be read in as
# simulated sine wave readings for filter characterization (bode plot).
#
# This script also allows for viewing the plot of the generated sine wave by
# using the '--plot' option. The sampled values from the sine wave are written
# to a .csv file for simulation and further processing.
#
# CSV Data Format:
#   There is a header for the generated CSV files. Each line in the CSV has the
#   following structure:
#       <time>,<adc-value>
#
#   where <adc-value> is the actual decimal representation of the corresponding 
#   sample and <time> is the index of the sample in the stream.
#
# Usage:
#   $ python sine.py [options] <amplitude> <signalfreq> <samplefreq>
#
# Options:
#   --plot      visualize the generated sine wave
#   --binary    csv data format includes the raw bit representation (deprec.)

import argparse, math
import numpy as np
from matplotlib import pyplot as plt

# --- Constants

# number of full signal periods to generate
SIGNAL_CYCLES = 6

ADC_BIT_PRECISION = 10

ADC_MAX = (2**(ADC_BIT_PRECISION-1))-1
ADC_MIN = -(2**(ADC_BIT_PRECISION-1))

# --- Command-line arguments

parser = argparse.ArgumentParser()

parser.add_argument('amplitude', action='store', type=int, help='sine wave amplitude')
parser.add_argument('signalfreq', action='store', type=int, help='signal frequency in Hz')
parser.add_argument('samplefreq', action='store', type=int, help='sampling frequency in Hz')
parser.add_argument('--plot', action='store_true', help='plot the sine wave data points')
parser.add_argument('--data-dir', metavar='dir', action='store', type=str, default='./data', help='directory to locate csv files')

args = parser.parse_args()

SIGNAL_AMP = int(args.amplitude)
SIGNAL_FREQ = int(args.signalfreq)
SAMPLING_FREQ = int(args.samplefreq)
PLOT_SIGNAL = bool(args.plot)
OUTPUT_PATH = str(args.data_dir) + '/'

if SIGNAL_AMP > ADC_MAX:
    print('Error: Specified amplitude '+str(SIGNAL_AMP)+' exceeds range of two\'s complement representation for '+str(ADC_BIT_PRECISION)+' bits')
    exit(101)
elif SIGNAL_AMP <= 0:
    print('Error: Specified amplitude must be a positive number')
    exit(101)

# --- Logic

w = 2*math.pi*SIGNAL_FREQ

SIGNAL_PERIOD = 1/SIGNAL_FREQ

T = np.arange(0, SIGNAL_PERIOD*SIGNAL_CYCLES, 1/SAMPLING_FREQ)

print('Generating '+str(len(T))+' samples...')

signal_points = [SIGNAL_AMP*math.sin(w*t) for t in T]

# visualize the plot
if PLOT_SIGNAL == True:
    plt.title('Sine Wave ('+str(SIGNAL_FREQ)+' Hz) at '+str(SAMPLING_FREQ)+' Hz Sampling')
    plt.ylabel('Amplitude')
    plt.xlabel('Time')
    plt.plot(T, signal_points)
    plt.show()
    pass

print('Writing samples to file...')

FILE_PATH = OUTPUT_PATH + 'sine_'+str(SIGNAL_AMP)+'a'+str(SIGNAL_FREQ)+'f'+str(SAMPLING_FREQ)+'sf'+'.csv'

# write signal data points to a csv file (no header)
with open(FILE_PATH, 'w') as fh:
# format: <time>,<adc-value>
    for i, t in enumerate(T):
        time = i
        # the ADCs report 10 bits of precision
        raw_value = signal_points[i]
        # clamp to be sure its within the range
        if raw_value > ADC_MAX:
            raw_value = ADC_MAX
        if raw_value < ADC_MIN:
            raw_value = ADC_MIN
        fh.write(f"{time},{round(raw_value)}\n")
    pass

print('Samples saved to:', FILE_PATH)
