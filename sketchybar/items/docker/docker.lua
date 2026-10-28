-- Docker: running container count; hidden when Docker is quit
-- docker lives in /usr/local/bin (Docker Desktop), which is not on sketchybar's PATH
local cmd = "PATH=$PATH:/usr/local/bin:$HOME/.docker/bin docker info --format '{{.ContainersRunning}}' 2>/dev/null"

local docker = SBAR.add("item", "docker", {
  position = "right",
  drawing = false,
  -- keep polling while hidden (default updates = "when_shown" would stop it)
  updates = true,
  update_freq = 10,
  icon = {
    string = ICONS.docker,
    color = COLORS.text,
  },
  padding_left = RIGHT_GAP - PADDINGS,
  padding_right = RIGHT_GAP + 5, -- netspeed to the right has padding_left = -5
  click_script = "open -a Docker",
})

docker:subscribe({ "forced", "routine", "system_woke" }, function()
  SBAR.exec(cmd, function(result)
    local count = tonumber((result or ""):match("%d+"))
    docker:set({
      drawing = count ~= nil,
      label = { string = tostring(count or "") },
    })
  end)
end)
