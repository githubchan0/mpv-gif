start_time = -1
end_time = -1
fps_presets = {5, 8, 10, 15, 18, 20, 23, 25, 30, "source"}
fps_index = 4
width_presets = {1920, 1280, 854, 640, 426, -1}
height_presets = {1080, 720, 480, 360, 240, -1}
size_index = 5
dithering_options = {"sierra2_4a", "floyd_steinberg", "bayer:bayer_scale=2", "bayer:bayer_scale=3", "none"}
dithering_index = 1

function make_gif()
   local start_time_l = start_time
   local end_time_l = end_time
   if start_time_l == -1 or end_time_l == -1 or start_time_l >= end_time_l then
       mp.osd_message("Invalid start/end time.")
       return
   end

   mp.osd_message("Creating GIF.")

   local video_path = mp.get_property("path")

   local position = start_time_l
   local duration = end_time_l - start_time_l - 1
   if duration < 0 then
       duration = 0
   end

   local current_date_time = os.date("%Y%m%d_%H%M%S")
   local video_filename = mp.get_property("filename")
   local gif_filename = video_filename:gsub("%.[^.]+$", "") .. "_" .. current_date_time .. ".gif"

   local directory_path = video_path:match("(.*/)")
   if not directory_path then
       directory_path = ""
   end

   local gif_path = directory_path .. gif_filename

   local dithering_option = dithering_options[dithering_index]

   local fps_value = fps_presets[fps_index]
   local fps_filter = ""

   if type(fps_value) == "number" then
       fps_filter = string.format('setpts=1.0*PTS,fps=%d', fps_value)
   elseif fps_value == "source" then
       local ffprobe_cmd = string.format('ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate %q', video_path)
       local ffprobe_output = io.popen(ffprobe_cmd):read('*all')
       local source_fps = ffprobe_output:match('(%d+)/(%d+)')

       if source_fps then
           source_fps = tonumber(source_fps)
           fps_filter = string.format('fps=%d', source_fps)
       else
           mp.osd_message("Could not determine source FPS.")
           return
       end
   else
       mp.osd_message("Invalid FPS value.")
       return
   end

   local ffmpeg_args = string.format('ffmpeg -ss %s -t %s -i %q -vf %s,scale=w=%d:h=%d:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256:stats_mode=diff[p];[s1][p]paletteuse=dither=%s -loop 0 -y %q',
                              position, duration, video_path, fps_filter, width_presets[size_index], height_presets[size_index], dithering_option, gif_path)

   os.execute(ffmpeg_args)
end

function make_full_gif()
    mp.osd_message("Creating full GIF.")
    local video_path = mp.get_property("path")
    local current_date_time = os.date("%Y%m%d_%H%M%S")
    local video_filename = mp.get_property("filename")
    local gif_filename = video_filename:gsub("%.[^.]+$", "") .. "_" .. current_date_time .. ".gif"
    local directory_path = video_path:match("(.*/)")
    
    if not directory_path then
        directory_path = ""
    end

    local gif_path = directory_path .. gif_filename
    local dithering_option = dithering_options[dithering_index]
    local fps_value = fps_presets[fps_index]
    local fps_filter = ""

    if type(fps_value) == "number" then
        fps_filter = string.format('setpts=1.0*PTS,fps=%d', fps_value)
    elseif fps_value == "source" then
        local ffprobe_cmd = string.format('ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate %q', video_path)
        local ffprobe_output = io.popen(ffprobe_cmd):read('*all')
        local source_fps = ffprobe_output:match('(%d+)/(%d+)')
        if source_fps then
            source_fps = tonumber(source_fps)
            fps_filter = string.format('fps=%d', source_fps)
        else
            mp.osd_message("Could not determine source FPS.")
            return
        end
    else
        mp.osd_message("Invalid FPS value.")
        return
    end

    local ffmpeg_args = string.format('ffmpeg -i %q -vf %s,scale=w=%d:h=%d:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256:stats_mode=diff[p];[s1][p]paletteuse=dither=%s -loop 0 -y %q',
        video_path, fps_filter, width_presets[size_index], height_presets[size_index], dithering_option, gif_path)

    os.execute(ffmpeg_args)
end

function set_gif_start()
   start_time = mp.get_property_number("time-pos", -1)
   mp.osd_message("GIF Start: " .. start_time)
end

function set_gif_end()
   end_time = mp.get_property_number("time-pos", -1)
   mp.osd_message("GIF End: " .. end_time)
end

function cycle_fps()
  fps_index = (fps_index % #fps_presets) + 1
  mp.osd_message("GIF FPS: " .. fps_presets[fps_index])
end

function adjust_size(increase)
   if increase then
       size_index = size_index % #width_presets + 1
   elseif size_index == 6 then
       mp.osd_message("GIF Size: source")
       return
   else
       size_index = (size_index - 2) % #width_presets + 1
   end

   mp.osd_message("GIF Size: " .. (size_index == 6 and "source" or (width_presets[size_index] .. "x" .. height_presets[size_index])))
end

function cycle_dithering()
   dithering_index = dithering_index % #dithering_options + 1
   mp.osd_message("GIF Dithering: " .. dithering_options[dithering_index])
end

mp.add_forced_key_binding("g", "set_gif_start", set_gif_start)
mp.add_forced_key_binding("h", "set_gif_end", set_gif_end)
mp.add_forced_key_binding("Ctrl+s", "adjust_width", function() adjust_size(true) end)
mp.add_forced_key_binding("Ctrl+d", "cycle_dithering", cycle_dithering)
mp.add_forced_key_binding("Ctrl+f", "cycle_fps", cycle_fps)
mp.add_forced_key_binding("Ctrl+g", "make_gif", make_gif)
mp.add_forced_key_binding("Ctrl+h", "make_full_gif", make_full_gif)
