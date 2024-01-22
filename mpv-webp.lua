start_time = -1
end_time = -1
fps_presets = {5, 8, 10, 15, 18, 20, 23, 25, 30, "source"}
fps_index = 4
width_presets = {1920, 1280, 854, 640, 426, -1}
height_presets = {1080, 720, 480, 360, 240, -1}
size_index = 5

local function generate_webp_filename(video_filename, current_date_time)
    return video_filename:gsub("%.[^.]+$", "") .. "_" .. current_date_time .. ".webp"
end

local function get_scale_filter()
    local width = width_presets[size_index]
    local height = height_presets[size_index]
    if width == -1 or height == -1 then
        return "scale=-1:-1"
    else
        if width == -1 then
            return string.format("scale=-1:h=%d", height)
        elseif height == -1 then
            return string.format("scale=w=%d:-1", width)
        else
            return string.format("scale=w=%d:h=%d:force_original_aspect_ratio=decrease", width, height)
        end
    end
end

local function get_fps_filter(video_path)
    local fps_value = fps_presets[fps_index]
    if type(fps_value) == "number" then
        return string.format("fps=%d", fps_value)
    elseif fps_value == "source" then
        local ffprobe_cmd = string.format('ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate %q', video_path)
        local ffprobe_output = io.popen(ffprobe_cmd):read('*all')
        local num, den = ffprobe_output:match('(%d+)/(%d+)')
        if num and den then
            local source_fps = tonumber(num) / tonumber(den)
            return string.format("fps=%d", source_fps)
        else
            return nil, "Could not determine source FPS."
        end
    else
        return nil, "Invalid FPS value."
    end
end

local function execute_ffmpeg_command(position, duration, video_path, scale_filter, fps_filter, webp_path)
    local ffmpeg_args = string.format('ffmpeg -ss %s -t %s -i %q -vf "%s,%s" -vcodec libwebp -lossless 0 -compression_level 6 -q:v 100 -loop 0 -preset picture -an -vsync 0 -y %q',
                                      position, duration, video_path, fps_filter, scale_filter, webp_path)
    os.execute(ffmpeg_args)
end

function make_webp()
    local start_time_l = start_time
    local end_time_l = end_time
    if start_time_l == -1 or end_time_l == -1 or start_time_l >= end_time_l then
        mp.osd_message("Invalid start/end time.")
        return
    end

    mp.osd_message("Creating WEBP.")

    local video_path = mp.get_property("path")
    local position = start_time_l
    local duration = end_time_l - start_time_l
    local current_date_time = os.date("%Y%m%d_%H%M%S")
    local video_filename = mp.get_property("filename")
    local webp_filename = generate_webp_filename(video_filename, current_date_time)
    local directory_path = video_path:match("(.*/)")
    directory_path = directory_path or ""
    local webp_path = directory_path .. webp_filename
    local scale_filter = get_scale_filter()
    local fps_filter, message = get_fps_filter(video_path)

    if not fps_filter then
        mp.osd_message(message)
        return
    end

    execute_ffmpeg_command(position, duration, video_path, scale_filter, fps_filter, webp_path)
    mp.osd_message("WEBP created: " .. webp_path)
end

function make_full_webp()
    mp.osd_message("Creating full WEBP.")
    local video_path = mp.get_property("path")
    local current_date_time = os.date("%Y%m%d_%H%M%S")
    local video_filename = mp.get_property("filename")
    local webp_filename = generate_webp_filename(video_filename, current_date_time)
    local directory_path = video_path:match("(.*/)")
    directory_path = directory_path or ""
    local webp_path = directory_path .. webp_filename
    local scale_filter = get_scale_filter()
    local fps_filter, message = get_fps_filter(video_path)
    
    if not fps_filter then
        mp.osd_message(message)
        return
    end
    
    local ffmpeg_args = string.format('ffmpeg -i %q -vf "%s,%s" -vcodec libwebp -lossless 0 -compression_level 6 -q:v 100 -loop 0 -preset picture -an -vsync 0 -y %q',
                                      video_path, fps_filter, scale_filter, webp_path)
    os.execute(ffmpeg_args)
    mp.osd_message("Full WEBP created: " .. webp_path)
end

function set_webp_start()
   start_time = mp.get_property_number("time-pos", -1)
   mp.osd_message("WEBP Start: " .. start_time)
end

function set_webp_end()
   end_time = mp.get_property_number("time-pos", -1)
   mp.osd_message("WEBP End: " .. end_time)
end

function cycle_fps()
  fps_index = (fps_index % #fps_presets) + 1
  mp.osd_message("WEBP FPS: " .. tostring(fps_presets[fps_index]))
end

function adjust_size(increase)
   if increase then
       size_index = size_index % #width_presets + 1
   else
       size_index = (size_index - 2) % #width_presets + 1
   end
   if size_index == 6 then
       mp.osd_message("WEBP Size: source")
   else
       mp.osd_message("WEBP Size: " .. width_presets[size_index] .. "x" .. height_presets[size_index])
   end
end

mp.add_forced_key_binding("t", "set_webp_start", set_webp_start)
mp.add_forced_key_binding("y", "set_webp_end", set_webp_end)
mp.add_forced_key_binding("Ctrl+w", "adjust_size", function() adjust_size(true) end)
mp.add_forced_key_binding("Ctrl+r", "cycle_fps", cycle_fps)
mp.add_forced_key_binding("Ctrl+t", "make_webp", make_webp)
mp.add_forced_key_binding("Ctrl+y", "make_full_webp", make_full_webp)
