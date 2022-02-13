local registered_astk = {}
computers.formspec = {}

computers.formspec.get_element_by_name = formspec_ast.get_element_by_name

function computers.formspec.get_index_by_name(tree, name)
    --this doesnt support containers, use this to get container index and then pass container as tree
    if type(tree) ~= "table" then return end

    for key, element in pairs(tree) do
        if type(element) == "table" and element.name and element.name == name then
            return key
        end
    end
end

--note this is terrible hard coded
local function insert_styles(form, styles)
    local headers = {size = true, position = true, anchor = true, no_prepend = true, real_cordinates = true}
    local cindex = 0
    local fs = {}

    for key, val in pairs(form) do
        if type(val) == "number" and not tonumber(key) then
            fs[key] = val
        elseif type(val) == "table" and val.type and headers[val.type] then
            table.insert(fs, val)
            cindex = key
        end
    end

    for _, val in pairs(styles) do
        table.insert(fs, val)
    end

    cindex = cindex+1
    for i=cindex, #form do
        table.insert(fs, form[i])
    end

    return fs
end

function computers.formspec.convert_to_ast(form)
    local styles = {}

    local function rfind(fs)
        for key, val in pairs(fs) do
            if type(val) == "table" then
                if val.type and val.type:find("container") then
                    if val.state and val.state == 1 then
                        --cant use nil so swaping in thing that will never render
                        fs[key] = {type = "label",x = 100,y = 100,label = "nil",}
                    else
                        rfind(val)
                    end
                elseif val.props then
                    table.insert(styles, {type = "style", selectors = val.selectors or {val.name}, props = val.props})
                elseif val.read_only == 1 then
                    val.name = nil
                end
                if val.type == "field" then
                    table.insert(
                        styles,
                        {type = "field_close_on_enter", name = val.name, close_on_enter = val.close_on_enter}
                    )
                end
            end
        end
    end

    rfind(form)

    local fs = insert_styles(form, styles)
    return fs
end

function computers.formspec.show_formspec(player, formname, fs)
    local playername = player
    local formspec = fs

    if type(player) == "userdata" then
        playername = player:get_player_name()
    end
    if type(fs) == "table" then
        registered_astk[playername] = table.copy(fs)
        formspec = formspec_ast.unparse(computers.formspec.convert_to_ast(fs))
    end

    minetest.show_formspec(playername, formname, formspec)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "computers:gui" then return end
    local pname = player:get_player_name()

    if fields.quit then registered_astk[pname] = nil return end

    local keys = {}
    for key, val in pairs(fields) do table.insert(keys, key) end

    local element = computers.formspec.get_element_by_name(registered_astk[pname], keys[1])

    if element and element.on_event then
        --on_event(form, player, element)
        local form = element.on_event(registered_astk[pname], player, element, fields[keys[1]])

        if form then computers.formspec.show_formspec(player, formname, form) end
    end
end)