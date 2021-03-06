Pack = {}

KEYBOARD_PRESS_WHEN_LIGHT = {"02 20 10 11 00 01 00 80 4E E3","02 20 10 12 00 01 00 80 0A E3","02 20 10 13 00 01 00 80 37 23","02 20 10 14 00 01 00 80 82 E3"}
KEYBOARD_PRESS = {"02 20 10 11 00 01 00 00 4f 43","02 20 10 12 00 01 00 00 0b 43","02 20 10 13 00 01 00 00 36 83","02 20 10 14 00 01 00 00 83 43"}
KEY_LIGHT_ON = {"02 06 10 21 00 01 1C F3","02 06 10 22 00 01 EC F3","02 06 10 23 00 01 BD 33","02 06 10 24 00 01 0C F2"}
KEY_LIGHT_OFF = {"02 06 10 21 00 00 DD 33","02 06 10 22 00 00 2D 33","02 06 10 23 00 00 7C F3","02 06 10 24 00 00 CD 32"}

PATTERN = "bbb>Hbb"

function Pack:create()
    local pack = {}

    function pack.head(data)
        local _,head=string.unpack(data,PATTERN)
        return head
    end

    function pack.cmd(data)
        local _,_,cmd=string.unpack(data,PATTERN)
        return cmd
    end

    function pack.sceneID(data)
        local _,_,_,_,sceneID=string.unpack(data,PATTERN)
        return sceneID
    end
 
    function pack.decode(data)
    	local pattern = "bbbbbbb"
        local _,_,_,_,extaddr,addr,state = string.unpack(data,pattern)

	   local device = {}
	   device.extaddr = extaddr
	   device.addr = addr
	   device.state = state
	   return device

    end

    function pack.keyHex(num)
	   return tohex(KEYBOARD_PRESS[num])
    end

    function pack.keyHexLight(num)
	   return tohex(KEYBOARD_PRESS_WHEN_LIGHT[num])
    end
    
    function pack.lightonHex(num)
	   return KEY_LIGHT_ON[num]
    end
    
    function pack.lightoffHex(num)
	   return KEY_LIGHT_OFF[num]
    end
    
    function pack.broadcastHex()
	   local a,b,c,d = string.match(C4:GetControllerNetworkAddress(),"(%d+).(%d+).(%d+).(%d+)")
	   local pattern = "bbbb>H"
	   return string.pack(pattern,tonumber(a),tonumber(b),tonumber(c),tonumber(d),SERVER_PORT)
    end

    function pack.update(cmd,devices)
    	local pattern = "bbb>Hbb"
    	local data = string.pack(pattern,cmd,3,deviceID,state)
    	local checksum = pack.checksum(data)
    	pattern = "bbb>Hbb"
    	return string.pack(pattern,VI_HEAD,cmd,3,deviceID,state,checksum)
    end
    
    function pack.decodeFresh(data)
    	local fresh = {}
	   local pattern = "bbb"
	   local _,_,_,length= string.unpack(data,pattern)
	   print("len:",length)
	   if length == 5 then
	   		pattern = "bbbbbbbbb"
	   		local _,_,_,_,addr,extaddr,action,_,value= string.unpack(data,pattern)
	   		fresh.length = length
	   		fresh.extaddr = extaddr
	   		fresh.addr = addr
	   		fresh.action = action
	   		fresh.value = value
	   		return fresh
	   end

	   if length == 4 then
	   		pattern = "bbbbbbbb"
	   		local _,_,_,_,addr,extaddr,action,value= string.unpack(data,pattern)
	   		fresh.length = length
	   		fresh.extaddr = extaddr
	   		fresh.addr = addr
	   		fresh.action = action
	   		fresh.value = value
	   		return fresh
	   end

	   return nil
    end
    
    function pack.decodeFreshFB(data)
	   local pattern = "bbbbbbbbbbbbbbbbbbb"
	   local _,_,_,_,_,mode,_,_,_,_,_,_,_,_,_,_,_,_,_,power= string.unpack(data,pattern)
	   if (mode==0x00) then return end
	   C4:SetVariable("FRESH_POWER", tostring(power==0x20))  
	   print(tostring(power==0x20))
    end
    
    function pack.decodeAirFB(data)
	   local pattern = "bbbbbbbbbbbbbbb"
	   local _,_,_,_,_,_,_,power,setemp,mode,speed,temp = string.unpack(data,pattern)
	   local air = {}
	   air.mode = mode
	   air.speed = speed
	   air.temp = temp
	   air.power = power
	   air.setemp = setemp
	   return air
    end

    function pack.decodeAir(data)
    	local pattern = "bbbbbbbbbb"
    	local _,_,_,extaddr,addr,_,state,mode,temp,speed= string.unpack(data,pattern)
	local air = {}
	air.extaddr = extaddr
	air.addr = addr
	air.state = state
	air.mode = mode
	air.temp = math.floor(temp/2)
	air.speed = speed
	return air
    end

    --feedback
    function pack.handleAddr(deviceid)
    	addr = deviceid % 256
    	extaddr = math.floor(deviceid / 256)
    	if addr>0xaf then
    		addr = addr % 0xaf
    		extaddr = extaddr + 10
    	end
    	return extaddr,addr
    end

    --control
    function pack.calcAddr( extaddr,addr )
    	if extaddr > 10 then
    		addr = addr + 0xaf
    		extaddr = extaddr - 10
    	end
    	return extaddr*256+addr
    end

    function pack.checksum(strPkt)
	   local cs = 0
	   string.gsub(strPkt, "(.)", function(c) cs = cs + string.byte(c) end)
	   return bit.band(cs, 0xff)
    end
    
    function pack.crc16(pmsg)
	   local crc_table = {
		   0x0000, 0xcc01, 0xd801, 0x1400,
		   0xf001, 0x3c00, 0x2800, 0xe401,
		   0xa001, 0x6c00, 0x7800, 0xb401,
		   0x5000, 0x9c01, 0x8801, 0x4400
	   }
	    local crc		= 0xffff
	    local i, temp

	    for i = 1,#pmsg do 
		    temp = string.byte(pmsg,i)
		    crc	 =  bit.bxor(crc_table[bit.band(bit.bxor(temp , crc) , 15)+1] , bit.rshift(crc , 4));
		    crc	 =  bit.bxor(crc_table[bit.band(bit.bxor(bit.rshift(temp , 4) , crc) , 15)+1] , bit.rshift(crc , 4));
	    end

	    local ret = string.format("%04x",crc):gsub("(..)(..)","%2%1")
	    return ret
    end
    
    return pack
end