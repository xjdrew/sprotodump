local util = require "util"

local fmt_file_header = [[
// Code generated by sprotodump
// source: %s
// DO NOT EDIT!

/*
    Package %s is a generated sproto package.
*/
package %s

import (
    "reflect"

    "github.com/xjdrew/gosproto"
)
]]

local fmt_struct_header = [[type %s struct {]]
local fmt_struct_field = [[%s %s `sproto:"%s"`]]
local fmt_struct_end = [[}
]]

local fmt_protocols_header = [[var Protocols []*sproto.Protocol = []*sproto.Protocol{]]
local fmt_protocols_end = [[}]]

-- protocol request and response
local fmt_protocol = {
    zz = [[&sproto.Protocol{
            Type: %d,
            Name: "%s",
            Request: reflect.TypeOf(&%s{}),
            Response: reflect.TypeOf(&%s{}),
        },]],
    za = [[&sproto.Protocol{
            Type: %d,
            Name: "%s",
            Request: reflect.TypeOf(&%s{}),
        },]],
    az = [[&sproto.Protocol{
            Type: %d,
            Name: "%s",
            Response: reflect.TypeOf(&%s{}),
        },]],
    aa = [[&sproto.Protocol{
            Type: %d,
            Name: "%s",
        },]]
}

local stream = {}
stream.__index = stream

function stream:write(str)
    table.insert(self.lines, str)
end

function stream:dump()
    return table.concat(self.lines, "\n")
end

local function new_stream()
    local obj = {
        lines = {}
    }
    return setmetatable(obj, stream)
end

local function get_package_name(filename)
    local name = string.match(filename, "([%a_]+).sproto$")
    return ("sproto_%s"):format(name)
end

local function get_file_header(filename)
    local package = get_package_name(filename)
    return fmt_file_header:format(filename, package, package)
end

local function canonical_name(name)
    return name:gsub("%f[^\0%_%.]%l",string.upper):gsub("[%_%.]","")
end

local type_map = {
    string = "*string",
    integer = "*int",
    boolean = "*bool",
}

local array_type_map = {
    string = "[]string",
    integer = "[]int",
    boolean = "[]bool",
}

local function get_type_string(typename, array)
    local target
    if array then
        target = array_type_map[typename]
        if not target then
            target = string.format("[]*%s", canonical_name(typename))
        end
    else
        target = type_map[typename]
        if not target then
            target = string.format("*%s", canonical_name(typename))
        end
    end
    return assert(target, typename .. ":" .. tostring(array))
end

local function get_meta_string(field)
    local meta = {}
    if type_map[field.typename] then
        table.insert(meta, field.typename)
    else
        table.insert(meta, "struct")
    end

    table.insert(meta, field.tag)

    if field.array then
        table.insert(meta, "array")
    end

    table.insert(meta, ("name=%s"):format(field.name))
    return table.concat(meta, ",")
end

local function write_struct_field(f, field)
    local name = canonical_name(field.name)
    local typename = get_type_string(field.typename, field.array)
    local meta = get_meta_string(field)
    f:write(fmt_struct_field:format(name, typename, meta))
end

local function write_struct(f, name, fields)
    local name = canonical_name(name)
    f:write(fmt_struct_header:format(name))
    for _, field in ipairs(fields) do
        write_struct_field(f, field)
    end
    f:write(fmt_struct_end)
end

local function write_protocol(f, name, protocol)
    local request
    local key
    if protocol.request then
        key = "z"
        request = canonical_name(protocol.request)
    else
        key = "a"
    end

    if protocol.response then
        response = canonical_name(protocol.response)
        key = key .. "z"
    else
        key = key .. "a"
    end
    f:write(fmt_protocol[key]:format(protocol.tag, name, request, response))
end

local function main(trunk, build, param)
    assert(#param.sproto_file==1, "one sproto file one package")
    local f = new_stream()
    local filename = param.sproto_file[1]
    f:write(get_file_header(filename))
    for name, fields in pairs(trunk[1].type) do
        write_struct(f, name, fields)
    end
    f:write(fmt_protocols_header)
    for name, protocol in pairs(trunk[1].protocol) do
        write_protocol(f, name, protocol)
    end
    f:write(fmt_protocols_end)

    local outfile = param.outfile
    local dir = param.dircetory or ""
    local file = dir .. outfile
    local content = f:dump()
    util.write_file(file, content, "w")
end

return main
