local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local LocalPlayer = game:GetService("Players").LocalPlayer

local RodModel, PointAtt, ActivePoint = nil -- the variable that will hold the rods model
local maxVisualPart = 20

local FishCatchThreshold = 2

local Character, Hum, HumRP, RightArm = nil

-- status variables
local IfRodisEquipped = false

local BaitActive = false
local PullingFish = false
local PointTween = nil



local VisualizeConnectionForRenderStepped = nil
local VisualizerPartsTable = {}

--[[

MADE BY QUANTUMLUA (AKA Quantum)
This script is for a application on hiddendevs written by quantumlua AKA quantum
and its purpose is to simulate fishing like a minigame on the client because they want a single script to handle everything ig. 
which means anything happening on this script cant seen by any other client except if you play a animation on your character from here
so Im using my own fine-tuned knit version  to make this (I js added some extra bindable events to handle specific things)
]]

local function QuadraticBezier(t,p0,p1,p2)
	return (1-t)^2*p0+2*(1-t)*t*p1+t^2*p2 -- bezier formula
end

local function GetGroundedMousePosition(maxDistance)
	--basically gets the mouse position in 2 dimesnions from the screen - x,y
	local mouseLocation = UIS:GetMouseLocation()
	local mouseRay = workspace.CurrentCamera:ScreenPointToRay(mouseLocation.X, mouseLocation.Y)
	
	--raycastparams for filtering the raycast
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {Character, RodModel}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	--first ray where mouse is pointing
	local result = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * maxDistance, raycastParams)

	if result then
		return result.Position
	end

	--if the ray hits nothing itll cast straight down from the sky
	local skyPoint = mouseRay.Origin + mouseRay.Direction * maxDistance
	local downward = Vector3.new(0, -1, 0)

	local groundResult = workspace:Raycast(skyPoint + Vector3.new(0, 1000, 0), downward * 5000, raycastParams)

	if groundResult then
		return groundResult.Position
	end

	--last fallback point at origin + forward vector
	return skyPoint
end


local FishingController = Knit.CreateController({
	Name = "FishingController",
})

function FishingController:KnitInit()

end

function FishingController:KnitStart()
	
	
	--get the character and the parts needed
	Knit.characterAddedSignal:Connect(function(Char)
		Character = Char
		Hum = Character:FindFirstChild("Humanoid")
		HumRP = Character:FindFirstChild("HumanoidRootPart")
		RightArm = Character:FindFirstChild("Right Arm")   -- For R6 ofc
	end)
	
	

	Knit.characterRemovingSignal:Connect(function()
		Character = nil
		Hum = nil
		HumRP = nil     --handle the removing and dying
		RightArm = nil
	end)
	
	
	
	Knit.characterDiedSignal:Connect(function()
		Character = nil
		Hum = nil           --handle the removing and dying
		HumRP = nil
		RightArm = nil
	end)
	
	

	UIS.InputBegan:Connect(function(input, gpe) -- gpe -> game processed event ---|
		if gpe then return end -- which we use here to prevent accidental input <-|

		if input.KeyCode == Enum.KeyCode.E then
			self:ToggleRod() --self --> which is the module it(self) -> FishingController
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:ThrowBait() -- call the thrwo bait func/method
		end
	end)
end

function FishingController:ThrowBait()
	if not IfRodisEquipped then return end
	
	--disconnecting the visualizing connection to prevent any 
	if VisualizeConnectionForRenderStepped then
		VisualizeConnectionForRenderStepped:Disconnect()
	end
	
	-- looping in the parts table and checking if the part exists in game then destroying it 
	for _,part in pairs(VisualizerPartsTable) do
		if part:IsDescendantOf(game) then
			part:Destroy()
		end
	end
	
	if PullingFish then
		if PointTween then
			PointTween:Pause() -- pause the tween 
		end
		
		for t = 0,1,.01 do
			local CurvePoint = CFrame.new(PointAtt.WorldCFrame.Position):Lerp(CFrame.new(ActivePoint.Position),.5) * CFrame.new(0,((ActivePoint.Position - PointAtt.WorldCFrame.Position) / 2.5).Magnitude, 0)
			ActivePoint.Position = QuadraticBezier(t, ActivePoint.Position, PointAtt.WorldCFrame.Position, CurvePoint.Position)
			-- the curve point is the middle point that gives the curve between the start and end points
			-- and to make the point in the middle of the two points I used lerp to take the middle cframe and assigned it to the curve point
			-- + I multiplied it with the length of the distance between the rods point and the mousehitPosition divided by 2.5 cause that felt the most suitable for me 
			task.wait(.0075)
		end
		PullingFish = false -- finish the pull
		
		--recreate the rod --> recreate the point + visualizing
		self:DestroyRod()
		self:CreateRod()
		
		return
	end
	
	--getting the mouse hit pos
	
	local MouseHitPosition = GetGroundedMousePosition(100)
	
	--giving the throwing the point of the rod effect with -> destroying the weld -> clone the point -> destroy the old point to make it look like you threw it -> throw it with the bezier formula/function

	local RodPoint = RodModel:FindFirstChild("Point")
	local RopeBeam = RodModel:FindFirstChild("RopeBeam") :: Beam
	local RopeBeam2 = RodModel:FindFirstChild("RopeBeam2") :: Beam

	local weldOfRodPoint = RodPoint:FindFirstChildOfClass("WeldConstraint")
	if weldOfRodPoint then
		weldOfRodPoint:Destroy() --destroy weld if theres one (theres a weld so it will automatically destroy it)
	end

	local Point = RodPoint:Clone()
	ActivePoint = Point -- assign the point to the variable

	RopeBeam.Attachment1 = Point:FindFirstChild("Att")
	RopeBeam2.Attachment1 = Point:FindFirstChild("Att")
	--change the beams attachment the the new created point
	
	RodPoint:Destroy() -- destroy the 
	--make the settings like placing it to the point and the anchor 
	Point.Parent = RodModel
	Point.Anchored = true
	Point.CanCollide = false
	Point.CanQuery = false
	Point.CFrame = PointAtt.WorldCFrame
	

	for t = 0,1,.01 do
		local CurvePoint = CFrame.new(PointAtt.WorldCFrame.Position):Lerp(CFrame.new(MouseHitPosition),.5) * CFrame.new(0,((PointAtt.WorldCFrame.Position - MouseHitPosition) / 2.5).Magnitude, 0)
		Point.Position = QuadraticBezier(t ,PointAtt.WorldCFrame.Position, CurvePoint.Position, MouseHitPosition)
		-- the curve point is the middle point that gives the curve between the start and end points
		-- and to make the point in the middle of the two points I used lerp to take the middle cframe and assigned it to the curve point
		-- + I multiplied it with the length of the distance between the rods point and the mousehitPosition divided by 2.5 cause that felt the most suitable for me
		task.wait(.005)
	end
	
	
	BaitActive = true -- activate the bait
	
	local waitingTime = math.random(2,5) --seconds
	
	print("wait:",waitingTime)

	task.delay(waitingTime, function()
		if not BaitActive then return end -- if the bait isnt activated it means ur not fishing yet!!
		BaitActive = false
		PullingFish = true		
		print("theres a fish!")
		
		PointTween = TweenService:Create(Point, TweenInfo.new(.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0), {CFrame = Point.CFrame * CFrame.new(math.random(-4,4),-1,0)})
		PointTween:Play()
		
		task.delay(FishCatchThreshold, function()
			if not PullingFish then return end
			print("...the fish escaped...")
			ActivePoint = nil
			PullingFish = false	
			PointTween:Pause()
			--recreate the rod --> recreate the point + visualizing
			self:DestroyRod()
			self:CreateRod()
		end)
		
	end)
end



function FishingController:CreateRod()
	if not Character or not RightArm then return end
	if RodModel then	
		RodModel:Destroy() -- destroys the old one if there is one
	end
	RodModel = ReplicatedStorage.Rod:Clone() -- clones the rod
	PointAtt = RodModel:FindFirstChild("PointAtt")
	RodModel.Parent = workspace -- places it in characters root part
	RodModel.CFrame = RightArm.CFrame * CFrame.new(0,-1,-3) * CFrame.Angles(math.rad(90), 0, math.rad(180)) -- adjusting it to the arm properly
	RodModel.Anchored = false
	RodModel.CanCollide = false	
	RodModel.Massless = true
	
	--create a weld instance to weld rightarm and the rod
	local Weld = Instance.new("WeldConstraint")
	Weld.Parent = RodModel
	Weld.Part0 = RightArm
	Weld.Part1 = RodModel

	for i = 1,maxVisualPart do -- started it from 1 not 0 cuz I wanted it to be one step ahead
		--creating a part instance for visualizing the pattern when throwed
		local VisualizePart = Instance.new("Part")
		VisualizePart.Parent = workspace.Visuals
		VisualizePart.Anchored = true
		VisualizePart.CanCollide = false
		VisualizePart.CanQuery = false -- not to throw the point to the visualizepart itself
		VisualizePart.Transparency = .2
		VisualizePart.CFrame = PointAtt.WorldCFrame
		VisualizePart.Material = Enum.Material.Neon
		VisualizePart.Color = Color3.fromRGB(0, 255/(i/3), 255)
		VisualizePart.Shape = Enum.PartType.Ball
		VisualizePart.Size = Vector3.new(.5,.5,.5)

		VisualizerPartsTable[i] = VisualizePart
	end

	VisualizeConnectionForRenderStepped = RunService.RenderStepped:Connect(function()
		if #VisualizerPartsTable < 2 then return end
		local MouseHitPosition = GetGroundedMousePosition(100)
		
		-- the curve point is the middle point that gives the curve between the start and end points
		local CurvePoint = CFrame.new(PointAtt.WorldCFrame.Position):Lerp(CFrame.new(MouseHitPosition),.5) * CFrame.new(0,((PointAtt.WorldCFrame.Position - MouseHitPosition) / 2.5).Magnitude, 0)
		--//same explanation
		-- and to make the point in the middle of the two points I used lerp to take the middle cframe and assigned it to the curve point
		-- + I multiplied it with the length of the distance between the rods point and the mousehitPosition divided by 2.5 cause that felt the most suitable for me

		if not IfRodisEquipped then return end

		for index,Part in pairs(VisualizerPartsTable) do
			Part.Position = QuadraticBezier(index/maxVisualPart ,PointAtt.WorldCFrame.Position, CurvePoint.Position ,MouseHitPosition)
		end
	end)

end

function FishingController:DestroyRod()
	--cancel the baits and waiting
	BaitActive = false
	PullingFish = false
	
	--disconnecting the visualizing connection to prevent any 
	if VisualizeConnectionForRenderStepped then
		VisualizeConnectionForRenderStepped:Disconnect()
	end

	-- looping in the parts table and checking if the part exists in game then destroying it 
	for _,part in pairs(VisualizerPartsTable) do
		if part:IsDescendantOf(game) then
			part:Destroy()
		end
	end
	
	if ActivePoint then
		ActivePoint:Destroy() -- destroys and nullifies the active point if theres one
		ActivePoint = nil
	end
	
	if RodModel then
		RodModel:Destroy() -- destroys the rod if there is one
	end
end

function FishingController:ToggleRod()
	IfRodisEquipped = not IfRodisEquipped -- it makes the IfRodisEquipped variable the opposite value like --> if its true, makes it false. if its false then it makes it true
	
	--handling the actions
	if IfRodisEquipped then
		self:CreateRod() -- creates the rod
	else
		self:DestroyRod() -- destroys the rod
	end
end


return FishingController
