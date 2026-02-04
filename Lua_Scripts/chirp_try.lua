-- Roll-angle chirp for Copter in GUIDED mode
-- Uses vehicle:set_target_angle_and_climbrate()
-- Starts 7 seconds after entering GUIDED
-- Prints message when chirp is finished

---@diagnostic disable: cast-local-type
---@diagnostic disable: redundant-parameter

---------------- USER PARAMETERS ----------------
local roll_amp_deg   = 10.0     -- roll amplitude [deg]
local f_start_hz     = 0.5      -- start frequency [Hz]
local f_end_hz       = 5.0      -- end frequency [Hz]
local chirp_time_s   = 20.0     -- chirp duration [s]
local sample_time_s  = 0.02     -- update period [s]
local start_delay_s  = 7.0      -- delay after entering GUIDED [s]
-------------------------------------------------

local GUIDED = 4
local t = 0.0
local yaw_deg_hold = nil
local guided_entry_time = nil
local chirp_done = false

local function chirp_freq(tt)
    if tt >= chirp_time_s then
        return f_end_hz
    end
    return f_start_hz + (f_end_hz - f_start_hz) * (tt / chirp_time_s)
end

gcs:send_text(6, "Roll chirp script loaded (7s delayed)")

function update()
    if arming:is_armed() and vehicle:get_mode() == GUIDED then

        -- detect GUIDED entry
        if guided_entry_time == nil then
            guided_entry_time = millis():tofloat() * 0.001
            t = 0.0
            yaw_deg_hold = nil
            chirp_done = false
            gcs:send_text(6, "Entered GUIDED, waiting 7s")
        end

        local now_s = millis():tofloat() * 0.001

        -- wait before starting chirp
        if (now_s - guided_entry_time) < start_delay_s then
            return update, sample_time_s * 1000
        end

        -- chirp finished → print once and hold attitude
        if t >= chirp_time_s then
            if not chirp_done then
                gcs:send_text(6, "Roll chirp finished")
                chirp_done = true
            end
            return update, sample_time_s * 1000
        end

        -- capture yaw once (after delay)
        if yaw_deg_hold == nil then
            local yaw_rad = ahrs:get_yaw_rad()
            yaw_deg_hold = math.deg(yaw_rad)
            gcs:send_text(6, "Yaw hold set to " .. string.format("%.1f", yaw_deg_hold) .. " deg")
        end

        local f = chirp_freq(t)
        local roll_deg = roll_amp_deg * math.sin(2.0 * math.pi * f * t)

        local pitch_deg = 0.0
        local yaw_deg   = yaw_deg_hold

        local yaw_rate_dps    = 0.0
        local climb_rate_mps  = 0.0
        local yaw_mode        = 0   -- use yaw angle

        vehicle:set_target_angle_and_climbrate(
            roll_deg, pitch_deg, yaw_deg,
            yaw_rate_dps, climb_rate_mps, yaw_mode
        )

        t = t + sample_time_s

    else
        -- reset when leaving GUIDED or disarmed
        t = 0.0
        yaw_deg_hold = nil
        guided_entry_time = nil
        chirp_done = false
    end

    return update, sample_time_s * 1000
end

return update()
