replacer.tool_name_basic = 'replacer:replacer'
replacer.tool_name_technic = 'replacer:replacer_technic'
replacer.tool_default_node = 'default:dirt'

-- pulling to local scope especially those used in loops
local r = replacer
local rb = replacer.blabla
local rp = replacer.patterns
local rud = replacer.unifieddyes
-- math
local max, min, floor = math.max, math.min, math.floor
local core_check_player_privs = minetest.check_player_privs
local core_get_node = minetest.get_node
local core_get_node_or_nil = minetest.get_node_or_nil
local core_get_node_drops = minetest.get_node_drops
local core_get_item_group = minetest.get_item_group
local core_registered_items = minetest.registered_items
local core_registered_nodes = minetest.registered_nodes
local core_swap_node = minetest.swap_node
local deserialize = minetest.deserialize
local has_creative = creative.is_enabled_for
local serialize = minetest.serialize
local us_time = minetest.get_us_time
-- vector
local vector_multiply = vector.multiply
local vector_new = vector.new
local vector_subtract = vector.subtract

replacer.mode_major_names = { rb.mode_single, rb.mode_field, rb.mode_crust }
replacer.mode_major_infos = {
	rb.mode_single_tooltip,
	rb.mode_field_tooltip:gsub('\n', ' '),
	rb.mode_crust_tooltip:gsub('\n', ' ')
}
replacer.mode_minor_names = { rb.mode_minor1, rb.mode_minor2, rb.mode_minor3 }
replacer.mode_minor_infos = {
	rb.mode_minor1_info, rb.mode_minor2_info, rb.mode_minor3_info
}

replacer.mode_colours = {
	{ '#ffffff', '#cccccc', '#999999' },
	{ '#38fb9a', '#21cc79', '#10bb68' },
	{ '#f4b755', '#d29533', '#9F6200' }
}
function replacer.get_data(stack)
	local meta = stack:get_meta()
	local data = meta:get_string('replacer'):split(' ') or {}
	local node = {
		name = data[1] or r.tool_default_node,
		param1 = tonumber(data[2]) or 0,
		param2 = tonumber(data[3]) or 0
	}
	local mode, mode_bare = {}, meta:get_string('mode'):split('.') or {}
	mode.major = tonumber(mode_bare[1] or 1) or 1
	mode.minor = tonumber(mode_bare[2] or 1)
	return node, mode
end -- get_data

function replacer.set_data(stack, node, mode)
	node = 'table' == type(node) and node or {}
	-- allow passing nil mode -> when ignoring mode in history
	if 'table' ~= type(mode) then
		_, mode = r.get_data(stack)
	end
	local tool_itemstring = stack:get_name()
	local tool_def = core_registered_items[tool_itemstring]
	-- some accidents or deliberate actions can be harmful
	-- if user has an unknown item. So we check here to
	-- prevent possible server crash
	if (not tool_itemstring) or (not tool_def) then
		local t = {
			'Blessed', 'Somewhat known', 'Unknown if known',
			'Pwned', 'Hued', 'Strange', 'Found'
		}
		return t[os.date('*t').wday] .. ' Item'
	end
	local param1 = tostring(node.param1 or 0)
	local param2 = tostring(node.param2 or 0)
	local node_name = node.name or r.tool_default_node
	local data = node_name .. ' ' .. param1 .. ' ' .. param2
	local meta = stack:get_meta()
	meta:set_string('mode', mode.major .. '.' .. mode.minor)
	meta:set_string('replacer', data)
	meta:set_string('color', r.mode_colours[mode.major][mode.minor])
	local node_def = core_registered_items[node_name]
	local node_description = node_name
	if node_def and node_def.description then
		node_description = node_def.description
	end
	local colour_name = rud.colour_name(param2, node_def)
	if 0 < #colour_name then
		colour_name = ' ' .. colour_name
	end
	local tool_name = tool_def.description
	local short_description = rb.tool_short_description:format(
		param1, param2, colour_name, node_name)
	local description = rb.tool_long_description:format(
		tool_name, short_description, node_description) -- r.titleCase(colour_name))

	meta:set_string('description', description)
	return short_description
end -- set_data

if r.has_technic_mod then
	if technic.plus then
		replacer.get_charge = technic.get_RE_charge
		replacer.set_charge = technic.set_RE_charge
	else
		-- technic still stores data serialized, so this is the nearest we get to current standard
		function replacer.get_charge(itemstack)
			local meta = deserialize(itemstack:get_meta():get_string(''))
			if (not meta) or (not meta.charge) then
				return 0
			end
			return meta.charge
		end

		function replacer.set_charge(itemstack, charge, max)
			technic.set_RE_wear(itemstack, charge, max)
			local meta = itemstack:get_meta()
			local data = deserialize(meta:get_string(''))
			if (not data) or (not data.charge) then
				data = { charge = 0 }
			end
			data.charge = charge
			meta:set_string('', serialize(data))
		end
	end

	function replacer.discharge(itemstack, charge, num_nodes, has_creative_or_give)
		if (not technic.creative_mode) and (not has_creative_or_give) then
			charge = charge - r.charge_per_node * num_nodes
			r.set_charge(itemstack, charge, r.max_charge)
			return itemstack
		end
	end
else
	function replacer.discharge() end
	function replacer.get_charge() return r.max_charge end
end

-- replaces one node with another one and returns if it was successful
function replacer.replace_single_node(pos, node_old, node_new, player,
		name, inv, creative)
	local succ, error = r.permit_replace(pos, node_old, node_new, player,
		name, inv, creative)
	if not succ then
		return false, error
	end

	-- do not replace if there is nothing to be done
	if node_old.name == node_new.name then
		-- only the orientation was changed
		if (node_old.param1 ~= node_new.param1)
			or (node_old.param2 ~= node_new.param2)
		then
			core_swap_node(pos, node_new)
		end
		return true
	end

	-- map exception
	local inv_name = r.exception_map[node_new.name] or node_new.name
	-- does the player carry at least one of the desired nodes with him?
	if (not creative) and (not inv:contains_item('main', inv_name)) then
		return false, rb.run_out:format(node_new.name or '?')
	end

	local node_old_def = core_registered_nodes[node_old.name]
	if not node_old_def then
		return false, rb.attempt_unknown_replace:format(node_old.name)
	end
	local node_new_def = core_registered_nodes[node_new.name]
	if not node_new_def then
		return false, rb.attempt_unknown_place:format(node_new.name)
	end

	-- dig the current node if needed
	if not node_old_def.buildable_to then
		-- give the player the item by simulating digging if possible
		node_old_def.on_dig(pos, node_old, player)
		-- test if digging worked
		local dug_node = core_get_node_or_nil(pos)
		if (not dug_node) or
			(not core_registered_nodes[dug_node.name].buildable_to) then
			return false, rb.can_not_dig:format(node_old.name)
		end
	end

	-- place the node similar to how a player does it
	-- (other than the pointed_thing)
	local new_item, succ = node_new_def.on_place(ItemStack(node_new.name), player,
		{ type = 'node', under = vector_new(pos), above = vector_new(pos) })
	-- replacing with trellis set, succ is returned but new_item is nil
	-- possible that other nodes react the same way.
	-- this allows users to dig nodes, I don't see reason to stop that
	-- as long as no crash occurs - SwissalpS
	if (false == succ) or (nil == new_item) then
		return false, rb.can_not_place:format(node_new.name)
	end

	-- update inventory in survival mode
	if not creative then
		-- consume the item
		inv:remove_item('main', inv_name .. ' 1')
		-- if placing the node didn't result in empty stack…
		if '' ~= new_item:to_string() then
			inv:add_item('main', new_item)
		end
	end

	-- test whether the placed node differs from the supposed node
	local placed_node = core_get_node(pos)
	if placed_node.name ~= node_new.name then
		-- Sometimes placing doesn't put the node but does something different
		-- e.g. when placing snow on snow with the snow mod
		return true
	end

	-- fix orientation if needed
	if placed_node.param1 ~= node_new.param1 or
	   placed_node.param2 ~= node_new.param2 then
		core_swap_node(pos, node_new)
	end

	if 'function' == type(r.exception_callbacks[node_new.name]) then
		succ, error = r.exception_callbacks[node_new.name](
			pos, node_old, node_new, player)
		if (not succ) and error and ('' ~= sMsg) then
			r.inform(name, rb.callback_error:format(sMsg))
		end
	end

	return true
end -- replace_single_node

-- the function which happens when the replacer is used
-- also called by on_place if sneak isn't pressed
function replacer.on_use(itemstack, player, pt, right_clicked)
	if (not player) or (not pt) then
		return
	end

	local succ, error
	local keys = player:get_player_control()
	local name = player:get_player_name()
	local creative_enabled = has_creative(name)
	local has_give = core_check_player_privs(name, 'give')
	local has_creative_or_give = creative_enabled or has_give
	local is_technic = itemstack:get_name() == r.tool_name_technic
	local modes_are_available = is_technic or creative_enabled

	-- is special-key held? (aka fast-key)
	if keys.aux1 then
		if not modes_are_available then return itemstack end
		-- fetch current mode
		local _, mode = r.get_data(itemstack)
		-- Show formspec to choose mode
		r.show_mode_formspec(player, mode)
		-- return unchanged tool
		return itemstack
	end

	if 'node' ~= pt.type then
		r.inform(name, rb.not_a_node:format(pt.type))
		return
	end

	local pos = minetest.get_pointed_thing_position(pt, right_clicked)
	local node_old = core_get_node_or_nil(pos)

	if not node_old then
		r.inform(name, rb.wait_for_load)
		return
	end

	local node_new, mode = r.get_data(itemstack)
	if not modes_are_available then
		mode = { major = 1, minor = 1 }
	end
	-- utility function to adjust new node to mode.minor
	-- returns true if adjustments make them equal
	local function adjust_new_to_minor(minor, node_old, node_new)
		-- minor mode overrides to node_new
		if 2 == minor then
			-- node only
			node_new.param1 = node_old.param1
			node_new.param2 = node_old.param2
		elseif 3 == minor then
			-- rotation only
			node_new.name = node_old.name
		end
		-- can we skip right away?
		if (node_old.name == node_new.name)
			and (node_old.param1 == node_new.param1)
			and (node_old.param2 == node_new.param2)
		then
			return true
		end
	end -- adjust_new_to_minor
	if adjust_new_to_minor(mode.minor, node_old, node_new) then
		r.inform(name, rb.nothing_to_replace)
		return
	end

	local inv = player:get_inventory()
	if 1 == mode.major then
		-- single
		succ, error = r.replace_single_node(pos, node_old, node_new,
			player, name, inv, has_creative_or_give)
		if not succ then
			r.inform(name, error)
		end
		return
	end

	-- figure out how many nodes we can modify before we reach
	-- either the count or charge limit
	local max_nodes = r.limit_list[node_new.name] or r.max_nodes
	local charge = r.get_charge(itemstack)
	if not has_creative_or_give then
		if charge < r.charge_per_node then
			r.inform(name, rb.need_more_charge)
			--return
		end

		-- clamp so it works as single mode even without charge
		local max_charge_to_use = min(charge, r.max_charge)
		max_nodes = floor(max_charge_to_use / r.charge_per_node)
		max_nodes = max(1, min(max_nodes, r.max_nodes))
	end

	local found_positions, found_count
	if 2 == mode.major then
		-- field
		-- Get four walk directions which are orthogonal to the field
		local normal = vector_subtract(pt.above, pt.under)
		local dirs, n = {}, 1
		local p
		for coord in pairs(normal) do
			if 0 == normal[coord] then
				for a = -1, 1, 2 do
					p = { x = 0, y = 0, z = 0 }
					p[coord] = a
					dirs[n] = p
					n = n + 1
				end
			end
		end
		-- The normal is used as offset to test if the searched position
		-- is next to the field; the offset goes in the other direction when
		-- a right click happens
		if right_clicked then
			normal = vector_multiply(normal, -1)
		end
		-- Search along the plane next to the field
		right_clicked = (right_clicked and true) or false
		found_positions, found_count = rp.search_positions({
			startpos = pos,
			fdata = {
				func = rp.field_position,
				name = node_old.name,
				param2 = node_old.param2,
				pname = name,
				above = normal,
				right_clicked = right_clicked
			},
			moves = dirs,
			max_positions = max_nodes,
		})
	elseif 3 == mode.major then
		-- crust
		-- Search positions of air (or similar) nodes next to the crust
		local nodename_clicked = rp.get_node(pt.under).name
		local unders, under_count, aboves = rp.search_positions({
			startpos = pt.above,
			fdata = {
				func = rp.crust_above_position,
				name = nodename_clicked,
				pname = name
			},
			moves = rp.offsets_touch,
			max_positions = max_nodes,
		})
		local data
		if right_clicked then
			-- Remove positions which are not directly touching the crust
			data = {
				ps = unders,
				num = under_count,
				name = nodename_clicked,
				pname = name
			}
			rp.reduce_crust_above_ps(data)
			found_positions, found_count = data.ps, data.num
		else
			-- Search crust positions which are next to the previously found
			-- air (or similar) node positions
			found_positions, found_count = rp.search_positions({
				startpos = pt.under,
				fdata = {
					func = rp.crust_under_position,
					name = node_old.name,
					pname = name,
					aboves = aboves
				},
				moves = rp.offsets_hollowcube,
				max_positions = max_nodes
			})
			-- Keep only positions which are directly touching those previously
			-- found positions
			data = { aboves = aboves, ps = found_positions, num = found_count }
			rp.reduce_crust_ps(data)
			found_positions, found_count = data.ps, data.num
		end
	end

	rp.reset_nodes_cache()

	-- at least do the one that was clicked on
	if 0 == found_count then
		succ, error = r.replace_single_node(pos, node_old, node_new, player,
			name, inv, has_creative_or_give)
		if not succ then
			r.inform(name, error)
		end
		return
	end

	local charge_needed = r.charge_per_node * found_count
	local possible_count = found_count
	if not has_creative_or_give then
		if charge < charge_needed then
			possible_count = floor(charge / r.charge_per_node)
		end
	end

	-- set nodes
	local t_start = us_time()
	-- TODO
	local max_time_us = 1000000 * r.max_time
	-- Turn found_positions into a binary heap
	r.datastructures.create_binary_heap({
		input = found_positions,
		n = possible_count,
		compare = function(pos1, pos2)
			-- Return true iff pos1 is nearer to the start position than pos2
			local n1 = (pos1.x - pos.x) ^ 2 + (pos1.y - pos.y) ^ 2 +
				(pos1.z - pos.z) ^ 2
			local n2 = (pos2.x - pos.x) ^ 2 + (pos2.y - pos.y) ^ 2 +
				(pos2.z - pos.z) ^ 2
			return n1 < n2
		end,
	})
	local actual_node_count = 0
	while not found_positions:is_empty() do
		-- Take the position nearest to the start position
		pos = found_positions:take()
		node_old = core_get_node(pos)
		adjust_new_to_minor(minor, node_old, node_new)
		succ, error = r.replace_single_node(pos, node_old, node_new,
			player, name, inv, has_creative_or_give)
		if not succ then
			r.inform(name, error)
			break
		end
		actual_node_count = actual_node_count + 1
		if actual_node_count > max_nodes then
			-- This can happen if too many nodes were detected and the nodes
			-- limit has been set to a small value
			r.inform(name, rb.too_many_nodes_detected)
			break
		end
		-- time-out check
		if us_time() - t_start > max_time_us then
			r.inform(name, rb.timed_out)
			break
		end
	end

	r.discharge(itemstack, charge, actual_node_count, has_creative_or_give)
	if has_creative_or_give then
		r.inform(name, rb.count_replaced:format(actual_node_count))
	end
	return itemstack
end -- on_use

-- right-click with tool -> place set node
-- special+right-click -> cycle major mode (if tool/privs permit)
-- special+sneak+right-click -> cycle minor mode (if tool/privs permit)
-- sneak+right-click -> set node
function replacer.on_place(itemstack, player, pt)
	if (not player) or (not pt) then
		return
	end

	local keys = player:get_player_control()
	local name = player:get_player_name()
	local creative_enabled = has_creative(name)
	local has_give = core_check_player_privs(name, 'give')
	local has_creative_or_give = creative_enabled or has_give
	local is_technic = itemstack:get_name() == r.tool_name_technic
	local modes_are_available = is_technic or creative_enabled

	-- is special-key held? (aka fast-key)
	if keys.aux1 then
		-- don't want anybody to think that special+rc = place
		if not modes_are_available then return end
		-- fetch current mode
		local node, mode = r.get_data(itemstack)
		if keys.sneak then
			-- increment and roll-over minor mode
			mode.minor = mode.minor % 3 + 1
			-- spam chat
			r.inform(name, rb.mode_changed:format(
				r.mode_minor_names[mode.minor], r.mode_minor_infos[mode.minor]))
		else
			-- increment and roll-over major mode
			mode.major = mode.major % 3 + 1
			-- spam chat
			r.inform(name, rb.mode_changed:format(
				r.mode_major_names[mode.major], r.mode_major_infos[mode.major]))
		end
		-- update tool
		r.set_data(itemstack, node, mode)
		-- return changed tool
		return itemstack
	end

	-- If not holding sneak key, place node(s)
	if not keys.sneak then
		return r.on_use(itemstack, player, pt, true)
	end

	-- Select new node
	if 'node' ~= pt.type then
		r.inform(name, rb.none_selected)
		return
	end

	local node, mode = r.get_data(itemstack)
	node = core_get_node_or_nil(pt.under) or node

	-- don't allow setting replacer to denied nodes
	if r.deny_list[node.name] then
		r.inform(name, rb.deny_listed:format(node.name))
		return
	end

	if not modes_are_available then
		mode = { major = 1, minor = 1 }
	end

	local inv = player:get_inventory()
	if (not (creative_enabled and has_give)) and
		(not inv:contains_item('main', node.name)) and
		(not r.exception_map[node.name])
	then
		-- not in inv and not (creative and give)
		local found_item = false
		local drops = core_get_node_drops(node.name)
		if has_creative_or_give then
			if 0 < core_get_item_group(node.name,
					'not_in_creative_inventory')
			then
				-- search for a drop available in creative inventory
				for i = 1, #drops do
					local name = drops[i]
					if core_registered_nodes[name] and
						0 == core_get_item_group(name,
							'not_in_creative_inventory')
					then
						node.name = name
						found_item = true
						break
					end
				end
				if not found_item then
					r.inform(name, rb.not_in_creative:format(node.name))
					return
				end
			end
		else
			-- search for a drop that the player has if possible
			for i = 1, #drops do
				local name = drops[i]
				if core_registered_nodes[name] and
					inv:contains_item('main', name)
				then
					node.name = name
					found_item = true
					break
				end
			end
			if not found_item then
				-- search for a drop available in creative inventory
				-- that first configuring the replacer,
				-- then digging the nodes works
				for i = 1, #drops do
					local name = drops[i]
					if core_registered_nodes[name] and
						0 == core_get_item_group(name,
							'not_in_creative_inventory')
					then
						node.name = name
						found_item = true
						break
					end
				end
			end
			if (not found_item) and (not has_give) then
				r.inform(name, rb.not_in_inventory:format(node.name))
				return
			end
		end
	end

	local short_description = r.set_data(itemstack, node, mode)
	r.history.add_item(player, mode, node, short_description)

	r.inform(name, rb.set_to:format(short_description))

	return itemstack --data changed
end -- on_place

function replacer.tool_def_basic()
	return {
		description = rb.description_basic,
		inventory_image = 'replacer_replacer.png',
		stack_max = 1, -- it has to store information - thus only one can be stacked
		liquids_pointable = true, -- it is ok to painit in/with water
		--node_placement_prediction = nil,
		-- place node(s)
		on_place = r.on_place,
		-- Replace node(s)
		on_use = r.on_use
	}
end

minetest.register_tool(r.tool_name_basic, r.tool_def_basic())

if r.has_technic_mod then
	function replacer.tool_def_technic()
		local def = r.tool_def_basic()
		def.description = rb.description_technic
		def.wear_represents = 'technic_RE_charge'
		def.on_refill = technic.refill_RE_charge
		return def
	end
	technic.register_power_tool(r.tool_name_technic, r.max_charge)
	minetest.register_tool(r.tool_name_technic, r.tool_def_technic())
end
