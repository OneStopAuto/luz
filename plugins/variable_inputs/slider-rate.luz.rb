 ###############################################################################
 #  Copyright 2006 Ian McIntosh <ian@openanswers.org>
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

class VariableInputSliderRate < VariableInput
	title				"Slider Rate"
	description "Slider values over chosen pivot point grows the activation, values under the pivot point shrinks activation."

	setting 'slider', :slider, :summary => true
	setting 'pivot_point', :float, :range => 0.001..0.999, :default => 0.5..0.999
	setting 'fill_time', :timespan, :summary => true

	def value
		if slider > pivot_point
			return (last_value + (($env[:frame_time_delta] / fill_time.to_seconds) * ((slider - pivot_point) / pivot_point)))
		else
			return (last_value - (($env[:frame_time_delta] / fill_time.to_seconds) * ((pivot_point - slider) / (1.0 - pivot_point))))
		end
	end
end
