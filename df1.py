# Script: df1.py
#
# Performs a software simulation of the proposed notch filter to measure the
# impulse response against the ideal case.

from fixedpoint import approx
import numpy as np
import matplotlib.pyplot as plt
import argparse

# coefficients
B = [
    0.99998305179178714752197265625000000000000000000000000,
    -1.99996609846130013465881347656250000000000000000000000,
    0.99998305179178714752197265625000000000000000000000000
]

A = [
    1,
    -1.99996609846130013465881347656250000000000000000000000,
    0.99996610358357429504394531250000000000000000000000000
]


def df1(num, den, sample):
    x_ff = np.zeros(3)
    y_ff = np.zeros(3)

    for x in sample:
        # Propagate x
        x_ff[2] = x_ff[1]
        x_ff[1] = x_ff[0]
        x_ff[0] = x

        # Propagate y
        y_ff[2] = y_ff[1]
        y_ff[1] = y_ff[0]

        # Calculate result
        y_ff[0] = num[0]*x_ff[0] + num[1]*x_ff[1] + num[2]*x_ff[2] - den[1]*y_ff[1] - den[2]*y_ff[2]

        # Return value
        yield y_ff[0]


def dut_df1(b, a, sample, frac_bits):
    x_ff = np.zeros(3)
    y_ff = np.zeros(3)
    num = approx(b, frac_bits)
    den = approx(a, frac_bits)

    for x in sample:
        # Propagate x
        x_ff[2] = x_ff[1]
        x_ff[1] = x_ff[0]
        x_ff[0] = x

        # Propagate y
        y_ff[2] = y_ff[1]
        y_ff[1] = y_ff[0]

        # Calculate result
        y_ff[0] = num[0]*x_ff[0] + num[1]*x_ff[1] + num[2]*x_ff[2] - den[1]*y_ff[1] - den[2]*y_ff[2]

        # Return value
        yield y_ff[0]


def approx_all_dut_df1(b, a, sample, frac_bits):
    x_ff = np.zeros(3)
    y_ff = np.zeros(3)
    num = approx(b, frac_bits)
    den = approx(a, frac_bits)

    for x in sample:
        # Propagate x
        x_ff[2] = x_ff[1]
        x_ff[1] = x_ff[0]
        x_ff[0] = x

        # Propagate y
        y_ff[2] = y_ff[1]
        y_ff[1] = y_ff[0]

        # Calculate result
        y_ff[0] = approx(approx(num[0]*x_ff[0],frac_bits)[0] + approx(num[1]*x_ff[1],frac_bits)[0] + approx(num[2]*x_ff[2],frac_bits)[0] - approx(den[1]*y_ff[1],frac_bits)[0] - approx(den[2]*y_ff[2],frac_bits)[0], frac_bits)[0]

        # Return value
        yield y_ff[0]


def main():

    parser = argparse.ArgumentParser()

    # parser.add_argument('file', action='store', type=str, help='path to impulse data')
    parser.add_argument('--frac-bits', action='store', type=int, default=32, help='number of fractional bits')
    parser.add_argument('--num-samples', action='store', type=int, default=int(1e6), help='number of samples')
    parser.add_argument('--plot-xl', action='store_true', help='use enlarged settings to display plot')

    args = parser.parse_args()

    IS_PLOT_XL = bool(args.plot_xl)
    FRAC_BITS = int(args.frac_bits)
    NUM_SAMPLES = int(args.num_samples)

    SAMPLING_FREQ = int(5e6)

    inp = np.zeros(NUM_SAMPLES)
    inp[0] = (2**(10-1))-1

    print('Running simulation for ideal model...')
    gld_res = np.fromiter(df1(B, A, inp), float, inp.size)
    print('Running simulation for approximation (only coefficients)...')
    dut_res = np.fromiter(dut_df1(B, A, inp, FRAC_BITS), float, inp.size)
    print('Running simulation for approximation (everything)...')
    approx_dut_res = np.fromiter(approx_all_dut_df1(B, A, inp, FRAC_BITS), float, inp.size)

    print('Analyzing results...')
    print(f'''
Mean squared error:
Gold vs Approx only coefficients -- {np.square(gld_res - dut_res).mean()}
Gold vs Approx everything        -- {np.square(gld_res - approx_dut_res).mean()}
    ''')

    print('Plotting results...')
    fig, ax = plt.subplots(1,1)

    x = np.linspace(0, NUM_SAMPLES/SAMPLING_FREQ, NUM_SAMPLES)
    ax.plot(x[1:], gld_res[1:], label="gold")
    ax.plot(x[1:], dut_res[1:], label="approx coeff")
    ax.plot(x[1:], approx_dut_res[1:], label="approx all")

    ax.legend()
    ax.set_title("Impulse Response")
    ax.set_xlabel("Seconds")
    ax.set_ylabel("Value")

    if IS_PLOT_XL == True:
        fig.set_size_inches(16, 9, forward=True)
        fig.set_dpi(600)
        plt.tight_layout()
    
    plt.savefig("df1_plots.png", dpi=fig.dpi, bbox_inches='tight')

    plt.show()


if __name__ == '__main__':
    main()
    pass