---------------------------------
-- Trading House Sell
---------------------------------

local ZO_GamepadTradingHouse_Sell = ZO_GamepadTradingHouse_ItemList:Subclass()

function ZO_GamepadTradingHouse_Sell:New(...)
    return ZO_GamepadTradingHouse_ItemList.New(self, ...)
end

function ZO_GamepadTradingHouse_Sell:Initialize(control)
    ZO_GamepadTradingHouse_ItemList.Initialize(self, control)

    GAMEPAD_TRADING_HOUSE_SELL_FRAGMENT = ZO_FadeSceneFragment:New(self.control)
    self:SetFragment(GAMEPAD_TRADING_HOUSE_SELL_FRAGMENT)
end

function ZO_GamepadTradingHouse_Sell:UpdateItemSelectedTooltip(selectedData)
    if selectedData then
        local bag, index = ZO_Inventory_GetBagAndIndex(selectedData)
        GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, bag, index)
    else
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
    end
end

function ZO_GamepadTradingHouse_Sell:SetupSelectedSellItem(selectedItem)
    local bag, index = ZO_Inventory_GetBagAndIndex(selectedItem)
    ZO_TradingHouse_CreateListing_Gamepad_BeginCreateListing(selectedItem, bag, index, selectedItem.stackSellPrice)
end

function ZO_GamepadTradingHouse_Sell:UpdateForGuildChange()
    if not self.control:IsHidden() then
        self:UpdateListForCurrentGuild()
    end
end

function ZO_GamepadTradingHouse_Sell:UpdateListForCurrentGuild()
    local guildId = GetSelectedTradingHouseGuildId()
    if CanSellOnTradingHouse(guildId) then
        self.itemList:SetNoItemText(GetString(SI_GAMEPAD_NO_SELL_ITEMS))
        self.itemList:SetInventoryTypes(BAG_BACKPACK)
    else
        local errorMessage
        if not IsPlayerInGuild(guildId) then
            errorMessage = GetString(SI_GAMEPAD_TRADING_HOUSE_NOT_A_GUILD_MEMBER)
        elseif not DoesGuildHavePrivilege(guildId, GUILD_PRIVILEGE_TRADING_HOUSE) then
            errorMessage = zo_strformat(GetString(SI_GAMEPAD_TRADING_HOUSE_NO_PERMISSION_GUILD), GetNumGuildMembersRequiredForPrivilege(GUILD_PRIVILEGE_TRADING_HOUSE))
        else
            errorMessage = GetString(SI_GAMEPAD_TRADING_HOUSE_NO_PERMISSION_PLAYER)
        end

        self.itemList:SetNoItemText(errorMessage)
        self.itemList:ClearInventoryTypes()
    end

    self:UpdateKeybind()
end

local function SellItemSetupFunction(control, data, selected, selectedDuringRebuild, enabled, activated)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)

    local PRICE_INVALID = false
    ZO_CurrencyControl_SetSimpleCurrency(control.price, CURT_MONEY, data.stackSellPrice, ZO_GAMEPAD_CURRENCY_OPTIONS, CURRENCY_SHOW_ALL, PRICE_INVALID)
end

function ZO_GamepadTradingHouse_Sell:OnSelectionChanged(list, selectedData, oldSelectedData)
    self:UpdateItemSelectedTooltip(selectedData) 
end

-- Overriden functions

function ZO_GamepadTradingHouse_Sell:InitializeList()
    local function OnSelectionChanged(...)
        self:OnSelectionChanged(...)
    end

    local USE_TRIGGERS = true
    local SORT_FUNCTION = nil
    local CATEGORIZATION_FUNCTION = nil
    local ENTRY_SETUP_CALLBACK = nil

    self.itemList = ZO_GamepadInventoryList:New(self.listControl, BAG_BACKPACK, SLOT_TYPE_ITEM, OnSelectionChanged, ENTRY_SETUP_CALLBACK, 
                                                    CATEGORIZATION_FUNCTION, SORT_FUNCTION, USE_TRIGGERS, "ZO_TradingHouse_ItemListRow_Gamepad", SellItemSetupFunction)

    self.itemList:SetItemFilterFunction(function(slot) 
                                            return  ZO_InventoryUtils_DoesNewItemMatchFilterType(slot, ITEMFILTERTYPE_TRADING_HOUSE)
                                        end)
    local parametricList = self.itemList:GetParametricList()
    parametricList:SetAlignToScreenCenter(true)
    parametricList:SetValidateGradient(true)
end

function ZO_GamepadTradingHouse_Sell:OnShowing()
    self:UpdateListForCurrentGuild()
    if self.awaitingResponse and self.itemList:IsActive() then
        -- If returning from the create listing screen the item list will still be active even though we're waiting for a response
        -- We deactivate here for correct functionality while we wait for that response
        self:DeactivateForResponse()
    end
end

function ZO_GamepadTradingHouse_Sell:OnShown()
    self:UpdateKeybind()
end

function ZO_GamepadTradingHouse_Sell:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function()
                local currentListings, maxListings = GetTradingHouseListingCounts()
                if currentListings < maxListings then
                    return zo_strformat(SI_GAMEPAD_TRADING_HOUSE_LISTING_CREATE, currentListings, maxListings)
                else
                    return zo_strformat(SI_GAMEPAD_TRADING_HOUSE_LISTING_CREATE_FULL, currentListings, maxListings)
                end
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            alignment = KEYBIND_STRIP_ALIGN_LEFT,

            callback = function()
                local selectedItem = self.itemList:GetTargetData()
                self:SetupSelectedSellItem(selectedItem)
            end,

            visible = function()
                local guildId = GetSelectedTradingHouseGuildId()
                local selectedItem = self.itemList:GetTargetData()
                return selectedItem and CanSellOnTradingHouse(guildId)
            end,

            enabled = function()
                local currentListings, maxListings = GetTradingHouseListingCounts()
                return currentListings < maxListings
            end

        },

        {
            name = GetString(SI_TRADING_HOUSE_GUILD_LABEL),
            keybind = "UI_SHORTCUT_TERTIARY",
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            callback = function()
                self:DisplayChangeGuildDialog()
            end,
            visible = function()
                return GetSelectedTradingHouseGuildId() ~= nil and GetNumTradingHouseGuilds() > 1
            end,
        },
    }

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
end

function ZO_GamepadTradingHouse_Sell:GetFragmentGroup()
    return {GAMEPAD_TRADING_HOUSE_SELL_FRAGMENT}
end

function ZO_GamepadTradingHouse_Sell:OnHiding()
    self:UpdateItemSelectedTooltip(nil)
end

function ZO_GamepadTradingHouse_Sell:DeactivateForResponse()
    ZO_GamepadTradingHouse_BaseList.DeactivateForResponse(self)
end

function ZO_TradingHouse_Sell_Gamepad_OnInitialize(control)
    GAMEPAD_TRADING_HOUSE_SELL = ZO_GamepadTradingHouse_Sell:New(control)
end