-- GNatives for Phantom Blade Zero (UE 5.7, PBZ.exe CL-302256).
-- Match: an inlined FFrame::Step (movzx ecx,byte[rax]; inc rax; mov [rdi+20h],rax;
-- mov r9,[r9+rcx*8]; ...; call r9) followed by lea r14,[rip+GNatives].
-- 36 of the 44 inlined Step sites load this same table; it is 0x800 bytes (256 natives).
function Register()
    return "0F B6 08 48 FF C0 48 89 47 20 4D 8B 0C C9 48 8B 4F 18 41 FF D1 4C 8D 35 ?? ?? ?? ??"
end

function OnMatchFound(MatchAddress)
    local LeaAddress = MatchAddress + 0x15
    local NextInstr = LeaAddress + 0x7
    local Offset = DerefToInt32(LeaAddress + 0x3)
    return NextInstr + Offset
end
