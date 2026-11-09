--[[
	BM Hub - شروع خودکار بعد از ری‌جوین سرویس جاخالی مشاهده
	فقط وقتی اجرا میشه که توی Blox Fruits باشی و هاب همین 3 دقیقه‌ی اخیر برای هاکی ری‌جوین کرده باشه.
	بازی‌های دیگه یا باز کردن معمولی Blox Fruits: هیچ کاری نمی‌کنه.
]]
local BF = { [2753915549] = true, [4442272183] = true, [7449423635] = true, [79091703265657] = true, [100117331123089] = true }
if not BF[game.PlaceId] then return end
if not game:IsLoaded() then game.Loaded:Wait() end

local recent = false
pcall(function()
	if not isfile("BMHub_ken.json") then return end
	local all = game:GetService("HttpService"):JSONDecode(readfile("BMHub_ken.json"))
	local me = tostring(game:GetService("Players").LocalPlayer.UserId)
	local job = all[me]
	recent = type(job) == "table" and not job.doneAt and tonumber(job.lastRejoin) ~= nil and os.time() - job.lastRejoin < 180
end)
if not recent then return end

task.wait(4)
local genv = (getgenv and getgenv()) or _G
if genv.BMHub and genv.BMHub.Running then return end -- queue_on_teleport زودتر اجراش کرده
loadstring(readfile("bm.lua"))()
