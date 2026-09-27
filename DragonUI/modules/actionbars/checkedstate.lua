local addon = select(2, ...)

-- Blizzard drops state events on empty slots without unchecking, so a paged-out cast stays lit.
hooksecurefunc("ActionButton_Update", function(button)
    local action = button.action
    if action and not HasAction(action) then
        button:SetChecked(0)
    end
end)
