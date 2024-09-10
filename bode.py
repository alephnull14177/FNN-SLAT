# Script: bode.py
#
# Generate a bode plot from varying frequency sine waves. All frequency
# response data *.csv and *.csv.out files are expected to be in a directory
# defined by `--data-dir` option (default: ./data).
#
# Decibels equation: 20 * log_{10}(|Vout/Vin|)
#
# Usage:
#   $ python bode.py <AMP> [options]
#
# Options:
#   <AMP>               amplitude to use when finding files for bode plot
#   --single <FILE>     visualize a single input/output sine wave result
#   --data-dir <DIR>    directory to where to collect csv file data
#   --xl                use larger magnification settings for plots

import argparse, glob, math, os
from matplotlib import pyplot as plt

# --- Constants

# goal frequency to attenuate
TARGET_HZ = 60

# --- Classes/Functions

class Record:
    def __init__(self, time: float, deci: float):
        self.time: float = time
        self.deci: float = deci
    pass


def load_result(fp: str):
    '''
    Loads a list of records from a filepath `fp`.
    '''
    results = []
    with open(fp, 'r') as fh:
        for line in fh.readlines():
            results += [load_record(line)]
    return results


def load_record(line: str) -> Record:
    '''
    Loads a single record from a file's `line`.
    '''
    parts = line.strip().split(',')
    return Record(float(parts[0].strip()), float(parts[1].strip()))


def parse_filename(fname: str):
    '''
    Parses the file name into (amplitude, frequency, sampling frequency).
    '''
    header = fname.find('_')
    amp_footer = fname.find('a')
    freq_footer = fname.find('f')
    sfreq_footer = fname.find('sf')

    amp = int(fname[header+1:amp_footer])
    freq = int(fname[amp_footer+1:freq_footer])
    sfreq = int(fname[freq_footer+1:sfreq_footer])
    # determine tested frequency from file
    return (amp, freq, sfreq)


def find_last_local_peak(records) -> float:
    '''
    Returns a local peak of the sine wave.
    
    Looks at the last half of the samples, and takes the highest value found.
    The reason to look at last half of samples is to ignore the transient
    response when coming off of reset during simulation.
    '''
    data = [abs(r.deci) for r in records[int(len(records)/2):][::-1]]
    peak = data[0]
    for sample in data[1:]:
        if sample > peak:
            peak = sample
        pass
    # find a local peak in wave
    return peak


def compute_magnitude(v_in, v_out) -> float:
    '''
    Computes the magnitude of the system's response using the gain of the
    system v_out/v_in.

    If v_out/v_in is close to 0.0 (silence), then -60 dB is reported.
    '''
    if v_out/v_in < 0.001:
        return -60
    return 20*math.log10(v_out/v_in)


def main():

    # --- Command-line arguments

    parser = argparse.ArgumentParser()

    parser.add_argument('amp', action='store', type=int, help='amplitude to use when generating bode plot')
    parser.add_argument('--single', metavar='file', action='store', type=str, help='single input/output filter result')
    parser.add_argument('--data-dir', metavar='dir', action='store', type=str, default='./data', help='directory to locate csv files')
    parser.add_argument('--xl', action='store_true', help='use larger magnification settings for plots')
    parser.add_argument('--no-plot', action='store_true', help='do not create interactive plot during single view')

    args = parser.parse_args()

    SINGLE_RESULT = str(args.single) if args.single != None else None
    BODE_AMPLITUDE = int(args.amp)
    OUTPUT_PATH = str(args.data_dir) + '/'
    PLOT_XL = bool(args.xl)
    SINGLE_NO_PLOT = bool(args.no_plot)

    # --- Logic

    if SINGLE_RESULT != None:

        (amp, freq, sample_freq) = parse_filename(os.path.basename(SINGLE_RESULT))

        # grab input data points
        print('Loading input results...')
        inputs = load_result(SINGLE_RESULT)
        print('Loading output results...')
        outputs = load_result(SINGLE_RESULT + '.out')

        times = []
        in_samples = []
        out_samples = []
        print('Formatting data...')

        sample_count = len(outputs) if len(outputs) < len(inputs) else len(inputs)
        # process and format data
        for i in range(sample_count):
            times += [inputs[i].time]
            in_samples += [inputs[i].deci]
            out_samples += [outputs[i].deci]
            pass
        print('Plotting results...')

        v_in = find_last_local_peak(inputs)
        v_out = find_last_local_peak(outputs)
        print('Frequency:', freq, 'Vin:', v_in, 'Vout:', v_out)
        
        mag = compute_magnitude(v_in, v_out)
        print('Frequency:', freq, 'Magnitude:', mag, 'dBs')

        if SINGLE_NO_PLOT == False:
            plt.title('Filter Simulation ('+str(freq)+'Hz)')
            plt.ylabel('Amplitude')
            plt.xlabel('Time')
            # plot results
            plt.plot(times, in_samples, label='input')
            plt.plot(times, out_samples, label='output')
            plt.show()
    
        # raise a bad exit code if the system does not attenuate at 60Hz
        if freq == TARGET_HZ and mag > -12.0:
            exit(101)

        exit(0)

    # otherwise, generate the bode plot!
    sine_waves = glob.glob(OUTPUT_PATH + 'sine_' + str(BODE_AMPLITUDE) + 'a' + '*.csv')
    print('Found', len(sine_waves), 'sine wave results...')

    freq_mag_pairs = []

    for sine_filepath in sine_waves:

        (amp, freq, sample_freq) = parse_filename(os.path.basename(sine_filepath))
        print('Analyzing frequency response for '+str(freq)+'Hz...')

        # find last local maximum value for input
        in_samples = load_result(sine_filepath)
        v_in = find_last_local_peak(in_samples)

        # verify an output file exists
        if os.path.exists(sine_filepath + '.out') == False:
            print('Warning: Skipping ' + str(os.path.basename(sine_filepath)) + ' because no results found')
            continue

        # find last local maximum value for output
        out_samples = load_result(sine_filepath + '.out')
        v_out = find_last_local_peak(out_samples)

        print('Frequency:', freq, 'Vin:', v_in, 'Vout:', v_out)

        mag = compute_magnitude(v_in, v_out)
        print('Frequency:', freq, 'Magnitude:', mag, 'dBs')

        # add to the list of responses
        freq_mag_pairs += [(freq, mag)]
        pass

    magnitudes = []
    frequencies = []

    # sort into ascending frequency order
    freq_mag_pairs.sort(key=lambda x: x[0])

    TARGET_SAMPLE = None

    # split into two separate lists for plotting
    for freq, mag in freq_mag_pairs:
        frequencies += [freq]
        magnitudes += [mag]
        if freq == TARGET_HZ:
            TARGET_SAMPLE = (freq, mag)
        pass

    # create the plot
    fig, ax = plt.subplots(1,1)
    ax.plot(frequencies, magnitudes)

    ax.set_title('Bode Plot')
    ax.set_xscale('log')
    ax.set_xlabel('Frequency (Hz)')
    ax.set_ylabel('Magnitude (dB)')

    # draw a point at 60Hz (target frequency to attenuate)
    if TARGET_SAMPLE != None:
        plt.scatter(TARGET_SAMPLE[0], TARGET_SAMPLE[1], color='r')
    else:
        plt.axvline(TARGET_HZ, color='r')

    if PLOT_XL == True:
        fig.set_size_inches(16, 9, forward=True)
        fig.set_dpi(600)
        pass

    plt.tight_layout()
    plt.savefig(f"bode-{amp}.png", dpi=fig.dpi, bbox_inches='tight')

    plt.show()
    pass


if __name__ == '__main__':
    main()
    pass