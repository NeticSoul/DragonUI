-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Plain arithmetic on doubles only: the client's bit library differs from LuaJIT on values >= 2^31.

local addon = select(2, ...)

local floor = math.floor
local byte, char, rep, concat = string.byte, string.char, string.rep, table.concat

-- Public halves of the release keys; the private keys never enter this repository.
local KEYS = {
    { modulus = "9A83DA6FCC7F54B885D44739F15DD04BD8DFB51FD0BC0A7355B7A98CFB00D04B2C9C692580D71517C3E55B7964E7635F23666A49A8BE54A4330360B7A9E0114F93ABA3CE486027502C297A38A68D507ECF2FDABF421EC18E99D66160B087C05611BC2164D84357776A0B68155655AEB8FAFA3B1E265FAC8E82A0F5921FA33341", exponent = 65537 },
    { modulus = "98F130FC45F261F39364292C26CF1F9092E66FDE5CA7A9684C8A848AE5FA3C314BAA577144EA726A0A656986AF7362714FE87D36858EB601A446B3F6DD03AA7CAF17F73C2D83EF26B35F3ED5D7B2FA68AC215EB3D94528C7FDDBD5EF83F21ACF9A9CB177D5B54158891632FB5F2DD72D25DA6BB379C37C40C5E7A98BB535CF45", exponent = 65537 },
}

local MESSAGE_PREFIX = "DragonUI-release:"

-- ============================================================================
-- 32-bit WORD OPERATIONS
-- ============================================================================

local TWO32 = 4294967296
local POW2 = {}
for i = 0, 32 do
    POW2[i] = 2 ^ i
end

local XOR4, AND4 = {}, {}
for a = 0, 15 do
    for b = 0, 15 do
        local x, y, xr, ar, p = a, b, 0, 0, 1
        for _ = 1, 4 do
            local xa, yb = x % 2, y % 2
            if xa ~= yb then xr = xr + p end
            if xa + yb == 2 then ar = ar + p end
            x, y, p = (x - xa) / 2, (y - yb) / 2, p * 2
        end
        XOR4[a * 16 + b] = xr
        AND4[a * 16 + b] = ar
    end
end

local function bitop(t, a, b)
    local r, p = 0, 1
    for _ = 1, 8 do
        local na, nb = a % 16, b % 16
        r = r + t[na * 16 + nb] * p
        a, b, p = (a - na) / 16, (b - nb) / 16, p * 16
    end
    return r
end

local function bxor(a, b) return bitop(XOR4, a, b) end
local function band(a, b) return bitop(AND4, a, b) end

local function rotr(x, n)
    local lo = x % POW2[n]
    return (x - lo) / POW2[n] + lo * POW2[32 - n]
end

local function shr(x, n)
    return (x - x % POW2[n]) / POW2[n]
end

-- ============================================================================
-- SHA-256
-- ============================================================================

local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function SHA256(msg)
    local len = #msg
    local bits = len * 8
    local tail = {}
    for i = 7, 0, -1 do
        tail[#tail + 1] = char(floor(bits / 256 ^ i) % 256)
    end
    msg = msg .. "\128" .. rep("\0", (55 - len) % 64) .. concat(tail)

    local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    local w = {}

    for chunk = 1, #msg, 64 do
        for i = 0, 15 do
            local b1, b2, b3, b4 = byte(msg, chunk + i * 4, chunk + i * 4 + 3)
            w[i] = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
        end
        for i = 16, 63 do
            local x, y = w[i - 15], w[i - 2]
            local s0 = bxor(bxor(rotr(x, 7), rotr(x, 18)), shr(x, 3))
            local s1 = bxor(bxor(rotr(y, 17), rotr(y, 19)), shr(y, 10))
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % TWO32
        end

        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
        for i = 0, 63 do
            local S1 = bxor(bxor(rotr(e, 6), rotr(e, 11)), rotr(e, 25))
            local ch = bxor(band(e, f), band(TWO32 - 1 - e, g))
            local t1 = (h + S1 + ch + K[i + 1] + w[i]) % TWO32
            local S0 = bxor(bxor(rotr(a, 2), rotr(a, 13)), rotr(a, 22))
            local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
            local t2 = (S0 + maj) % TWO32
            h, g, f, e, d, c, b, a = g, f, e, (d + t1) % TWO32, c, b, a, (t1 + t2) % TWO32
        end

        h0, h1, h2, h3 = (h0 + a) % TWO32, (h1 + b) % TWO32, (h2 + c) % TWO32, (h3 + d) % TWO32
        h4, h5, h6, h7 = (h4 + e) % TWO32, (h5 + f) % TWO32, (h6 + g) % TWO32, (h7 + h) % TWO32
    end

    local out = {}
    for _, v in ipairs({ h0, h1, h2, h3, h4, h5, h6, h7 }) do
        for i = 3, 0, -1 do
            out[#out + 1] = char(floor(v / POW2[8 * i]) % 256)
        end
    end
    return concat(out)
end

-- ============================================================================
-- BIG INTEGERS (24-bit limbs, little-endian, index 0 first)
-- ============================================================================

-- 24-bit limbs keep every partial product + carry below 2^53, where doubles stay exact.
local BASE = 16777216

local function BytesToLimbs(s, count)
    local k, t = #s, {}
    for i = 0, count - 1 do
        local p, v = k - 3 * i, 0
        for q = p - 2, p do
            v = v * 256 + ((q >= 1 and q <= k) and byte(s, q) or 0)
        end
        t[i] = v
    end
    return t
end

local function LimbsToBytes(t, count, k)
    local out = {}
    for i = 0, count - 1 do
        local v = t[i]
        for j = 0, 2 do
            local bv = v % 256
            v = (v - bv) / 256
            local pos = k - 3 * i - j
            if pos >= 1 then
                out[pos] = char(bv)
            elseif bv ~= 0 then
                return nil
            end
        end
    end
    return concat(out, "", 1, k)
end

local function Compare(a, b, count)
    for i = count - 1, 0, -1 do
        if a[i] ~= b[i] then
            return a[i] > b[i] and 1 or -1
        end
    end
    return 0
end

-- a := a - b, assuming a >= b once the extra top limb a[count] is included.
local function SubtractInPlace(a, b, count)
    local borrow = 0
    for i = 0, count - 1 do
        local x = a[i] - b[i] - borrow
        if x < 0 then
            a[i], borrow = x + BASE, 1
        else
            a[i], borrow = x, 0
        end
    end
    a[count] = (a[count] or 0) - borrow
end

-- Montgomery product a*b/R mod n (CIOS), R = BASE^count.
local function MontMul(a, b, key)
    local n, ninv, s = key.n, key.ninv, key.count
    local t = {}
    for i = 0, s + 1 do t[i] = 0 end

    for i = 0, s - 1 do
        local bi, c = b[i], 0
        for j = 0, s - 1 do
            local x = t[j] + a[j] * bi + c
            c = floor(x / BASE)
            t[j] = x - c * BASE
        end
        local x = t[s] + c
        c = floor(x / BASE)
        t[s] = x - c * BASE
        t[s + 1] = c

        local m = (t[0] * ninv) % BASE
        c = 0
        for j = 0, s - 1 do
            x = t[j] + m * n[j] + c
            c = floor(x / BASE)
            t[j] = x - c * BASE
        end
        x = t[s] + c
        c = floor(x / BASE)
        t[s] = x - c * BASE
        t[s + 1] = t[s + 1] + c

        for j = 0, s do
            t[j] = t[j + 1]
        end
        t[s + 1] = 0
    end

    if t[s] ~= 0 or Compare(t, n, s) >= 0 then
        SubtractInPlace(t, n, s)
    end
    t[s], t[s + 1] = nil, nil
    return t
end

local function ParseHex(hex)
    if type(hex) ~= "string" or #hex % 2 ~= 0 or hex:find("[^%x]") then
        return nil
    end
    local out = {}
    for i = 1, #hex, 2 do
        out[#out + 1] = char(tonumber(hex:sub(i, i + 1), 16))
    end
    return (concat(out):gsub("^%z+", ""))
end

local preparedKeys = {}

local function PrepareKey(modulusHex, exponent)
    local cached = preparedKeys[modulusHex]
    if cached then return cached end

    local nBytes = ParseHex(modulusHex)
    if not nBytes or #nBytes < 64 or byte(nBytes, #nBytes) % 2 == 0 then
        return nil
    end
    local k = #nBytes
    local count = floor((k * 8 + 23) / 24)
    local n = BytesToLimbs(nBytes, count)

    -- Newton iteration for n0^-1 mod 2^24; each step doubles the correct low bits (3 -> 48).
    local n0, inv = n[0], n[0]
    for _ = 1, 5 do
        local t = (n0 * inv) % BASE
        inv = (inv * ((2 - t) % BASE)) % BASE
    end
    local key = { n = n, count = count, k = k, exponent = exponent, ninv = (BASE - inv) % BASE }

    -- R^2 mod n by doubling from the highest power of two below n.
    local bitLen = 8 * (k - 1)
    local top = byte(nBytes, 1)
    while top > 0 do
        bitLen, top = bitLen + 1, floor(top / 2)
    end
    local r = {}
    for i = 0, count do r[i] = 0 end
    local startBit = bitLen - 1
    r[floor(startBit / 24)] = POW2[startBit % 24]
    for _ = 1, 2 * 24 * count - startBit do
        local c = 0
        for i = 0, count - 1 do
            local x = r[i] * 2 + c
            if x >= BASE then
                r[i], c = x - BASE, 1
            else
                r[i], c = x, 0
            end
        end
        r[count] = c
        if c ~= 0 or Compare(r, n, count) >= 0 then
            SubtractInPlace(r, n, count)
        end
        r[count] = 0
    end
    r[count] = nil
    key.r2 = r

    preparedKeys[modulusHex] = key
    return key
end

local function ModPow(base, key)
    local one = { [0] = 1 }
    for i = 1, key.count - 1 do one[i] = 0 end

    local bm = MontMul(base, key.r2, key)
    local e, bitsOfE = key.exponent, {}
    while e > 0 do
        local bit = e % 2
        bitsOfE[#bitsOfE + 1] = bit
        e = (e - bit) / 2
    end
    local x = bm
    for i = #bitsOfE - 1, 1, -1 do
        x = MontMul(x, x, key)
        if bitsOfE[i] == 1 then
            x = MontMul(x, bm, key)
        end
    end
    return MontMul(x, one, key)
end

-- ASN.1 DigestInfo header for SHA-256 (RFC 8017, section 9.2 note 1).
local DIGEST_INFO = "\48\49\48\13\6\9\96\134\72\1\101\3\4\2\1\5\0\4\32"

local function VerifyWithKey(modulusHex, exponent, message, signature)
    local key = PrepareKey(modulusHex, exponent)
    if not key or type(signature) ~= "string" or #signature ~= key.k then
        return false
    end
    local s = BytesToLimbs(signature, key.count)
    if Compare(s, key.n, key.count) >= 0 then
        return false
    end
    local em = LimbsToBytes(ModPow(s, key), key.count, key.k)
    local padLength = key.k - 3 - #DIGEST_INFO - 32
    if not em or padLength < 8 then
        return false
    end
    return em == "\0\1" .. rep("\255", padLength) .. "\0" .. DIGEST_INFO .. SHA256(message)
end

-- ============================================================================
-- BASE64
-- ============================================================================

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_VALUE = {}
for i = 1, 64 do
    B64_VALUE[byte(B64, i)] = i - 1
end

local function DecodeBase64(str)
    if type(str) ~= "string" then return nil end
    str = str:gsub("=+$", "")
    local out, acc, accBits = {}, 0, 0
    for i = 1, #str do
        local v = B64_VALUE[byte(str, i)]
        if not v then return nil end
        acc, accBits = acc * 64 + v, accBits + 6
        if accBits >= 8 then
            accBits = accBits - 8
            local b = floor(acc / POW2[accBits])
            out[#out + 1] = char(b)
            acc = acc - b * POW2[accBits]
        end
    end
    return concat(out)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

addon.ReleaseSignature = {
    KEY_COUNT = #KEYS,
    MESSAGE_PREFIX = MESSAGE_PREFIX,
    SHA256 = SHA256,
    DecodeBase64 = DecodeBase64,
    VerifyWithKey = VerifyWithKey,

    -- True only if `signatureBase64` is the release key `keyIndex` signing `version`.
    Verify = function(keyIndex, version, signatureBase64)
        local key = KEYS[keyIndex]
        if not key or type(version) ~= "string" then
            return false
        end
        return VerifyWithKey(key.modulus, key.exponent, MESSAGE_PREFIX .. version, DecodeBase64(signatureBase64))
    end,
}
