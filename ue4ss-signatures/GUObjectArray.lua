-- GUObjectArray for Phantom Blade Zero (UE 5.7, PBZ.exe CL-302256).
-- Match: mov rax,[rip+ObjObjects.Objects]; mov rcx,[rax+rcx*8]; lea rax,[rcx+rdx*8]
-- (the inlined FChunkedFixedUObjectArray::GetObjectPtr; 309 sites, all the same target).
-- In this build ObjObjects starts at +0x10 but its Objects pointer is at ObjObjects+0x8
-- (MaxChunks/NumChunks come first), so Objects sits at GUObjectArray+0x18.
-- Verified in live memory; see ue4ss-config/MemberVariableLayout.ini.
function Register()
    return "48 8B 05 ?? ?? ?? ?? 48 8B 0C C8 48 8D 04 D1"
end

function OnMatchFound(MatchAddress)
    local NextInstr = MatchAddress + 0x7
    local Offset = DerefToInt32(MatchAddress + 0x3)
    return NextInstr + Offset - 0x18
end
