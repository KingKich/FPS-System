-- be only required from the client

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()
Player:WaitForChild("PlayerGui")
local PlayerGui = Player.PlayerGui
local GunUI = PlayerGui:WaitForChild("GunUI")
local ScopeUI = GunUI:WaitForChild("SniperScope")

local Cloneable = ReplicatedStorage:WaitForChild("Cloneable")
local GunAnims = ReplicatedStorage:WaitForChild("GunAnims")
local BulletMark = Cloneable:WaitForChild("BulletMark")
local ADSUI = GunUI:WaitForChild("ADS")

local Events = ReplicatedStorage:WaitForChild("Events")
local ShootEvent = Events:WaitForChild("ShootEvent")
local ReloadEvent = Events:WaitForChild("ReloadEvent")
local SwitchGunEvent = Events:WaitForChild("SwitchGun")

local BulletTrailStart = Cloneable:WaitForChild("BulletTrailStart")
local BulletTrailEnd = Cloneable:WaitForChild("BulletTrailEnd")

ContentProvider:PreloadAsync({GunAnims})

--// Sounds
local ClientSFX = SoundService:WaitForChild("ClientSFX")
local ADS_SFX = ClientSFX:WaitForChild("ADS")

--// Modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local CameraShakeModule = require(Modules:WaitForChild("CameraShaker"))

local Camera = workspace.CurrentCamera
local recoilAngle = 0

--// Setting up camera shake
local CameraShake = CameraShakeModule.new(Enum.RenderPriority.Camera.Value + 1, function(shakeCf)
	local recoilCF = CFrame.Angles(math.rad(recoilAngle), 0, 0)
	Camera.CFrame = Camera.CFrame * shakeCf * recoilCF
end)

CameraShake:Start()

-- settle time
local decayTime = 0.2 -- Default decay time

--// Gun Recoil
RunService:BindToRenderStep("RecoilDecay", Enum.RenderPriority.Camera.Value, function(dt)
	if recoilAngle > 0 then
		local decayRate = recoilAngle / decayTime
		recoilAngle = math.max(recoilAngle - decayRate * dt, 0)
	end
end)
CameraShake:Start()

local module = {
	M4A1 = {
		Viewmodel = Cloneable:WaitForChild("M4A1ViewModel"),
		
		EquipSFX = ClientSFX:WaitForChild("M4A1Equip"),
		decayTime = .1,
		
		CustomKeyframes = function(reloadTrack: AnimationTrack)
			reloadTrack:GetMarkerReachedSignal("MagOut"):Connect(function()
				ClientSFX:WaitForChild("MagOut"):Play()
				CameraShake:ShakeOnce(2, 5, .1, .4)
			end)
			reloadTrack:GetMarkerReachedSignal("MagIn"):Connect(function()
				ClientSFX:WaitForChild("MagIn"):Play()
				CameraShake:ShakeOnce(3, 6, .1, .5)
			end)
			reloadTrack:GetMarkerReachedSignal("MagTap"):Connect(function()
				CameraShake:ShakeOnce(3, 6, .1, .5)
			end)
		end,
		
		ShootSFX = ClientSFX:WaitForChild("MA41_Shoot"),
		ShootShake = function()
			recoilAngle += .1
			CameraShake:ShakeOnce(1, 9, .01, .15)
		end,
		ADS_ShootShake = function()
			CameraShake:ShakeOnce(.5, 7, .02, .2)
		end,
	},
	Scar = {
		Viewmodel = Cloneable:WaitForChild("ScarViewmodel"),
		
		ShootShake = function()
			recoilAngle += 2
			CameraShake:ShakeOnce(4, 8, .02, .5)
		end,
		decayTime = .07,
		
		Scope = true,
		
		EquipSFX = ClientSFX:WaitForChild("ScarEquip"),
		CustomKeyframes = function(reloadTrack: AnimationTrack)
			reloadTrack:GetMarkerReachedSignal("Bolt"):Connect(function()
				ClientSFX:WaitForChild("BoltOut"):Play()
				CameraShake:ShakeOnce(2, 5, .1, .4)
			end)
			reloadTrack:GetMarkerReachedSignal("MagOut"):Connect(function()
				ClientSFX:WaitForChild("MagOut"):Play()
				CameraShake:ShakeOnce(3, 6, .1, .5)
			end)
			reloadTrack:GetMarkerReachedSignal("MagIn"):Connect(function()
				ClientSFX:WaitForChild("MagIn"):Play()
				CameraShake:ShakeOnce(3, 6, .1, .5)
			end)
			reloadTrack:GetMarkerReachedSignal("BoltIn"):Connect(function()
				ClientSFX:WaitForChild("BoltIn"):Play()
				CameraShake:ShakeOnce(2.5, 5.5, .1, .7)
			end)
		end,
		
		ADS_ShootShake = function()
			recoilAngle += .7
			CameraShake:ShakeOnce(2, 7, .02, .3)
		end,
		
		ShootSFX = ClientSFX:WaitForChild("ScarShoot"),
	}
}
local meta = {}
meta.__index = meta

--// Variables
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local inputService = game:GetService("UserInputService")

local Spring = require(script:WaitForChild("SpringModule"))
local SwaySpring = Spring.new()
local BobSpring = Spring.new()

type vm_obj = {
	viewmodel: Model,
	__type: "vmObj",
	 
	decayTime: number,
	
	Gun: Model,
	gunName: string,
	Ammo: number,
	TotalAmmo: number,
	RunAlpha: number,
	
	ShootSFX: Sound,
	Animations: {[string]: AnimationTrack},
}

-- Creates a new viewmodel object
function module.new(gunName: string)
	local gunConfig = module[gunName]
	local vm = gunConfig.Viewmodel:Clone()
	vm.Parent = workspace.CurrentCamera
	
	--// Base properties
	local newViewmodelObj = {
		viewmodel = vm,
		
		Gun = vm:FindFirstChildWhichIsA("Model") or vm,
		gunName = gunName,
		
		RunAlpha = 1,
		RunID = 0,
		RunTime = 0,
		ADSID = 0,
		
		Scope = gunConfig.Scope or false,
		
		ShootSFX = gunConfig.ShootSFX,
		Animations = {}
	}
	newViewmodelObj.__type = "vmObj"
	
	-- Change decay time
	decayTime = gunConfig.decayTime or .2
	
	--// Equip SFX
	local newEquipSFX = gunConfig.EquipSFX:Clone()
	newEquipSFX.Parent = ClientSFX
	newEquipSFX:Play()
	newEquipSFX.Ended:Once(function()
		newEquipSFX:Destroy()
	end)
	
	--|| Letting server know you're switching guns
	if gunName ~= Player:GetAttribute("EquippedGun") then
		SwitchGunEvent:FireServer(gunName)
	end
	
	--// Equip Animation
	local Animator = vm:FindFirstChild("Humanoid"):FindFirstChild("Animator")
	local gunAnimations = GunAnims[gunName]
	for _, v in gunAnimations:GetChildren() do
		newViewmodelObj.Animations[v.Name] = Animator:LoadAnimation(v)
		newViewmodelObj.Animations[v.Name].Priority = Enum.AnimationPriority.Action4
	end
	
	--|| Connect reload's custom keyframes to certain actions (usually screen shakes)
	gunConfig.CustomKeyframes(newViewmodelObj.Animations.Reload)
	
	CameraShake:ShakeOnce(1, 4, .05, .6) -- camera shake on equip
	
	--// Equip SFX
	newViewmodelObj.Animations.Equip:Play()
	newViewmodelObj.Animations.Equip.Stopped:Once(function()
		newViewmodelObj.Animations.Idle:Play()
	end)
	
	return setmetatable(newViewmodelObj, meta)
end

local fadeSpeed = 8
function meta:UpdateRunAlpha(dt)
	local target = self.Moving and 1 or 0
	
	self.RunAlpha += (target - self.RunAlpha) * dt * fadeSpeed
	self.RunAlpha = math.clamp(self.RunAlpha, 0, 1)

	if self.RunAlpha == 0 then
		self.RunTime = 0
	end
end

-- Updates the Viewmodel to match with the camera
function meta:Update(dt)
	assert(self.__type == "vmObj", "Type is not vmObj, or . used instead of :")

	local vm = self.viewmodel
	local cameraCF = workspace.CurrentCamera.CFrame
	local mouse_dt = inputService:GetMouseDelta()
	
	SwaySpring:shove(Vector3.new(-mouse_dt.X/300, mouse_dt.Y/300, 0))

	--// Update spring
	local UpdatedSway = SwaySpring:update(dt)
	local swayOffset = CFrame.new(UpdatedSway.X, UpdatedSway.Y, 0)
	
	self:UpdateRunAlpha(dt)

	--// Running bob
	local runOffset = CFrame.new()
	if self.RunAlpha > 0 then
		if self.Sprinting then
			self.RunTime += (dt * 1.5) -- Adjust value as needed
		else
			self.RunTime += dt
		end
	
		local x = math.sin(self.RunTime * 8) * (0.1 * self.RunAlpha)
		local y = math.sin(self.RunTime * 16) * (0.05 * self.RunAlpha)

		runOffset = CFrame.new(x, y, 0)
	end

	--
	local finalCF = cameraCF * swayOffset * runOffset
	vm:PivotTo(finalCF)
end
--// Shooting
-- @ variables
local ShootVFX = Cloneable:WaitForChild("ShootVFX")
local Spotlight1 = Cloneable:WaitForChild("SpotLight")
local BulletImpactSFX = ClientSFX:WaitForChild("BulletImpact")

-- The gun shoots
function meta:Shoot()
	assert(self.__type == "vmObj", "Type is not vmObj, or . used instead of :")
	
	if self.Reloading then
		return
	end
	if Player:GetAttribute(self.gunName .. "_Ammo") <= 0 and Player:GetAttribute(self.gunName .. "_TotalAmmo") <= 0 then
		return
	end
	
	-- @ variables
	local self: vm_obj = self
	local vm = self.viewmodel
	local gun = self.Gun
	local tip = gun:FindFirstChild("Tip")
	if not tip then
		warn("Gun is missing a tip")
		return
	end
	local gunConfig = module[self.gunName]
	
	-- Fire to server
	ShootEvent:FireServer(Camera.CFrame.LookVector)
	
	if self.Animations["Inspect"].IsPlaying then
		self.Animations["Inspect"]:Stop()
	end
	
	--// Shake
	if self.ADSing then
		gunConfig.ADS_ShootShake()
		if self.Scope then
			self:StopADS()
		end
	else
		gunConfig.ShootShake()
	end
	
	--// Shoot SFX
	local newMA41ShootSFX = self.ShootSFX:Clone()
	newMA41ShootSFX.Parent = ClientSFX
	newMA41ShootSFX.PlaybackSpeed = math.random(90, 110)/100
	newMA41ShootSFX:Play()
	newMA41ShootSFX.Ended:Once(function()
		newMA41ShootSFX:Destroy()
	end)
	
	--// Shoot Trail
	local newBulletTrailStart = BulletTrailStart:Clone()
	local newBulletTrailEnd = BulletTrailEnd:Clone()
	local bulletTrail = newBulletTrailStart:FindFirstChild("Beam")
	
	--// Bullet Marks
	local Origin = Camera.CFrame.Position
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {vm, Player.Character}
	params.FilterType = Enum.RaycastFilterType.Exclude
	
	bulletTrail.Attachment0 = newBulletTrailStart
	bulletTrail.Attachment1 = newBulletTrailEnd
	
	--// Spotlights
	local newSpotlight1 = Spotlight1:Clone()
	newSpotlight1.Parent = tip
	
	local raycast = workspace:Raycast(Origin, (Mouse.Hit.Position - Origin).Unit * 1000, params)
	if raycast then
		local hitPos = raycast.Position
		local normal = raycast.Normal
		
		local newBulletMark = BulletMark:Clone()
		newBulletMark.CFrame =  CFrame.lookAt(hitPos + normal * 0.01, hitPos - normal)
		
		local BulletMarkImageLabel = newBulletMark:WaitForChild("SurfaceGui"):WaitForChild("ImageLabel")
		BulletMarkImageLabel.ImageColor3 = Color3.fromRGB(255, 192, 66)
		newBulletMark.Parent = workspace
		
		for _, v in newBulletMark:GetChildren() do
			if v:IsA("ParticleEmitter") then
				v:Emit(math.random(3, 5))
			end
		end
		
		--// Bullet Impact
		local newBulletImpactSFX = BulletImpactSFX:Clone()
		newBulletImpactSFX.PlaybackSpeed = math.random(90, 110)/100
		newBulletImpactSFX.Volume = math.random(70, 90)/100
		newBulletImpactSFX.Parent = newBulletMark
		newBulletImpactSFX:Play()
		newBulletImpactSFX.Ended:Once(function()
			newBulletImpactSFX:Destroy()
		end)
		
		newBulletTrailStart.WorldPosition = tip.Position
		newBulletTrailEnd.CFrame = CFrame.lookAt(hitPos + normal * 0.01, hitPos - normal)
		newBulletTrailEnd.Parent = workspace
		newBulletTrailStart.Parent = workspace
		
		TweenService:Create(BulletMarkImageLabel, TweenInfo.new(.4, Enum.EasingStyle.Circular), {ImageColor3 = Color3.fromRGB(), ImageTransparency = .8}):Play()
		
		task.delay(5, function()
			local hideTween = TweenService:Create(BulletMarkImageLabel, TweenInfo.new(1), {ImageTransparency = 1})
			hideTween:Play()
			hideTween.Completed:Wait()
			newBulletMark:Destroy()
		end)
	else
		newBulletTrailStart.Position = tip.Position
		newBulletTrailEnd.WorldPosition = Mouse.Hit.Position
		newBulletTrailStart.Parent = workspace
		newBulletTrailEnd.Parent = workspace
	end
	
	task.delay(.05, function()
		newBulletTrailEnd:Destroy()
		newBulletTrailStart:Destroy()
		newSpotlight1:Destroy()
	end)
	
	--// Shoot VFX
	local newShootVFX = ShootVFX:Clone()
	newShootVFX.Parent = self.Gun:FindFirstChild("Tip")
	
	for _, v in newShootVFX:GetChildren() do
		if v:IsA("ParticleEmitter") then
			v:Emit(1)
		end
	end
	
	--// Animation
	self.Animations["Fire"]:Play()
	
	--// Reloading
	if Player:GetAttribute(self.gunName .. "_Ammo") <= 1 then
		self:Reload()
		return
	end
end

-- Inspecting
function meta:Inspect()
	assert(self.__type == "vmObj", "Type is not vmObj, or . used instead of :")
	
	local self: vm_obj = self
	local vm = self.viewmodel
	
	self.Animations["Inspect"]:Play()
end

-- Shooting
function meta:Reload()
	assert(self.__type == "vmObj", "Type is not vmObj, or . used instead of :")
	if Player:GetAttribute(self.gunName .. "_Ammo") <= 0 and Player:GetAttribute(self.gunName .. "_TotalAmmo") <= 0 then
		return
	end
	if self.Reloading then
		return
	end
	
	self.Reloading = true
	
	local self: vm_obj = self
	local vm = self.viewmodel
	
	self.Animations["Reload"]:Play()
	self.Animations["Reload"]:GetMarkerReachedSignal("MagIn"):Once(function()
		ReloadEvent:FireServer()
	end)
	self.Animations["Reload"].Stopped:Once(function()
		self.Reloading = false
	end)
end

-- ADS
function meta:ADS()
	assert(self.__type == "vmObj", "Type is not vmObj, or . used instead of :")
	if self.ADSing then
		return
	end
	self.ADSID += 1
	local ADSId = self.ADSID
	
	self.ADSing = true
	
	TweenService:Create(Camera, TweenInfo.new(.6, Enum.EasingStyle.Circular), {FieldOfView = 60}):Play()
	self.Animations["ADS"]:Play(.25) -- custom transitions can be added later on
	
	if self.Scope then
		task.wait(.2)
		if ADSId ~= self.ADSID then
			return
		end
		for _, v in self.viewmodel:GetDescendants() do
			if v:IsA("BasePart") then
				v.LocalTransparencyModifier = 1
			end
		end
		ADS_SFX:Play()
		
		inputService.MouseIconEnabled = false
		ScopeUI.Size = UDim2.fromScale(.8, .8)
		ScopeUI.Position = UDim2.fromScale(.55, .55)
		ScopeUI.Visible = true
		TweenService:Create(ScopeUI, TweenInfo.new(.5, Enum.EasingStyle.Circular), {Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(.5, .5)}):Play()
	else
		TweenService:Create(ADSUI, TweenInfo.new(.4, Enum.EasingStyle.Quad), {ImageTransparency = .7}):Play()
		ADS_SFX:Play()
	end
end
function meta:StopADS()
	assert(self.__type == "vmObj", "Type is not vmObj, or . used instead of :")
	if not self.ADSing then
		return
	end
	self.ADSing = false
	self.ADSID += 1

	TweenService:Create(Camera, TweenInfo.new(.5, Enum.EasingStyle.Sine), {FieldOfView = 70}):Play()
	self.Animations["ADS"]:Stop(.2)
	
	TweenService:Create(ADSUI, TweenInfo.new(.4, Enum.EasingStyle.Quad), {ImageTransparency = 1}):Play()
	
	if self.Scope then
		for _, v in self.viewmodel:GetDescendants() do
			if v:IsA("BasePart") then
				v.LocalTransparencyModifier = 0
			end
		end
		inputService.MouseIconEnabled = true
		ScopeUI.Visible = false
	end
end

-- Walking
function meta:StartWalking()
	if self.Moving then 
		return 
	end
	self.Moving = true
end

function meta:StopWalking()
	if not self.Moving then 
		return
	end
	self.Moving = false
end

-- Running
function meta:StartRunning()
	if self.Sprinting then 
		return 
	end
	self.Sprinting = true
	
	if not self.Animations["Running"] then
		return
	end
	self.Animations["Running"]:Play()
end

function meta:StopRunning()
	if not self.Sprinting then 
		return
	end
	self.Sprinting = false
	
	if not self.Animations["Running"] then
		return
	end
	self.Animations["Running"]:Stop()
end

return module
