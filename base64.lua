
local base64 = {}

local ffi = require'ffi'
local bit = require'bit'
local shl = bit.lshift
local shr = bit.rshift
local bor = bit.bor
local band = bit.band

local base64_table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64chars = ffi.new('char[?]', #base64_table+1)
ffi.copy(b64chars, base64_table)

-- calculate LUT
local b64digits = ffi.new('short[?]', 4096)
for j=0,63,1 do
	for k=0,63,1 do
		b64digits[j*64+k] = bor(shl(b64chars[k], 8), b64chars[j])
	end
end

local EQ = string.byte'='

function base64.encode(data)

	local nLenSrc = #data
	local nLenOut = math.floor((nLenSrc+2)/3)*4
	local pDst = ffi.new('char[?]', nLenOut+1)
	local pSrc = ffi.new('char[?]', nLenSrc+1)
	ffi.copy(pSrc, data)
	local pwDst = ffi.cast('short*', pDst)
	local sCnt = 0
	local dCnt = 0

	while( nLenSrc > 2) do
		local n = pSrc[sCnt]
		n = shl(n, 8)
		n = bor(n, pSrc[sCnt+1])
		n = shl(n, 8)
		n = bor(n, pSrc[sCnt+2])
		local n1 = shr(n, 12)
		local n2 = band(n, 0x00000fff)
		pwDst[dCnt  ] = b64digits[n1]
		pwDst[dCnt+1] = b64digits[n2]
		nLenSrc = nLenSrc - 3
		dCnt = dCnt + 2
		sCnt = sCnt + 3
	end

	dCnt = dCnt * 2

	if nLenSrc > 0 then
		local n1 = shr(band(pSrc[sCnt], 0xfc),2)
		local n2 = shl(band(pSrc[sCnt], 0x03),4)
		if nLenSrc > 1 then
			sCnt = sCnt + 1
			n2 = bor(n2, shr(band(pSrc[sCnt], 0xf0),4))
		end
		pDst[dCnt  ] = b64chars[n1]
		pDst[dCnt+1] = b64chars[n2]
		dCnt = dCnt + 2
		if nLenSrc == 2 then
			local n3 = shl(band(pSrc[sCnt], 0xf),2)
			sCnt = sCnt + 1
			n3 = bor(n3, shr(band(pSrc[sCnt], 0xc0),6))
			pDst[dCnt] = b64chars[n3]
			dCnt = dCnt + 1
		end
		if nLenSrc == 1 then
			pDst[dCnt] = EQ
			dCnt = dCnt + 1
		end
		pDst[dCnt] = EQ
	end
	return ffi.string(pDst, nLenOut)
end


if not ... then
	local clock = require'time'.clock
	local s=''
	for i=1,1000 do s = s .. '0123456789' end
	local n = 50000
	local st = clock()
	local encoded
	for i=1,n do
		encoded = base64.encode(s)
	end
	local et = clock()
	local dt =(et-st)
	print('bench-enc len:',#s,'n:',n,dt,'sec', (#s*n)/dt/1024.0/1024.0, 'MB/s' )
end


return base64
