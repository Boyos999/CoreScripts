require('utils')
local Database = class("Database")

function Database:LoadDriver(driver)

    self.driver = require("luasql." .. driver)

    -- Create environment object
    self.env = nil

    if driver == "sqlite3" then
        self.env = self.driver.sqlite3()
    end
end

function Database:Connect(databasePath)

    self.connection = assert(self.env:connect(databasePath))
end

function Database:Execute(query)

    local response = self.connection:execute(query)

    if response == nil then
        print("Could not execute query: " .. query)
    end

    return response
end

function Database:Escape(string)

    string = self.connection:escape(string)
    return string
end

--- Create a table if it does not already exist
--@param tableName The name of the table. [string]
--@param columnArray An array (to keep column ordering) of key/value pairs. [table]
function Database:CreateTable(tableName, columnArray)

    local query = string.format("CREATE TABLE IF NOT EXISTS %s(", tableName)
    
    for index, column in pairs(columnArray) do
        for name, definition in pairs(column) do
            if index > 1 then
                query = query .. ", "
            end

            -- If this is a constraint, only add its definition to the query
            if name == "constraint" then
                query = query .. definition
            else
                query = query .. string.format("%s %s", name, definition)
            end
        end
    end

    query = query .. ")"
    self:Execute(query)
end

--- Insert a row into a table
--@param tableName The name of the table. [string]
--@param valueTable A key/value table where the keys are the names of columns. [table]
function Database:InsertRow(tableName, valueTable)

    local query = string.format("INSERT OR REPLACE INTO %s", tableName)
    local queryColumns = ""
    local queryValues = ""
    local count = 0

    for column, value in pairs(valueTable) do

        count = count + 1

        if count > 1 then
            queryColumns = queryColumns .. ", "
            queryValues = queryValues .. ", "
        end

        queryColumns = queryColumns .. tostring(column)
        queryValues = queryValues .. '\'' .. self:Escape(tostring(value)) .. '\''
    end

    if count > 0 then

        query = query .. string.format("(%s) VALUES(%s)", queryColumns, queryValues)
        self:Execute(query)
    end
end

function Database:DeleteRows(tableName, condition)

    local query = string.format("DELETE FROM %s %s", tableName, condition)
    self:Execute(query)
end

function Database:GetSingleValue(tableName, column, condition)

    local query = string.format("SELECT %s from %s %s", column, tableName, condition)
    local cursor = self:Execute(query)
    local row = cursor:fetch({}, "a")

    if row == nil or row[column] == nil then
        return -1
    else
        return row[column]
    end
end

function Database:SavePlayer(dbPid, data)

    local validCategories = { "character", "location" }

    for category, categoryTable in pairs(data) do
        if table.contains(validCategories, category) then
            print("Saving category " .. category)
            local tempTable = table.shallowcopy(categoryTable)
            tempTable.dbPid = dbPid
            self:InsertRow("player_" .. category, tempTable)
        end
    end
end

function Database:CreateDefaultTables()

    local columnList, valueTable

    columnList = {
        {dbPid = "INTEGER PRIMARY KEY ASC"},
        {name = "TEXT UNIQUE"},
        {password = "TEXT"},
        {admin = "INTEGER"},
        {consoleAllowed = "TEXT NOT NULL CHECK (consoleAllowed IN ('true', 'false', 'default'))"}
    }

    self:CreateTable("player_general", columnList)

    columnList = {
        {dbPid = "INTEGER PRIMARY KEY ASC"},
        {race = "TEXT"},
        {head = "TEXT"},
        {hair = "TEXT"},
        {gender = "BOOLEAN NOT NULL CHECK (gender IN (0, 1))"},
        {class = "TEXT"},
        {birthsign = "TEXT"},
        {constraint = "FOREIGN KEY(dbPid) REFERENCES player_general(dbPid)" }
    }

    self:CreateTable("player_character", columnList)

    columnList = {
        {dbPid = "INTEGER PRIMARY KEY ASC"},
        {cell = "TEXT"},
        {posX = "NUMERIC"},
        {posY = "NUMERIC"},
        {posZ = "NUMERIC"},
        {rotX = "NUMERIC"},
        {rotY = "NUMERIC"},
        {rotZ = "NUMERIC"},
        {constraint = "FOREIGN KEY(dbPid) REFERENCES player_general(dbPid)" }
    }

    self:CreateTable("player_location", columnList)

    valueTable = {
        name = "David", password = "test", admin = 2, consoleAllowed = "true"
    }

    self:InsertRow("player_general", valueTable)

    local dbPid = self:GetSingleValue("player_general", "dbPid", "WHERE name = 'David'")
end

return Database