-- 递归列出 TreeProbeMac 窗口里每个 AX 元素："role,x,y,w,h"（屏幕坐标）。
on walk(e)
	set out to ""
	tell application "System Events"
		try
			set p to position of e
			set z to size of e
			set out to out & (role of e) & "," & (item 1 of p) & "," & (item 2 of p) & "," & (item 1 of z) & "," & (item 2 of z) & linefeed
		end try
		try
			repeat with c in (UI elements of e)
				set out to out & my walk(c)
			end repeat
		end try
	end tell
	return out
end walk
tell application "System Events" to tell process "TreeProbeMac" to set w to window 1
return walk(w)
