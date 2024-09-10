import numpy as np
from zplane import zplane
from dec_bin import bin_to_dec, decimal_to_fixed_point
b = [
    0.99998305179178714752197265625000000000000000000000000,
    -1.99996609846130013465881347656250000000000000000000000,
    0.99998305179178714752197265625000000000000000000000000
]

a = [
    1,
    -1.99996609846130013465881347656250000000000000000000000,
    0.99996610358357429504394531250000000000000000000000000
]


def direct(x, b, a):
    y_curr = [0]*len(x)
    for i, num in enumerate(x):
        #compute feedforward
        forward = 0
        for j, feedforward in enumerate((b)):
            if(i >= j):
                forward += feedforward * x[i-j]
        #compute feedback
        backward = 0
        for j, feedback in enumerate((a)):
            if(i >= j and j > 0):
                backward += feedback * y_curr[i-j]
        #compute y[i]
        y_curr[i] = forward - backward
    return y_curr 


def direct_binary(x, b, a, whole, frac):
    from dec_bin import binary
    x_approx = [binary.cast(n, whole, frac) for n in x]
    b_approx = [binary.cast(n, whole, frac) for n in b]
    #x_approx = [binary.cast(n, whole+4, frac) for n in x]
    #b_approx = [binary.cast(n, whole+4, frac) for n in b]
    a_approx = [binary.cast(-n, whole+4, frac) for n in a]

    y_curr = [0]*len(x_approx)
    y_curr = [binary.cast(0, whole+4, frac)]*len(x_approx)

    for i, num in enumerate(x_approx):
        #compute feedforward
        forward = binary.cast(0, whole+4, frac)
        for j, feedforward in enumerate((b_approx)):
            if(i >= j):
                #forward += feedforward * x_approx[i-j]
                forward += binary.mul_ext(feedforward, x_approx[i-j], 4)
        #compute feedback
        backward = binary.cast(0, whole+4, frac)
        for j, feedback in enumerate((a_approx)):
            if(i >= j):
                if(((j) == 3) or ((j) == 6)):
                    backward += feedback * y_curr[i-j]
                
        y_curr[i] = forward + backward
    return [binary.uncast(n,whole+4, frac) for n in y_curr] 



#need M=3
def scattered_lookahead(b,a, M):
    poles = np.roots(a)
    new_factors = np.array(list(np.power(poles, M)))
    added_poles = []
    for pole_power in new_factors:
        added_poles+=list(np.roots([1]+[0]*(M-1)+[-1*pole_power]))

    a_t = np.array(list(reversed(np.polynomial.polynomial.polyfromroots(added_poles))))

    quotient, remainder = np.polydiv(a_t, a)

    b_t = np.polymul(b, quotient)
    return (b_t, a_t) 


def main():
    t = np.array(range(0,500001))
    #impulse
    #x=[bin_to_dec("0111111111", 10)] + [0]*(500000)
    x=[511] + [0]*(500000)
    #x = 511*np.sin(np.pi*0.000012*2*t) 
    #x = 40*np.sin(np.pi*0.000012*2*t) + 25*np.cos(np.pi*0.000009*2*t)
    y1 = direct(x,b,a)

    (b_t, a_t) = scattered_lookahead(b,a,3)
    b_c = np.real(b_t)
    a_c = np.real(a_t)
    a_c[1] = 0
    a_c[2] = 0
    a_c[4] = 0
    a_c[5] = 0
    print(f"New coefficients without complex part and pipeline ready: \n    Feedforward: {b_c}\n     Feedback: {a_c}")
    y2 = direct(x, b_c, a_c)
    whole = 10 
    frac = 32

    print("Converting feedforward to bin")
    b_binary = []
    a_binary = []

    for i,num in enumerate(b_c):
        b_binary.append(decimal_to_fixed_point(num, whole, frac))
        print(f'b{i} : {b_binary[i]}')
    print("Converting feedback to bin")
    for i,num in enumerate(a_c):
        if(num != 0):
            a_binary.append(decimal_to_fixed_point(num, whole, frac))
            print(f'a{i} : {a_binary[-1]}')
    y3 = direct_binary(x, b_c, a_c, whole, frac)

    y4 = []
    with open("./Lookahead/Lookahead.sim/sim_1/behav/xsim/intermediate.txt", 'r') as file:
        for line in file:
            y4.append(bin_to_dec(line, whole+4))

    import matplotlib.pyplot as plt
    plt.figure()
    plt.plot(y1[1:], color='blue', label='Original')
    plt.plot(y2[1:], color="black", label="Transformed")
    plt.plot(y3[1:], color="green", label="Approximated Transformed")
    plt.plot(y4[1:], color="red", label="Hardware")
    plt.legend()
    plt.show()


    
    '''
    from scipy.signal import freqz
    f1 = np.abs(freqz(b, a))
    f2 = np.abs(freqz(b_t, a_t))
    f3 = np.abs(freqz(b_c, a_c))

    #omega = np.linspace(0, np.pi, 500000)  # Frequency grid
    #n = np.arange(0, len(y4))

    # Compute DTFT using the formula
    #f4 = np.absolute(np.array([np.sum(y4 * np.exp(-1j * w * n)) for w in omega]))
    f4 = np.abs(np.fft.fft(y1))
    plt.figure()
    plt.plot(f4, color="red", label='Hardware')
    plt.show()

    plt.figure()
    plt.plot(f1[0], abs(f1[1]), color='blue', label='Original')
    plt.plot(f2[0], abs(f2[1]), color="green", label='Transformed')
    plt.plot(f3[0], abs(f3[1]), color="black", label='Improved')
    plt.legend()
    plt.show()
    (z, p, k) = zplane(*(b,a))
    (z, p, k) = zplane(b_c, a_c)
    '''
    exit()
if __name__ == "__main__":
    main()
