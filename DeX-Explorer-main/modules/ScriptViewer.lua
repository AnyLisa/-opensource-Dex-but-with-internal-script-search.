--[[
	Script Viewer App Module
	
	A script viewer that is basically a notepad
]]
-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, ScriptViewer, Notebook -- Major Apps
local API,RMD,env,service,plr,create,createSimple -- Main Locals

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings

	API = data.API
	RMD = data.RMD
	env = data.env
	service = data.service
	plr = data.plr
	create = data.create
	createSimple = data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	Properties = Apps.Properties
	ScriptViewer = Apps.ScriptViewer
	Notebook = Apps.Notebook
end

local executorName = "Unknown"
local executorVersion = "???"
if identifyexecutor then
	local name,ver = identifyexecutor()
	executorName = name
	executorVersion = ver
elseif game:GetService("RunService"):IsStudio() then
	executorName = "Studio"
	executorVersion = version()
end

local function getPath(obj)
	if obj.Parent == nil then
		return "Nil parented"
	else
		return Explorer.GetInstancePath(obj)
	end
end

local function main()
	local ScriptViewer = {}
	local window, codeFrame
	
	local execute, clear, dumpbtn
	
	local PreviousScr = nil
	
	ScriptViewer.DumpFunctions = function(scr)
		-- thanks King.Kevin#6025 you'll obviously be credited (no discord tag since that can easily be impersonated)
		local getgc = getgc or get_gc_objects
		local getupvalues = (debug and debug.getupvalues) or getupvalues or getupvals
		local getconstants = (debug and debug.getconstants) or getconstants or getconsts
		local getinfo = (debug and (debug.getinfo or debug.info)) or getinfo
		local original = ("\n-- // Function Dumper made by King.Kevin\n-- // Script Path: %s\n\n--[["):format(getPath(scr))
		local dump = original
		local functions, function_count, data_base = {}, 0, {}
		function functions:add_to_dump(str, indentation, new_line)
			local new_line = new_line or true
			dump = dump .. ("%s%s%s"):format(string.rep("		", indentation), tostring(str), new_line and "\n" or "")
		end
		function functions:get_function_name(func)
			local n = getinfo(func).name
			return n ~= "" and n or "Unknown Name"
		end
		function functions:dump_table(input, indent, index)
			local indent = indent < 0 and 0 or indent
			functions:add_to_dump(("%s [%s] %s"):format(tostring(index), tostring(typeof(input)), tostring(input)), indent - 1)
			local count = 0
			for index, value in pairs(input) do
				count = count + 1
				if type(value) == "function" then
					functions:add_to_dump(("%d [function] = %s"):format(count, functions:get_function_name(value)), indent)
				elseif type(value) == "table" then
					if not data_base[value] then
						data_base[value] = true
						functions:add_to_dump(("%d [table]:"):format(count), indent)
						functions:dump_table(value, indent + 1, index)
					else
						functions:add_to_dump(("%d [table] (Recursive table detected)"):format(count), indent)
					end
				else
					functions:add_to_dump(("%d [%s] = %s"):format(count, tostring(typeof(value)), tostring(value)), indent)
				end
			end
		end
		function functions:dump_function(input, indent)
			functions:add_to_dump(("\nFunction Dump: %s"):format(functions:get_function_name(input)), indent)
			functions:add_to_dump(("\nFunction Upvalues: %s"):format(functions:get_function_name(input)), indent)
			for index, upvalue in pairs(getupvalues(input)) do
				if type(upvalue) == "function" then
					functions:add_to_dump(("%d [function] = %s"):format(index, functions:get_function_name(upvalue)), indent + 1)
				elseif type(upvalue) == "table" then
					if not data_base[upvalue] then
						data_base[upvalue] = true
						functions:add_to_dump(("%d [table]:"):format(index), indent + 1)
						functions:dump_table(upvalue, indent + 2, index)
					else
						functions:add_to_dump(("%d [table] (Recursive table detected)"):format(index), indent + 1)
					end
				else
					functions:add_to_dump(("%d [%s] = %s"):format(index, tostring(typeof(upvalue)), tostring(upvalue)), indent + 1)
				end
			end
			functions:add_to_dump(("\nFunction Constants: %s"):format(functions:get_function_name(input)), indent)
			for index, constant in pairs(getconstants(input)) do
				if type(constant) == "function" then
					functions:add_to_dump(("%d [function] = %s"):format(index, functions:get_function_name(constant)), indent + 1)
				elseif type(constant) == "table" then
					if not data_base[constant] then
						data_base[constant] = true
						functions:add_to_dump(("%d [table]:"):format(index), indent + 1)
						functions:dump_table(constant, indent + 2, index)
					else
						functions:add_to_dump(("%d [table] (Recursive table detected)"):format(index), indent + 1)
					end
				else
					functions:add_to_dump(("%d [%s] = %s"):format(index, tostring(typeof(constant)), tostring(constant)), indent + 1)
				end
			end
		end
		for _, _function in pairs(env.getgc()) do
			if typeof(_function) == "function" and getfenv(_function).script and getfenv(_function).script == scr then
				functions:dump_function(_function, 0)
				functions:add_to_dump("\n" .. ("="):rep(100), 0, false)
			end
		end
		local source = codeFrame:GetText()

		if dump ~= original then source = source .. dump .. "]]" end
		codeFrame:SetText(source)
		
		window:Show()
	end

	ScriptViewer.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Notepad")
		window:Resize(500,400)
		ScriptViewer.Window = window

		codeFrame = Lib.CodeFrame.new()
		codeFrame.Frame.Position = UDim2.new(0,0,0,20)
		codeFrame.Frame.Size = UDim2.new(1,0,1,-40)
		codeFrame.Frame.Parent = window.GuiElems.Content
		ScriptViewer.CodeFrame = codeFrame -- exposed for Explorer source-search highlighting
		
		local copy = Instance.new("TextButton",window.GuiElems.Content)
		copy.BackgroundTransparency = 1
		copy.Size = UDim2.new(0.33,0,0,20)
		copy.Position = UDim2.new(0,0,0,0)
		copy.Text = "Copy to Clipboard"
		
		if env.setclipboard then
			copy.TextColor3 = Color3.new(1,1,1)
			copy.Interactable = true
		else
			copy.TextColor3 = Color3.new(0.5,0.5,0.5)
			copy.Interactable = false
		end

		copy.MouseButton1Click:Connect(function()
			local source = codeFrame:GetText()
			env.setclipboard(source)
		end)

		local save = Instance.new("TextButton",window.GuiElems.Content)
		save.BackgroundTransparency = 1
		save.Size = UDim2.new(0.33,0,0,20)
		save.Position = UDim2.new(0.33,0,0,0)
		save.Text = "Save to File"
		save.TextColor3 = Color3.new(1,1,1)
		
		if env.writefile then
			save.TextColor3 = Color3.new(1,1,1)
			save.Interactable = true
		else
			save.TextColor3 = Color3.new(0.5,0.5,0.5)
			--save.Interactable = false
		end

		save.MouseButton1Click:Connect(function()
			local source = codeFrame:GetText()
			local filename = "Place_"..game.PlaceId.."_Script_"..os.time()..".txt"

			Lib.SaveAsPrompt(filename,source)
			--env.writefile(filename,source)
		end)
		
		dumpbtn = Instance.new("TextButton",window.GuiElems.Content)
		dumpbtn.BackgroundTransparency = 1
		dumpbtn.Position = UDim2.new(0.7,0,0,0)
		dumpbtn.Size = UDim2.new(0.3,0,0,20)
		dumpbtn.Text = "Dump Functions"
		dumpbtn.TextColor3 = Color3.new(0.5,0.5,0.5)
		
		if env.getgc then
			dumpbtn.TextColor3 = Color3.new(1,1,1)
			dumpbtn.Interactable = true
		else
			dumpbtn.TextColor3 = Color3.new(0.5,0.5,0.5)
			dumpbtn.Interactable = false
		end

		dumpbtn.MouseButton1Click:Connect(function()
			if PreviousScr ~= nil then
				pcall(ScriptViewer.DumpFunctions, PreviousScr)
			end
		end)
		
		-- Buttons below the editor
		
		
		execute = Instance.new("TextButton",window.GuiElems.Content)
		execute.BackgroundTransparency = 1
		execute.Size = UDim2.new(0.5,0,0,20)
		execute.Position = UDim2.new(0,0,1,-20)
		execute.Text = "Execute"
		execute.TextColor3 = Color3.new(1,1,1)
		
		if env.loadstring then
			execute.TextColor3 = Color3.new(1,1,1)
			execute.Interactable = true
		else
			execute.TextColor3 = Color3.new(0.5,0.5,0.5)
			execute.Interactable = false
		end

		execute.MouseButton1Click:Connect(function()
			local source = codeFrame:GetText()
			env.loadstring(source)()
		end)

		clear = Instance.new("TextButton",window.GuiElems.Content)
		clear.BackgroundTransparency = 1
		clear.Size = UDim2.new(0.5,0,0,20)
		clear.Position = UDim2.new(0.5,0,1,-20)
		clear.Text = "Clear"
		clear.TextColor3 = Color3.new(1,1,1)

		clear.MouseButton1Click:Connect(function()
			codeFrame:SetText("")
		end)

		-- ===== Find bar (Ctrl+F, also opened by Explorer search) =====
		do
			local theme = Settings.Theme
			local MAX_RESULTS = 3000
			local dim = Color3.fromRGB(150, 150, 150)
			local findState = {matches = {}, idx = 0, text = nil}
			local lastSearched = ""
			local debounce = 0

			local bar = Instance.new("Frame")
			bar.Name = "FindBar"
			bar.BackgroundColor3 = theme.Main2
			bar.BorderColor3 = theme.Outline1
			bar.AnchorPoint = Vector2.new(1, 0)
			bar.Position = UDim2.new(1, -22, 0, 24) -- top right, below the toolbar, left of the code scrollbar
			bar.Size = UDim2.new(0, 236, 0, 24)
			bar.ZIndex = 20
			bar.Visible = false
			bar.Parent = window.GuiElems.Content

			local box = Instance.new("TextBox")
			box.BackgroundColor3 = theme.TextBox
			box.BorderColor3 = theme.Outline3
			box.Position = UDim2.new(0, 3, 0, 3)
			box.Size = UDim2.new(0, 108, 0, 18)
			box.Font = Enum.Font.SourceSans
			box.TextSize = 14
			box.TextColor3 = theme.Text
			box.PlaceholderColor3 = theme.PlaceholderText
			box.PlaceholderText = "Find"
			box.TextXAlignment = Enum.TextXAlignment.Left
			box.ClearTextOnFocus = false
			box.Text = ""
			box.ZIndex = 21
			box.Parent = bar
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 4)
			pad.Parent = box

			local counter = Instance.new("TextLabel")
			counter.BackgroundTransparency = 1
			counter.Position = UDim2.new(0, 113, 0, 3)
			counter.Size = UDim2.new(0, 56, 0, 18)
			counter.Font = Enum.Font.SourceSans
			counter.TextSize = 13
			counter.TextColor3 = dim
			counter.TextXAlignment = Enum.TextXAlignment.Right
			counter.Text = ""
			counter.ZIndex = 21
			counter.Parent = bar

			local function makeButton(text, x, w, rotation)
				local b = Instance.new("TextButton")
				b.BackgroundTransparency = 1
				b.Position = UDim2.new(0, x, 0, 3)
				b.Size = UDim2.new(0, w, 0, 18)
				b.Font = Enum.Font.SourceSansBold
				b.TextSize = 16
				b.TextColor3 = theme.Text
				b.Text = text
				b.Rotation = rotation or 0
				b.ZIndex = 21
				b.Parent = bar
				return b
			end
			-- "<" and ">" turned 90 degrees clockwise point up and down
			local upBtn = makeButton("<", 172, 18, 90)
			local downBtn = makeButton(">", 192, 18, 90)
			local closeBtn = makeButton("X", 212, 20)
			closeBtn.TextSize = 13

			local function getText()
				local ok, t = pcall(codeFrame.GetText, codeFrame)
				return (ok and type(t) == "string") and t or ""
			end

			local function updateCounter()
				local n = #findState.matches
				if #box.Text == 0 then
					counter.Text = ""
				elseif n == 0 then
					counter.Text = "0/0"
					counter.TextColor3 = Color3.fromRGB(230, 120, 120)
				else
					counter.Text = findState.idx .. "/" .. n .. (n >= MAX_RESULTS and "+" or "")
					counter.TextColor3 = dim
				end
			end

			local function goTo(i)
				local n = #findState.matches
				if n == 0 then return end
				i = ((i - 1) % n) + 1
				findState.idx = i
				updateCounter()
				Explorer.SS.GoTo(codeFrame, findState.matches[i], findState.matches.lineCount, true)
			end

			local function search(goFirst)
				local q = box.Text
				lastSearched = q
				findState.text = getText()
				if #q == 0 or not (Explorer and Explorer.SS) then
					findState.matches, findState.idx = {}, 0
					updateCounter()
					return
				end
				local res = Explorer.SS.FindAll(findState.text, q, MAX_RESULTS)
				findState.matches = res
				findState.idx = #res > 0 and 1 or 0
				updateCounter()
				if goFirst and #res > 0 then goTo(1) end
			end

			local function step(dir)
				if getText() ~= findState.text then search(false) end -- the text changed since the last search
				goTo(findState.idx + dir)
			end

			local function show()
				bar.Visible = true
				box:CaptureFocus()
			end

			box:GetPropertyChangedSignal("Text"):Connect(function()
				if box.Text == lastSearched then return end
				debounce = debounce + 1
				local mine = debounce
				task.delay(0.15, function()
					if mine == debounce then search(true) end
				end)
			end)
			box.FocusLost:Connect(function(enterPressed)
				if enterPressed then
					if box.Text ~= lastSearched then search(true) else step(Lib.IsShiftDown() and -1 or 1) end
					task.defer(function() box:CaptureFocus() end) -- keep focus so Enter can be pressed repeatedly
				end
			end)
			upBtn.MouseButton1Click:Connect(function() step(-1) end)
			downBtn.MouseButton1Click:Connect(function() step(1) end)
			closeBtn.MouseButton1Click:Connect(function() bar.Visible = false end)

			-- Ctrl+F while the viewer window is the active one
			local viewerActive = false
			window.OnActivate:Connect(function() viewerActive = true end)
			window.OnDeactivate:Connect(function() viewerActive = false end)
			window.OnMinimize:Connect(function() viewerActive = false end)
			window.OnRestore:Connect(function() viewerActive = true end)
			service.UserInputService.InputBegan:Connect(function(input)
				if input.KeyCode == Enum.KeyCode.F and Lib.IsCtrlDown() and viewerActive then
					show()
					box.SelectionStart = 1
					box.CursorPosition = #box.Text + 1
					search(false)
				end
			end)

			-- used by Explorer: open the bar with the Explorer search word and jump to its first match
			ScriptViewer.OpenFind = function(query)
				bar.Visible = true
				if query then box.Text = query end
				search(true)
			end
			-- re-run after the script changed or the search options changed
			ScriptViewer.RefreshFind = function()
				if bar.Visible then search(false) end
			end
		end
	end

	ScriptViewer.ViewScript = function(scr)
		local oldtick = tick()
		local s,source = pcall(env.decompile or function() end,scr)

		if not s or not source then
			PreviousScr = nil
			dumpbtn.TextColor3 = Color3.new(0.5,0.5,0.5)
			source = "-- Unable to view source.\n"
			source = source .. "-- Script Path: "..getPath(scr).."\n"
			if (scr.ClassName == "Script" and (scr.RunContext == Enum.RunContext.Legacy or scr.RunContext == Enum.RunContext.Server)) or not scr:IsA("LocalScript") then
				source = source .. "-- Reason: The script is not running on client. (attempt to decompile ServerScript or 'Script' with RunContext Server)\n"
			elseif not env.decompile then
				source = source .. "-- Reason: Your executor does not support decompiler. (missing 'decompile' function)\n"
			else
				source = source .. "-- Reason: Unknown\n"
			end
			source = source .. "-- Executor: "..executorName.." ("..executorVersion..")"
		else
			PreviousScr = scr
			dumpbtn.TextColor3 = Color3.new(1,1,1)

			local decompiled = source

			source = "-- Script Path: "..getPath(scr).."\n"
			source = source .. "-- Took "..tostring(math.floor( (tick() - oldtick) * 100) / 100).."s to decompile.\n"
			source = source .. "-- Executor: "..executorName.." ("..executorVersion..")\n\n"

			source = source .. decompiled

			oldtick = nil
			decompiled = nil
		end

		codeFrame:SetText(source)
		window:Show()
		if ScriptViewer.RefreshFind then ScriptViewer.RefreshFind() end
	end

	return ScriptViewer
end

-- TODO: Remove when open source
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end