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

class ActorEffectGridTiled < ActorEffect
	title				"Grid Tiled"
	description "Draws actor many times in a grid pattern, out from the center, flipping those in odd columns horizontally and those in odd rows vertically, such that edges are guaranteed to match up with one another."

	setting 'offset', :float, :range => -100.0..100.0, :default => 1.0..2.0
	setting 'number_x', :integer, :range => 0..100, :default => 0..2
	setting 'number_y', :integer, :range => 0..100, :default => 0..2

	def render
		total_children = max(number_x.abs + 1, number_y.abs + 1)

		for y in (-number_y..number_y)
			for x in (-number_x..number_x)
				with_translation(x * offset, y * offset) {
					with_scale(x.is_odd? ? -1 : 1, y.is_odd? ? -1 : 1) {
						yield :child_index => max(x.abs, y.abs), :total_children => total_children
					}
				}
			end
		end
	end
end
