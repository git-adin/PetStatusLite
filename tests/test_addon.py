"""Exercise the Hunter panel through the TOC, UI callbacks and slash commands."""

from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "PetStatusLite"
sys.path.insert(0, str(ROOT / ".tools"))

from lupa.lua51 import LuaRuntime


class AddonTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(
            '''
            local widget = {}
            function widget:RegisterEvent(event) self.events[event] = true end
            function widget:UnregisterEvent(event) self.events[event] = nil end
            function widget:SetScript(name, callback) self[name] = callback end
            function widget:SetShown(shown)
                if self.shown == shown then return end
                self.shown = shown
                local callback = shown and self.OnShow or self.OnHide
                if callback then callback(self) end
            end
            function widget:Hide() self:SetShown(false) end
            function widget:IsShown() return self.shown end
            function widget:SetText(text) self.text = text end
            function widget:SetPoint(...) self.point = { ... } end
            function widget:GetPoint() return unpack(self.point) end
            function widget:SetWidth(width) self.width = width end
            function widget:GetStringHeight() return 40 end
            function widget:GetFrameLevel() return 1 end
            function widget:SetChecked(value) self.checked = value end
            function widget:GetChecked() return self.checked end
            for _, method in ipairs({
                "SetSize", "SetHeight", "SetClampedToScreen", "SetBackdrop",
                "SetBackdropColor", "SetBackdropBorderColor", "EnableMouse",
                "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
                "SetJustifyH", "SetSpacing", "SetFrameStrata", "SetHitRectInsets",
                "SetFrameLevel", "RegisterForClicks", "SetHighlightTexture", "SetTexture",
                "SetTexCoord", "SetColorTexture", "ClearAllPoints",
            }) do
                widget[method] = function() end
            end

            Frames = {}
            function CreateFrame(kind, _, parent, template)
                local frame = setmetatable({
                    kind = kind, parent = parent, template = template,
                    shown = true, events = {}, children = {},
                }, { __index = widget })
                if parent then table.insert(parent.children, frame) end
                table.insert(Frames, frame)
                return frame
            end
            function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
            function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
            function Fire(event, ...)
                for _, frame in ipairs(Frames) do
                    if frame.events[event] then frame:OnEvent(event, ...) end
                end
            end

            UIParent = CreateFrame("Frame")
            Minimap = CreateFrame("Frame", nil, UIParent)
            SlashCmdList = {}
            Class, ActivePet, PetName = "HUNTER", true, "Ash"
            PetGUID, Now = "Pet-1", 0
            PetLevel, PlayerLevel, CurrentXP, RequiredXP = 19, 20, 100, 500
            Loyalty, Mood = "Best Friend", 3
            Secret = {}
            function issecretvalue(value) return value == Secret end
            function UnitClass() return Class, Class end
            function UnitExists() return ActivePet end
            function UnitName() return PetName end
            function UnitGUID() return PetGUID end
            function UnitLevel(unit) return unit == "pet" and PetLevel or PlayerLevel end
            function GetPetExperience() return CurrentXP, RequiredXP end
            function BreakUpLargeNumbers(value) return tostring(value) end
            function GetTime() return Now end
            C_Timer = {
                NewTicker = function(_, callback)
                    assert(not Timer or Timer.cancelled)
                    Timer = {
                        callback = callback,
                        Cancel = function(self) self.cancelled = true end,
                    }
                    return Timer
                end,
            }
            function Tick(seconds)
                Now = Now + seconds
                if Timer and not Timer.cancelled then Timer.callback() end
            end
            C_PetInfo = {
                GetPetLoyalty = function() return Loyalty end,
                GetPetHappiness = function() return Mood end,
            }
            '''
        )
        namespace = self.lua.table()
        toc = (ADDON / "PetStatusLite.toc").read_text(encoding="utf-8")
        for line in toc.splitlines():
            entry = line.strip().replace(chr(92), "/")
            if entry and not entry.startswith("#") and entry.endswith(".lua"):
                source = (ADDON / entry).read_text(encoding="utf-8")
                self.lua.execute(source, "PetStatusLite", namespace)

    def load_addon(self):
        self.lua.execute(
            '''
            Fire("ADDON_LOADED", "PetStatusLite")
            Panel, Options = UIParent.children[2], UIParent.children[3]
            Heading, Empty, Bar = Panel.children[1], Panel.children[2], Panel.children[3]
            LevelRow, XPRow, RateRow, ETARow = unpack(Panel.children, 4, 7)
            LoyaltyRow, HungerRow = Panel.children[8], Panel.children[9]
            MinimapButton = Minimap.children[1]
            function SetOption(index, checked)
                local control = Options.children[index + 2]
                control:SetChecked(checked)
                control:OnClick()
            end
            '''
        )
        return self.lua.globals()

    def test_initializes_only_for_the_hunter_and_own_load_event(self):
        self.lua.execute('Fire("ADDON_LOADED", "AnotherAddon")')
        self.assertIsNone(self.lua.globals().PetStatusLiteDB)
        self.lua.execute('Class = "WARLOCK"; Fire("ADDON_LOADED", "PetStatusLite")')
        self.assertIsNone(self.lua.globals().PetStatusLiteDB)
        self.assertIsNone(self.lua.globals().Minimap.children[1])

    def test_displays_and_refreshes_pet_stats(self):
        ui = self.load_addon()
        self.assertEqual(ui.Heading.text, "Ash")
        self.assertIn("19", ui.LevelRow.text)
        self.assertIn("400", ui.XPRow.text)
        self.assertIn("Best Friend", ui.LoyaltyRow.text)
        self.assertIn("Happy", ui.HungerRow.text)

        self.lua.execute('CurrentXP = 350; Mood = 1; Loyalty = "Faithful"; Tick(1)')
        self.assertIn("150", ui.XPRow.text)
        self.assertIn("Faithful", ui.LoyaltyRow.text)
        self.assertIn("Unhappy", ui.HungerRow.text)

        self.lua.execute('PetLevel = PlayerLevel; Tick(1)')
        self.assertIn("At your level", ui.XPRow.text)
        self.assertFalse(ui.Bar.shown)

        self.lua.execute('PetLevel = 19; CurrentXP = Secret; Mood = Secret; Tick(1)')
        self.assertIn("Unavailable", ui.XPRow.text)
        self.assertIn("Unavailable", ui.HungerRow.text)

        self.lua.execute('ActivePet = false; Tick(1)')
        self.assertEqual(ui.Heading.text, "Pet Status Lite")
        self.assertEqual(ui.Empty.text, "No active pet")

    def test_minimap_toggles_panel_and_options_and_saves_choices(self):
        ui = self.load_addon()
        self.assertEqual(ui.SLASH_PETSTATUSLITE1, "/petstatuslite")
        self.assertTrue(ui.Panel.shown)
        self.assertFalse(ui.Options.shown)
        self.lua.execute('MinimapButton:OnClick("RightButton")')
        self.assertTrue(ui.Options.shown)
        self.lua.execute(
            '''
            for _, control in ipairs(Options.children) do
                if control.kind == "CheckButton" then
                    control:SetChecked(false)
                    control:OnClick()
                end
            end
            '''
        )
        self.assertFalse(ui.PetStatusLiteDB.stats.xp)
        self.assertEqual(ui.Empty.text, "Choose stats in Options")
        self.lua.execute('SlashCmdList.PETSTATUSLITE("options"); MinimapButton:OnClick("LeftButton")')
        self.assertFalse(ui.Options.shown)
        self.assertFalse(ui.Panel.shown)
        self.assertFalse(ui.PetStatusLiteDB.visible)
        self.assertTrue(ui.Timer.cancelled)
        self.lua.execute('SlashCmdList.PETSTATUSLITE("")')
        self.assertTrue(ui.Panel.shown)

    def test_restores_and_saves_panel_position(self):
        self.lua.execute(
            '''
            PetStatusLiteDB = {
                visible = false, stats = { xp = false },
                position = { point = "CENTER", relativePoint = "CENTER", x = 10, y = 30 },
            }
            '''
        )
        ui = self.load_addon()
        self.assertFalse(ui.Panel.shown)
        self.assertEqual(ui.Panel.point[4], 10)
        self.lua.execute(
            '''
            SlashCmdList.PETSTATUSLITE("")
            Panel:OnDragStart()
            Panel:SetPoint("TOP", UIParent, "TOP", 36, -20)
            Panel:OnDragStop()
            '''
        )
        self.assertFalse(ui.XPRow.shown)
        self.assertTrue(ui.Bar.shown)
        self.assertEqual(ui.PetStatusLiteDB.position.point, "TOP")
        self.assertEqual(ui.PetStatusLiteDB.position.x, 36)

    def test_bar_fills_partial_bubble_and_toggles_independently(self):
        ui = self.load_addon()
        self.lua.execute('CurrentXP = 175; Tick(1)')
        self.assertTrue(ui.Bar.shown)
        self.assertEqual(ui.Bar.children[6].width, 17)
        self.assertEqual(ui.Bar.children[8].width, 8.5)
        self.assertFalse(ui.Bar.children[10].shown)
        self.lua.execute('SetOption(3, false)')
        self.assertFalse(ui.Bar.shown)
        self.assertTrue(ui.XPRow.shown)
        self.assertFalse(ui.PetStatusLiteDB.stats.xpBar)

    def test_catch_up_pace_tracks_level_rollover_and_hidden_panel(self):
        ui = self.load_addon()
        self.assertFalse(ui.RateRow.shown)
        self.assertFalse(ui.ETARow.shown)
        self.lua.execute('PlayerLevel = 22; SetOption(4, true); SetOption(5, true)')
        self.assertIn("Learning pace", ui.ETARow.text)

        self.lua.execute(
            '''
            SlashCmdList.PETSTATUSLITE("")
            CurrentXP = 450
            Tick(30)
            PetLevel, CurrentXP, RequiredXP = 20, 10, 600
            Tick(30)
            SlashCmdList.PETSTATUSLITE("")
            '''
        )
        self.assertIn("24600", ui.RateRow.text)
        self.assertIn("~3 min", ui.ETARow.text)
        self.lua.execute('PlayerLevel = 20; Tick(1)')
        self.assertIn("Caught up", ui.ETARow.text)
        self.assertFalse(ui.Bar.shown)

    def test_pace_expires_and_resets_when_the_active_pet_changes(self):
        ui = self.load_addon()
        self.lua.execute(
            '''
            SetOption(5, true)
            CurrentXP = 200
            Tick(30)
            CurrentXP = 300
            Tick(30)
            '''
        )
        self.assertIn("~1 min", ui.ETARow.text)
        self.lua.execute('Tick(301)')
        self.assertIn("Learning pace", ui.ETARow.text)
        self.lua.execute('CurrentXP = 350; Tick(30); CurrentXP = 400; Tick(30)')
        self.assertIn("~1 min", ui.ETARow.text)
        self.lua.execute('PetGUID = "Pet-2"; CurrentXP = 420; Tick(1)')
        self.assertIn("Learning pace", ui.ETARow.text)

if __name__ == "__main__":
    unittest.main()
