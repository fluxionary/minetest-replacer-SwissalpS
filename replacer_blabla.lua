replacer.blabla = {}
local rb = replacer.blabla
rb.log = '[replacer] %s: %s'
rb.mode_single = 'Replace single node.'
rb.mode_field = 'Left click: Replace field of nodes of a kind where a translucent node is in front of it. Right click: Replace field of air where no translucent node is behind the air.'
rb.mode_crust = 'Left click: Replace nodes which touch another one of its kind and a translucent node, e.g. air. Right click: Replace air nodes which touch the crust'
rb.protected_at = 'Protected at %s'
rb.blacklisted = 'Replacing nodes of type "%s" is not allowed on this server. Replacement failed.'
rb.run_out = 'You have no further "%s". Replacement failed.'
rb.attempt_unknown_replace = 'Unknown node: "%s"'
rb.attempt_unknown_place = 'Unknown node to place: "%s"'
rb.can_not_dig = 'Could not dig "%s" properly.'
rb.can_not_place = 'Could not place "%s".'
rb.not_a_node = 'Error: "%s" is not a node.'
rb.wait_for_load = 'Target node not yet loaded. Please wait a moment for the server to catch up.'
rb.nothing_to_replace = 'Nothing to replace.'
rb.need_more_charge = 'Not enough charge to use this mode.'
rb.too_many_nodes_detected = 'Aborted, too many nodes detected.'
rb.charge_required = 'Need %d charge to replace %d nodes.'
rb.count_replaced = '%s nodes replaced.'
rb.mode_changed = 'Mode changed to %s: %s'
rb.none_selected = 'Error: No node selected.'
rb.not_in_creative = 'Item not in creative invenotry: "%s".'
rb.not_in_inventory = 'Item not in your inventory: "%s".'
rb.set_to = 'Node replacement tool set to:\n%s.'
rb.description_basic = 'Node replacement tool'
rb.description_technic = 'Node replacement tool (technic)'
rb.limit_override = 'Setting already set node-limit for "%s" was %d.'
rb.limit_insert = 'Setting node-limit for "%s" to %d.'
rb.blacklist_insert = 'Blacklisted "%s".'
rb.timed_out = 'Time-limit reached.'
rb.tool_short_description = '(%s %s%s) %s'
rb.tool_long_description = '%s\n%s\n%s'
rb.ccm_params = '[ on | off ]'
rb.ccm_description = 'Toggles mute of replacer tool.\nWhen on, no '
    .. 'messages are posted to chat. If off, verbose mode is on.'
rb.ccm_player_not_found = 'Player not found'
rb.ccm_player_meta_error = 'Player meta not existant'
rb.ccm_hint = 'Valid parameter is either "on" or "off"'
rb.reg_rot_exception_override = 'replacer.register_rotation_exception '
    .. 'for "%s" already exists.'
rb.reg_rot_exception = 'replacer.registered exception for "%s" to "%s"'
rb.reg_exception_callback = 'replacer.registered after on_place callback for "%s"'

