import numpy as np

def approx(value, digits):
    # Accepts a single variable, unpack your array as necessary with:
    #     fixp(*list)
    if not hasattr(value, "__len__"):
        value = [value]
    return fixp2dec(*fixp(*value, digits=digits))

def fixp(*value, digits=np.inf):
    # Accepts multiple values, unpack your array as necessary with:
    #     fixp(*list)
    return [binary(v, digits) for v in value]

def binary(value, digits=np.inf):
    # The number of fractional digits wanted is always positive
    digits = abs(digits)

    # For now, ignore two's complement and just indicate positive or negative
    if value < 0:
        fixp = '-'
        value = abs(value)
    else:
        fixp = ''

    # Convert the whole number portion first
    if value >= 1:
        fixp += f"{int(value):b}."
        value -= int(value)
    else:
        fixp += "0."

    cur_val = 2.**-1
    end_val = 2.**-digits

    # Iteratively check all the bits down to the requested amount or floating
    #     point precision bit limit
    # While you could grab the bit values from the significand, this solution
    #     works for both 32 and 64 bit precision, as well as more precision in
    #     case Python automatically goes further than Double precision floating
    #     point
    while cur_val >= end_val and value > 0:
        if (value - cur_val >= 0):
            value -= cur_val
            fixp += "1"
        else:
            fixp += "0"

        cur_val /= 2.

    return fixp

def fixp2dec(*value, digits=np.inf):
    # Accepts multiple variables, unpack your array as necessary with:
    #     fixp2dec(*list, *list, digits=<>])
    return [unbinary(v, digits) for v in value]

def unbinary(value, digits=0):
    # The number of fractional digits wanted is always positive
    digits = abs(digits)

    # Split the number into whole and fractional bits
    whole, frac = value.split('.')

    # Convert the whole bits first
    decimal = float(abs(int(whole, 2)))

    # Convert the fractional bits
    frac_len = len(frac)
    if digits > 0 and frac_len > 0:
        if digits > frac_len:
            digits = frac_len

        # The resolution for how many digits were requested
        #     The ``value`` of each bit
        res = 2**-digits
        # The resolution times the required bits gives the fractional component
        #     ``value`` of each bit * decimal value for these bits
        decimal += int(frac[:digits], 2)*res

    if whole[0] == '-':
        decimal *= -1

    return decimal
