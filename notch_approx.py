# Modified from the interactive plot example at https://stackoverflow.com/a/6697555
import pickle
import scipy
import matplotlib.pyplot as plt
import numpy as np
from numpy import pi, sin
from matplotlib.widgets import Slider, Button, RadioButtons
from fixedpoint import approx

def approx_filter(fs, w, num, den, dig):
    _num = approx(num, dig)
    _den = approx(den, dig)

    [print(f"{dig:2}'num[{i}] = {n:56.53f}") for i,n in enumerate(_num)]
    [print(f"{dig:2}'den[{i}] = {d:56.53f}") for i,d in enumerate(_den)]
    print()

    sys = scipy.signal.TransferFunction(_num, _den, dt=1/fs)
    w, mag, phase = scipy.signal.dbode(sys, w=w)

    return mag

fig = plt.figure()
ax = fig.add_subplot(111)

# Adjust the subplots region to leave some space for the sliders and buttons
fig.subplots_adjust(bottom=0.25)

digit = 32 

# Filter 1:
#fs = 10e6
#f0 = 60
#bw = 20
#q = f0/bw
#num, den = scipy.signal.iirnotch(f0, q, fs=fs)

## cheby2 high pass not as good attenuation at 50-60 Hz
#fs = 5e6
#f_hi = 80
#num, den = scipy.signal.cheby2(1, 3, f_hi, fs=fs, btype='highpass')

## Butter example from https://dsp.stackexchange.com/a/49435
## Butter reference from https://docs.scipy.org/doc/scipy/reference/generated/scipy.signal.butter.html
#fs = 5e6
#f_lo = 50
#f_hi = 70
#num, den = scipy.signal.butter(1, [f_lo, f_hi], fs=fs, btype='bandstop')

# cheby2 Good stuff
fs = 5e6
f_lo = 54
f_hi = 61

from lookahead import scattered_lookahead



#num =  [ 0.99998305, -0.0000339,  -0.00003389, -1.99989827,  0.0000339,  0.00003389, 0.99991526]
#den=  [ 1,          0,          0,         -1.99989827,  0, 0, 0.99989831]

num, den = scipy.signal.cheby2(1, 12, [f_lo, f_hi], fs=fs, btype='bandstop')
num, den = np.real(scattered_lookahead(num, den, 3))

den[1]=0
den[2]=0
den[4]=0
den[5]=0

'''
from fixedpoint import fixp
from dec_bin import decimal_to_fixed_point 
[print(f"{decimal_to_fixed_point(n, 10, digit)}") for i,n in enumerate(num)]
print("--------------------")
[print(f"{decimal_to_fixed_point(d, 10, digit)}") for i,d in enumerate(den)]
'''

[print(f"num[{i}] = {n:56.53f}") for i,n in enumerate(num)]
[print(f"den[{i}] = {d:56.53f}") for i,d in enumerate(den)]
print()

## cheby2
#fs = 5e6
#f_lo = 1
#f_hi = 60
#num, den = scipy.signal.cheby2(2, 30, [f_lo, f_hi], fs=fs, btype='highpass')

w = np.linspace(0, np.pi, num=2**int(fs).bit_length())

# Draw the initial plot
# The 'line' variable is used for modifying the line later
[line] = ax.semilogx(fs*w/np.pi/2, approx_filter(fs, w, num, den, digit))
ax.set_ylim([-100, 20])

plt.show()