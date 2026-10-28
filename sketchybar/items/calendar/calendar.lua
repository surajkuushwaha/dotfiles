-- Padding item required because of bracket
SBAR.add("item", { position = "right", width = PADDINGS + 6 })

-- time only; the date line was removed
local cal_time = SBAR.add("item", {
  position = "right",
  label = {
    color = COLORS.lavender,
    font = {
      size = 13.0,
    },
  },
})

-- Double border for calendar using a single item bracket
local cal_bracket = SBAR.add("bracket", { cal_time.name }, {
  update_freq = 1,
})

-- Padding item required because of bracket
SBAR.add("item", { position = "right", width = PADDINGS })

cal_bracket:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal_time:set({ label = { string = os.date("%H:%M:%S %p") } })
end)

local function click_event()
  SBAR.exec("open -a Calendar")
end

cal_time:subscribe("mouse.clicked", click_event)
