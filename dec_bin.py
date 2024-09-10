#assumes 2's comp
def decimal_to_fixed_point(decimal_number, integer_bits, fractional_bits):
    #fixed_point_value = int(round(decimal_number * (2 ** fractional_bits)))
    fixed_point_value = int(decimal_number * (2 ** fractional_bits))
    
    total_bits = integer_bits + fractional_bits
    
    if fixed_point_value < 0:
        fixed_point_value = (1 << total_bits) + fixed_point_value
    
    binary_representation = format(fixed_point_value & ((1 << total_bits) - 1), f'0{total_bits}b')
    return binary_representation


#assumes 2's comp
def bin_to_dec(binary_number: str, integer_bits):
    if(binary_number[0] == '1'):
        decimal_number = -1*(1<<integer_bits)
    else:
        decimal_number = 0.0
    power = 1<<(integer_bits-1)

    for s in binary_number:
        if(s=='1'):
            decimal_number += power
        #performs floating point arithmetic for this step
        power/=2
    return decimal_number

class binary:
    def __init__(self, x, whole, frac):
        fixed_point= int(x* (1<<frac))
    
        total_bits = whole + frac 
    
        if fixed_point < 0:
            fixed_point = (1 << total_bits) + fixed_point

        self.fixed_point = fixed_point & ((1 << total_bits) - 1)
        self.whole = whole
        self.frac = frac

    def __add__(self, other):
        out = binary(self.fixed_point + other.fixed_point, self.whole+self.frac, 0)
        out.whole = self.whole
        out.frac =  self.frac
        return out
    def __sub__(self, other):
        out = binary(self.fixed_point - other.fixed_point, self.whole+self.frac, 0)
        out.whole = self.whole
        out.frac =  self.frac
        return out
    def __mul__(self, other):
        left = self.fixed_point
        right = other.fixed_point
        #sign extend
        if(right >= (1<<(self.whole+self.frac-1))):
            right |= ((1<<(self.whole+self.frac + other.whole+other.frac)) - (1<<(self.whole+self.frac)))

        if(left >= (1<<(other.whole+other.frac-1))):
            left |= ((1<<(self.whole+self.frac + other.whole+other.frac)) - (1<<(other.whole+other.frac)))

        #capture in larger binary object
        out = binary(left*right, self.whole+self.frac+other.whole+other.frac, 0)
        out.whole = self.whole
        out.frac = self.frac

        #concatenate and format
        out.fixed_point = (out.fixed_point >> out.frac) & ((1<<(out.whole+out.frac))-1)
        return out
    def mul_ext(a, b, ext):
        left = a.fixed_point
        right = b.fixed_point
        #sign extend
        if(right >= (1<<(a.whole+a.frac-1))):
            right |= ((1<<(a.whole+a.frac + b.whole+b.frac)) - (1<<(a.whole+a.frac)))

        if(left >= (1<<(b.whole+b.frac-1))):
            left |= ((1<<(a.whole+a.frac + b.whole+b.frac)) - (1<<(b.whole+b.frac)))

        #capture in larger binary object
        out = binary(left*right, a.whole+a.frac+b.whole+b.frac, 0)
        out.whole = a.whole+ext
        out.frac = a.frac

        #concatenate and format
        out.fixed_point = (out.fixed_point >> out.frac) & ((1<<(out.whole+out.frac))-1)
        return out
    
    def cast(x, whole, frac): 
        return binary(x,whole,frac)

    def uncast(b, whole, frac):
        b = b.fixed_point
        if(b & (1<<(whole+frac-1))):
            b = b - (1<<(whole+frac))
        decimal = b / (1<<frac) 
        return decimal

k=0.9999830517917871
a = decimal_to_fixed_point(k, 10, 54)
b = bin_to_dec(a, 10)

print(k)
print(a)

print(b)
k = binary(k, 10, 54)
binary.uncast(k, 10, 54)


a = binary(-2,4,2)
b = binary(3.3,4,2)
print(binary.uncast(a, a.whole,a.frac))
print(binary.uncast(b, b.whole,b.frac))
print(binary.uncast(a*b, a.whole,a.frac))
#cast floating point to int type for computation
def cast(x, whole, frac): 
    print(decimal_to_fixed_point(x, whole, frac))
    return int(decimal_to_fixed_point(x, whole, frac),2)

#cast int to floating point
def uncast(x, whole, frac):
    print(decimal_to_fixed_point(x, whole+frac, 0))
    return bin_to_dec(decimal_to_fixed_point(x, whole+frac, 0), whole)

