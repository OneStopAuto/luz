#!/usr/bin/env ruby
$LOAD_PATH << '/usr/lib/ruby/1.9.1/i486-linux/'

 ###############################################################################
 #  Copyright 2011 Ian McIntosh <ian@openanswers.org>
 #
 #  This program is free software; you can redistribute it and/or modify
 #  it under the terms of the GNU General Public License as published by
 #  the Free Software Foundation; either version 2 of the License, or
 #  (at your option) any later version.
 #
 #  This program is distributed in the hope that it will be useful,
 #  but WITHOUT ANY WARRANTY; without even the implied warranty of
 #  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 #  GNU Library General Public License for more details.
 #
 #  You should have received a copy of the GNU General Public License
 #  along with this program; if not, write to the Free Software
 #  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 ###############################################################################

Dir.chdir(File.dirname(__FILE__))	# So that this file can be run from anywhere
$LOAD_PATH.unshift('./utils').unshift('.')
$LOAD_PATH << './user-object-settings'
$LOAD_PATH << './engine'

###################################################################
# Constants
###################################################################
APP_NAME			= 'Luz Performer'
APP_COPYRIGHT	= "Copyright (c) #{Time.now.year} Ian McIntosh"
APP_AUTHORS 	= ['Ian McIntosh <ian@openanswers.org>']
APP_VERSION		= 0.90

require 'reloadable_require'
require 'addons_ruby', 'method_piping', 'boolean_accessor'

# Application basics
require 'constants', 'sdl', 'opengl', 'addons_gl', 'drawing'

class LuzPerformer
	include Drawing

	SDL_TO_LUZ_BUTTON_NAMES = {'`' => 'Grave', '\\' => 'Backslash', '[' => 'Left Bracket', ']' => 'Right Bracket', ';' => 'Semicolon', "'" => 'Apostrophe', '/' => 'Slash', '.' => 'Period', ',' => 'Comma', '-' => 'Minus', '=' => 'Equal', 'left ctrl' => 'Left Control', 'right ctrl' => 'Right Control'}
	ICON_FILE_PATH = 'gui/icons/logo.bmp'

	attr_accessor :width, :height, :fullscreen, :border, :bits_per_pixel, :frames_per_second, :relay_port
	boolean_accessor :finished, :escape_quits

	TIMING_COUNT = 10

	def initialize
		@width, @height, @bits_per_pixel = 0, 0, 0		# NOTE: setting bpp to 0 means "current" in SDL
		@fullscreen = true
		@stencil_buffer = true
		@border = true

		self.escape_quits = true

		# Frame rate should, ideally, match that of LCD, projector, etc.
		# TODO: add an option for syncing to output device refresh rate, as a way to limit refresh rate.
		@frames_per_second = 60
	end

	def toggle_fullscreen!
		@fullscreen = !@fullscreen
		set_video_mode
		init_gl_viewport
	end

	def create
		SDL.init(SDL::INIT_VIDEO | SDL::INIT_TIMER)
		puts "Using SDL version #{SDL::VERSION}"

		set_video_mode
		init_gl_viewport
		puts "Running at #{@screen.w}x#{@screen.h} @ #{@bits_per_pixel}bpp, #{@frames_per_second}fps (max)"

		SDL::WM.set_caption(APP_NAME, '')

		#SDL::Mouse.hide		NOTE: using a blank cursor works better with Wacom pads
		SDL::Mouse.setCursor(SDL::Surface.new(SDL::HWSURFACE,8,8,8,0,0,0,0),1,1,0,1,0,0)

		SDL::WM.icon = SDL::Surface.load_bmp(ICON_FILE_PATH)

		SDL::Key.disable_key_repeat		# We want one Down and one Up message per key press

		# Create Luz Engine
		require 'engine'
		$engine = Engine.new(:relay_port => @relay_port)
		$engine.post_initialize
		$engine.load_plugins

		# Engine callbacks
		$engine.on_user_object_exception { |obj, e| on_user_object_exception(obj,e) }
		$engine.on_render_settings_changed { $engine.render_settings }	# TODO: remove 'render_settings_changed' concept
		$engine.on_render { $engine.render(enable_frame_saving=true) }		# NOTE: We just have one global context, so this renders to it
	end

	def sdl_video_mode_flags
		flags = SDL::HWSURFACE | SDL::OPENGL
		flags |= SDL::FULLSCREEN if @fullscreen
		flags |= SDL::RESIZABLE if !@fullscreen
		flags |= SDL::NOFRAME unless @border
		flags
	end

	def set_video_mode
		SDL.setGLAttr(SDL::GL_STENCIL_SIZE, 8) if @stencil_buffer
		@screen = SDL.set_video_mode(@width, @height, @bits_per_pixel, sdl_video_mode_flags)

		# Save
		@width, @height = @screen.w, @screen.h
		@bits_per_pixel = @screen.bpp if @bits_per_pixel == 0
	end

	def init_gl_viewport
		GL.Viewport(0, 0, @width, @height)
		clear_screen([0.0, 0.0, 0.0, 0.0])
	end

	#
	# Some hacks for reduced garbage / better performance
	#
	MOUSE_1_X = "Mouse 01 / X"
	MOUSE_1_Y = "Mouse 01 / Y"

	MOUSE_BUTTON_FORMAT = "Mouse %02d / Button %02d"
	@@mouse_1_button_formatter = Hash.new { |hash, key| hash[key] = sprintf(MOUSE_BUTTON_FORMAT, 1, key) }

	def parse_event(event)
		case event
		# Mouse input
		when SDL::Event2::MouseMotion
			$engine.on_slider_change(MOUSE_1_X, (event.x / (@width - 1).to_f))
			$engine.on_slider_change(MOUSE_1_Y, (1.0 - (event.y / (@height - 1).to_f)))

		when SDL::Event2::MouseButtonDown
			$engine.on_button_down(@@mouse_1_button_formatter[event.button], frame_offset=1)

		when SDL::Event2::MouseButtonUp
			$engine.on_button_up(@@mouse_1_button_formatter[event.button], frame_offset=1)

		# Keyboard input
		when SDL::Event2::KeyDown
			if event.sym == SDL::Key::ESCAPE and escape_quits?
				#toggle_fullscreen!
				finished!
			else
				$engine.on_button_down(sdl_to_luz_button_name((key_name=SDL::Key.get_key_name(event.sym))), frame_offset=1)
				if $gui
					key_name.shift = ((event.mod & SDL::Key::MOD_SHIFT) > 0)
					key_name.control = ((event.mod & SDL::Key::MOD_CTRL) > 0)
					key_name.alt = ((event.mod & SDL::Key::MOD_ALT) > 0)
					$gui.raw_keyboard_input(key_name)
				end
			end

		when SDL::Event2::KeyUp
			$engine.on_button_up(sdl_to_luz_button_name(SDL::Key.get_key_name(event.sym)), frame_offset=1)

		when SDL::Event2::Quit
			finished!
		end
	end

	#
	# Run Performer (interactive)
	#
	def run
		start_time = SDL.getTicks
		current_frames_per_second = nil
		frame_number = 1
		timing_start_ms = start_time

		while not finished?
			desired_ms_per_frame = (1000 / @frames_per_second)		# NOTE: desired FPS can change at any time

			frame_start_ms = SDL.getTicks
			timing_start_ms ||= frame_start_ms

			while event = SDL::Event2.poll
				parse_event(event)
			end

			#
			# Render then sleep until time for next frame
			#
			$engine.do_frame((frame_start_ms - start_time) / 1000.0)

			frame_end_ms = SDL.getTicks
			frame_duration_ms = (frame_end_ms - frame_start_ms)

			SDL.GL_swap_buffers		# note trying to not include swap in fps timing
			swap_time_ms = SDL.getTicks - frame_end_ms

			# HACK: recalculate so as not to sleep too much
			frame_end_ms = SDL.getTicks
			frame_duration_ms = (frame_end_ms - frame_start_ms)

			sleep_time_ms = desired_ms_per_frame - frame_duration_ms
			SDL.delay(sleep_time_ms) if sleep_time_ms > 3		# for tiny amounts it doesn't make sense

			frames_per_second = 1000.0 / frame_duration_ms

			if frame_number % TIMING_COUNT == 0
				timing_duration_ms = (frame_end_ms - timing_start_ms)		# we've been timing for many frames
				timing_duration_in_seconds = timing_duration_ms / 1000.0
				seconds_per_frame = timing_duration_in_seconds / TIMING_COUNT
				$env[:current_frames_per_second] = (1.0 / seconds_per_frame).ceil
				timing_start_ms = frame_end_ms
			end

			frame_number += 1
		end
		SDL.quit

		secs = (SDL.getTicks - start_time) / 1000.0
		puts sprintf('%d frames in %0.1f seconds = %dfps (~%dfps render loop)', $env[:frame_number], secs, $env[:frame_number] / secs, 1.0 / $engine.average_frame_time)
	end

	def on_user_object_exception(object, exception)
		# TODO: this shouldn't be printed if our stdout is going to luz_editor, as it can hang when the buffer fills!? :/
		puts sprintf(Engine::USER_OBJECT_EXCEPTION_FORMAT, exception.report_format, object.title)
	end

	@@sdl_to_luz_button_names = Hash.new { |hash, key| hash[key] = sprintf('Keyboard / %s', SDL_TO_LUZ_BUTTON_NAMES[key] || key.humanize) }
	def sdl_to_luz_button_name(name)
		@@sdl_to_luz_button_names[name]
	end

	#
	#
	#
	def get_framebuffer_rgb
		GL.Flush
		GL.ReadPixels(0, 0, @width, @height, GL::RGB, GL::UNSIGNED_BYTE)
	end

	def save_framebuffer_to_file(path)
		image = Magick::Image.new(width, height)
		image.import_pixels(0, 0, width, height, "RGB", get_framebuffer_rgb, Magick::CharPixel)
		image.flip!			# data comes at us upside down
		image.write(path)
	end
end

require 'settings'
settings_path = File.join(Dir.home, SETTINGS_DIRECTORY, SETTINGS_FILENAME)
$settings = Settings.new.load(settings_path)

$application = LuzPerformer.new

require 'optparse'
options = OptionParser.new do |opts|
	opts.banner = "Usage: luz_performer.rb [options] <project.luz>"

	opts.on("--width <width>", Integer, "Resolution width (eg. 800)") do |w|
		$application.width = w
	end
	opts.on("--height <height>", Integer, "Resolution height (eg. 600)") do |h|
		$application.height = h
	end
	opts.on("--bits-per-pixel <bpp>", Integer, "Bits per pixel (8, 16, 24, 32)") do |bpp|
		$application.bits_per_pixel = bpp
	end
	opts.on("--frames-per-second <fps>", Integer, "Target FPS") do |fps|
		$application.frames_per_second = fps.to_i
	end
	opts.on("--fullscreen", "Fullscreen") do
		$application.fullscreen = true
	end
	opts.on("--window", "Window") do
		$application.fullscreen = false
	end
	opts.on("--borderless", "Borderless") do
		$application.border = false
	end
	opts.on("--relay <number>", Integer, 'Relay all received input to this local UDP port number') do |port|
		$application.relay_port = port.to_i
	end
	opts.on("--record", "Record Mode") do
		@record_video = true
	end
	opts.on("--inputs <path>", String, "Specify Inputs File (required when using --record)") do |path|
		@inputs_path = path
	end
end

# Last argument is project name
unless (project_path = ARGV.pop)
	puts options
	exit
end

options.parse!

$application.create
$engine.load_from_path(project_path)
$engine.hardwire!

if @record_video
	#
	# Loop, stepping time forward while rendering frames
	#
	fps = $application.frames_per_second
	ms_per_frame = 1000.0 / fps
	ms = 0
	sample_index = 0
	frame_count = 0
	quit_at_time = nil
	time_to_quit = false

	#
	# Run Performer (non-interactively)
	#
	loop {
		time_in_seconds = (ms / 1000.0)

		# reached the end?
		exit if (quit_at_time and (time_in_seconds > quit_at_time))

		# Render a frame at specific time
		$engine.do_frame(time_in_seconds)

		# Check for ESC
		while event = SDL::Event2.poll
			time_to_quit = true if event.is_a? SDL::Event2::Quit or (event.is_a? SDL::Event2::KeyDown and event.sym == SDL::Key::ESCAPE)
		end

		# Also quit if application wants to (eg. Quit Performer plugin told it to)
		time_to_quit = true if $application.finished?

		$application.save_framebuffer_to_file('frame-%06d.bmp' % frame_count)

		if time_to_quit
			# delete the next frame here, in case there are frames left over from a previous recording
			# this gap in frames will cause the encoder to stop here
			File.rm_f('frame-%06d.bmp' % (frame_count + 1))
			exit
		end

		# Frame Done
		SDL.GL_swap_buffers
		frame_count += 1
		ms += ms_per_frame
	}
else
	$application.run
end
