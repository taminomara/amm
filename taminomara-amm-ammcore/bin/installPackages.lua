local log = require "ammcore/util/log"

local logger = log.Logger:New()

-- This file is started via `taminomara-amm-ammcore/bin/main.lua`,
-- which handles all updates for us.
logger:info("All packages are up to date.")
