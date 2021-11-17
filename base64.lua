
--https://github.com/kengonakajima/luvit-base64/issues/1

local base64 = {}

local ffi  = require'ffi'
local bit  = require'bit'
local shl  = bit.lshift
local shr  = bit.rshift
local bor  = bit.bor
local band = bit.band
local u8a  = ffi.typeof'uint8_t[?]'
local u8p  = ffi.typeof'uint8_t*'
local u16a = ffi.typeof'uint16_t[?]'
local u16p = ffi.typeof'uint16_t*'

local b64chars_s = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64chars = u8a(#b64chars_s + 1)
ffi.copy(b64chars, b64chars_s)

local b64digits = u16a(4096)
for j=0,63,1 do
	for k=0,63,1 do
		b64digits[j*64+k] = bor(shl(b64chars[k], 8), b64chars[j])
	end
end

local EQ = string.byte'='

function base64.encode(s, sn, dbuf, dn)

	local sn = sn or #s
	local min_dn = math.ceil(sn / 3) * 4
	local dn = dn or min_dn
	assert(dn >= min_dn, 'buffer too small')
	local dp  = dbuf and ffi.cast(u8p, dbuf) or u8a(dn)
	local sp  = ffi.cast(u8p, s)
	local dpw = ffi.cast(u16p, dp)
	local si = 0
	local di = 0

	while sn > 2 do
		local n = sp[si]
		n = shl(n, 8)
		n = bor(n, sp[si+1])
		n = shl(n, 8)
		n = bor(n, sp[si+2])
		local c1 = shr(n, 12)
		local c2 = band(n, 0x00000fff)
		dpw[di  ] = b64digits[c1]
		dpw[di+1] = b64digits[c2]
		sn = sn - 3
		di = di + 2
		si = si + 3
	end

	di = di * 2

	if sn > 0 then
		local c1 = shr(band(sp[si], 0xfc), 2)
		local c2 = shl(band(sp[si], 0x03), 4)
		if sn > 1 then
			si = si + 1
			c2 = bor(c2, shr(band(sp[si], 0xf0), 4))
		end
		dp[di  ] = b64chars[c1]
		dp[di+1] = b64chars[c2]
		di = di + 2
		if sn == 2 then
			local c3 = shl(band(sp[si], 0xf), 2)
			si = si + 1
			c3 = bor(c3, shr(band(sp[si], 0xc0), 6))
			dp[di] = b64chars[c3]
			di = di + 1
		end
		if sn == 1 then
			dp[di] = EQ
			di = di + 1
		end
		dp[di] = EQ
	end

	assert(di == dn-1)

	if dbuf then
		return dp, dn
	else
		return ffi.string(dp, dn)
	end
end

if not ... then
	local clock = require'time'.clock
	local b64 = require'libb64'
	local s=''
	for i=1,1000 do s = s .. '0123456789' end
	local n = 50000

	local st = clock()
	local encoded1
	for i=1,n do
		encoded1 = base64.encode(s)
	end
	local et = clock()
	local dt =(et-st)
	print('Lua len:',#s,'n:',n,dt,'sec', (#s*n)/dt/1024.0/1024.0, 'MB/s' )

	local st = clock()
	local encoded2
	for i=1,n do
		encoded2 = b64.encode(s)
	end
	local et = clock()
	local dt =(et-st)
	print('C   len:',#s,'n:',n,dt,'sec', (#s*n)/dt/1024.0/1024.0, 'MB/s' )

	assert(encode1 == encode2)
end


return base64
