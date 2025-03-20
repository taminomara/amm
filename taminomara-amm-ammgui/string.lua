local class = require "ammcore.class"

--- Working with strings and string lengths.
---
--- !doctype module
--- @class ammgui.string
local ns = {}

--- Abstract string width provider.
---
--- Calculates string width based on its length, font and size. Implementation
--- depends on GPU.
---
--- @alias ammgui.string.WidthProvider fun(text: string, size: integer, monospace: boolean): number

--- A string with additional data about how it should be rendered.
---
--- @class ammgui.string.String: ammcore.class.Base
ns.String = class.create("String")

--- @param string string
--- @param monospace true?
--- @param color Color?
--- @param noBreak true?
---
--- @generic T: ammgui.string.String
--- @param self T
--- @return T
function ns.String:New(
    string,
    monospace,
    color,
    noBreak
)
    self = class.Base.New(self)

    --- String contents.
    ---
    --- @type string
    self.string = string

    ---  Indicates that this string is rendered using monospace font.
    ---
    --- @type true | nil
    self.monospace = monospace

    ---  String color.
    ---
    --- @type Color?
    self.color = color

    ---  Indicates that this string can't be broken on white spaces.
    ---
    --- @type true | nil
    self.noBreak = noBreak

    return self
end

function ns.String:__tostring()
    return string.format("%s(%q)", self.__name, self.string)
end

function ns.String.__eq(lhs, rhs)
    return (
        lhs.monospace == rhs.monospace
        and lhs.color == rhs.color
        and lhs.noBreak == rhs.noBreak
        and lhs.string == rhs.string
    )
end

--- A string with its width calculated.
---
--- @class ammgui.string.StringW: ammcore.class.Base
ns.StringW = class.create("StringW")

--- @param string string
--- @param monospace true?
--- @param color Color?
--- @param width number
---
--- @generic T: ammgui.string.StringW
--- @param self T
--- @return T
function ns.StringW:New(
    string,
    monospace,
    color,
    width
)
    self = class.Base.New(self)

    --- StringW contents.
    ---
    --- @type string
    self.string = string

    ---  Indicates that this string is rendered using monospace font.
    ---
    --- @type true?
    self.monospace = monospace

    ---  StringW color.
    ---
    --- @type Color?
    self.color = color

    --- Calculated string width.
    ---
    --- @type number
    self.width = width

    return self
end

function ns.StringW:__tostring()
    return string.format("%s(%q, width=%s)", self.__name, self.string, self.width)
end

function ns.StringW.__eq(lhs, rhs)
    return (
        lhs.monospace == rhs.monospace
        and lhs.color == rhs.color
        and lhs.noBreak == rhs.noBreak
        and lhs.string == rhs.string
    )
end

--- Make a new string by combining style parameters from ``settings`` and text
--- from ``string``, and ensuring that its width is properly calculated.
---
--- @param string string text than neets its width calculated.
--- @param settings ammgui.string.String string settings.
--- @param width ammgui.string.WidthProvider function that calculates string widths.
--- @param size integer font size.
--- @return ammgui.string.StringW newString
local function calculateStringWidth(string, settings, width, size)
    return ns.StringW:New(string, settings.monospace, settings.color, width(string, size, settings.monospace))
end

--- Split text into words and calculate widths for each word.
---
--- This function takes a text as an array of strings. It breaks each string
--- into words and whitespaces according to `~ammgui.string.String.noBreak`
--- setting, and returns a new array of strings.
---
--- This function doesn't honor line breaks or groups of multiple
--- consecutive whitespaces. It may modify strings in-place.
---
--- @param strings (string | ammgui.string.String)[] strings to calculate.
--- @param width ammgui.string.WidthProvider function that calculates string widths.
--- @param size integer font size.
--- @return ammgui.string.StringW[] text array of strings with their widths calculated.
function ns.calculateTextWidth(strings, width, size)
    --- @type ammgui.string.StringW[]
    local result = {}
    local trimSpace = true

    --- @param i integer
    --- @param s ammgui.string.String
    --- @param space string
    --- @param word string
    local function processWord(i, s, space, word)
        if word:len() > 0 then
            -- Keep space in front of the string.
            if not trimSpace and space:len() > 0 then
                table.insert(result, calculateStringWidth(" ", s, width, size))
            end

            -- Insert word, keep spaces after it.
            table.insert(result, calculateStringWidth(word, s, width, size))
            trimSpace = false
        else
            -- Keep space in the string, but only if it's not the last one.
            if not trimSpace and space:len() > 0 and i ~= #strings then
                table.insert(result, calculateStringWidth(" ", s, width, size))
                trimSpace = true
            end
        end
    end

    for i, s in ipairs(strings) do
        if type(s) == "string" then
            s = ns.String:New(s)
        end

        local string = s.string:gsub("[\a\r\t\v\b]", "")

        if s.noBreak then
            local spaceBefore, word, spaceAfter = string:match("^(%s*)(.-)(%s*)$")
            processWord(i, s, spaceBefore, word:gsub("%s+", " "))
            processWord(i, s, spaceAfter, "")
        else
            for space, word in string:gmatch("(%s*)([^%s-]*%-*)") do
                processWord(i, s, space, word)
            end
        end
    end

    return result
end

--- Split text into lines trying to keep width below the limit.
---
--- @param strings ammgui.string.StringW[] text.
--- @param maxWidth number maximum width of the text.
--- @return [integer, integer] lines array of indices representing line.
--- @return number maxLineWidth width of the longest line, may be greated than ``maxWidth``.
function ns.splitLines(strings, maxWidth)
    local lines = {};
    local lineStart = 1;
    local lineWidth = 0;
    local maxLineWidth = 0;
    for i, word in ipairs(strings) do
        if lineWidth + word.width > maxWidth then
            if i == lineStart then
                -- Current line is empty, hence this word is too big to fit any line.
                -- Make a line with a single word, we'll have to overflow it.
                if word.string ~= " " then
                    table.insert(lines, { lineStart, lineStart })
                    maxLineWidth = math.max(maxLineWidth, word.width)
                end
                lineWidth = 0
                lineStart = i + 1
            else
                -- Current line is not empty, insert it and place this word
                -- into the next line.
                local lineEnd = i - 1
                while lineEnd > lineStart and strings[lineEnd].string == " " do
                    -- Skip spaces at the end of the string.
                    lineWidth = lineWidth - strings[lineEnd].width
                    lineEnd = lineEnd - 1
                end
                table.insert(lines, { lineStart, lineEnd })
                maxLineWidth = math.max(maxLineWidth, lineWidth)
                if word.string ~= " " then
                    lineWidth = word.width
                    lineStart = i
                else
                    lineWidth = 0
                    lineStart = i + 1
                end
            end
        else
            lineWidth = lineWidth + word.width
        end
    end

    if lineStart <= #strings then
        table.insert(lines, { lineStart, #strings })
        maxLineWidth = math.max(maxLineWidth, lineWidth)
    end

    return lines, maxLineWidth
end

return ns
