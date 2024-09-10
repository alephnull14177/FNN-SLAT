# Script: impulse.py
#
# Generate the impulse response graph from collected outputs of an HDL
# simulation.

import bode
from matplotlib import pyplot as plt
from matplotlib import rcParams
import argparse
import numpy as np
import df1
from datetime import datetime

def is_attenuated(samples, ending_range: int, detection_val: float) -> bool:
    '''
    Checks if the samples starting at index `ending_range` have stayed below the `detection_val`.
    '''
    print('Checking attenuation starting at sample', str(len(samples)-ending_range-1)+'/'+str(len(samples)), 'with threshold', detection_val, 'amplitude...')
    is_attenuated = True
    #for i in range(ending_range):
    for i,num in enumerate(samples):
        if samples[len(samples)-1-i] > detection_val:
            is_attenuated = False
            break
        pass
    return is_attenuated


def main():
    # --- Command-line arguments

    parser = argparse.ArgumentParser()

    parser.add_argument('file', action='store', type=str, help='path to impulse data')
    parser.add_argument('--frac-bits', action='store', type=int, default=52, help='number of fractional bits')
    parser.add_argument('--no-plot', action='store_true', help='do not create interactive plot during single view')
    parser.add_argument('--save-fig', action='store_true', help='do not create interactive plot during single view')

    args = parser.parse_args()

    FILE = str(args.file)
    FRAC_BITS = int(args.frac_bits)
    NO_PLOT = bool(args.no_plot)
    SAVE_FIG = bool(args.save_fig)

    # --- Logic

    data = bode.load_result(FILE)

    times = []
    out_samples = []
    print('Formatting data...')

    # process and format data
    for i in range(len(data)):
        # convert nanoseconds to seconds
        times += [data[i].time / 10**9]
        out_samples += [data[i].deci / (2**FRAC_BITS)]
        pass


    # use a detector to verify signal is attenutated at the end
    ENDING_RANGE = 100_000
    DETECT_VAL = 0.0001
    is_suppressed = is_attenuated(out_samples, ENDING_RANGE, DETECT_VAL)
    print('Attenuated:', is_suppressed)

    # load ideal and approximations from SW simulations

    NUM_SAMPLES = len(data)-1
    in_samples = np.zeros(NUM_SAMPLES+1)
    in_samples[0] = (2**(10-1))-1

    # print('Running simulation for ideal model...')
    # ideal_samples = np.fromiter(df1.df1(df1.B, df1.A, in_samples), float, in_samples.size)
    print('Running simulation for approximation (only coefficients)...')
    ideal_dut_samples = np.fromiter(df1.dut_df1(df1.B, df1.A, in_samples, FRAC_BITS), float, in_samples.size)

    mse = np.square(ideal_dut_samples - np.array(out_samples)).mean()
    print('Mean Squared Error:', mse)

    is_within_error = True if mse < float(1e0) else False

    # plot setup
    fig, ax = plt.subplots(1,1)

    ax.set_title('Impulse Response')
    ax.set_ylabel('Amplitude')
    ax.set_xlabel('Time (seconds)')
    rcParams['agg.path.chunksize'] = 1000

    # plot results
    ax.plot(times[1:], ideal_dut_samples[1:], label='Ideal (SW)', zorder=1, alpha=1.0, color='r', linestyle='-', linewidth=1.0)
    ax.plot(times[1:], out_samples[1:], label='Actual (HW)', zorder=2, alpha=1.0, color='b', linestyle=':', linewidth=2.0)
    ax.legend()

    if SAVE_FIG:
        print('Saving results...')
        fig.set_size_inches(16, 9, forward=True)
        fig.set_dpi(600)
        plt.tight_layout()
        date = datetime.now().strftime("%Y-%m-%d_%I-%M-%S%p")
        plt.savefig(f"images/impulse/impulse_plot_{date}.png", dpi=fig.dpi, bbox_inches='tight')

    if not NO_PLOT:
        print('Plotting results...')
        plt.show()

    # raise bad exit code if the filter failed to converge
    if is_suppressed == False or is_within_error == False:
        exit(101)
    pass


if __name__ == '__main__':
    main()
    pass