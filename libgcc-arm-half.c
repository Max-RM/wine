/*
 * ARM half-float helpers missing from Wine's libcompiler-rt.a on ARM32 PE.
 *
 * Link error this fixes:
 *   ld.lld: error: undefined symbol: __gnu_h2f_ieee
 *   >>> referenced by libavutil/half2float.h (ffmpeg, colorcnv.dll)
 *
 * Build (inside the Wine 11 armhf build env):
 *   armv7-w64-mingw32-clang -c -O2 -o h2f.o libgcc-arm-half.c
 *   llvm-ar rc /usr/armv7-w64-mingw32/lib/libgcc.a h2f.o
 * and add -lgcc to the clang wrapper (after "$@").
 */
#include <stdint.h>

float __gnu_h2f_ieee(uint16_t h)
{
    uint32_t sign = (uint32_t)(h & 0x8000) << 16;
    uint32_t exp  = (h >> 10) & 0x1f;
    uint32_t mant = h & 0x3ff;
    uint32_t f;

    if (exp == 0)
    {
        if (mant == 0) f = sign;
        else
        {
            exp = 127 - 15 + 1;
            while (!(mant & 0x400)) { mant <<= 1; exp--; }
            mant &= 0x3ff;
            f = sign | (exp << 23) | (mant << 13);
        }
    }
    else if (exp == 31)
        f = sign | 0x7f800000u | (mant << 13);
    else
        f = sign | ((exp + 127 - 15) << 23) | (mant << 13);

    { union { uint32_t u; float f; } u; u.u = f; return u.f; }
}

uint16_t __gnu_f2h_ieee(float x)
{
    union { float f; uint32_t u; } u;
    uint32_t sign, mant;
    int32_t exp, e;

    u.f = x;
    sign = (u.u >> 16) & 0x8000;
    exp  = (u.u >> 23) & 0xff;
    mant = u.u & 0x7fffff;

    if (exp == 0xff) return (uint16_t)(sign | 0x7c00 | (mant ? 0x200 : 0));

    e = exp - 127 + 15;
    if (e >= 31) return (uint16_t)(sign | 0x7c00);
    if (e <= 0)
    {
        int shift;
        uint32_t m, rem, half;

        if (e < -10) return (uint16_t)sign;
        mant |= 0x800000;
        shift = 14 - e;
        m = mant >> shift;
        rem = mant & ((1u << shift) - 1);
        half = 1u << (shift - 1);
        if (rem > half || (rem == half && (m & 1))) m++;
        return (uint16_t)(sign | m);
    }

    {
        uint32_t m = mant >> 13;
        uint32_t rem = mant & 0x1fff;

        if (rem > 0x1000 || (rem == 0x1000 && (m & 1)))
        {
            m++;
            if (m == 0x400) { m = 0; e++; if (e >= 31) return (uint16_t)(sign | 0x7c00); }
        }
        return (uint16_t)(sign | (e << 10) | m);
    }
}
