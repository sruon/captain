-- Stats utility functions for captain

local stats        = {}

---Calculate percentile from a sorted array
---@param sorted_array number[] -- The already sorted array of values
---@param p            number   -- The percentile to calculate (0-100)
---@return             number   -- The value at the specified percentile
stats.percentile   = function(sorted_array, p)
    if #sorted_array == 0 then
        return 0
    end

    local index = math.ceil(#sorted_array * (p / 100))
    return sorted_array[math.min(index, #sorted_array)]
end

---Calculate the most common value in a table (mode)
---@param values            number[]  -- Array of values
---@param roundingPrecision number?   -- Optional rounding precision to group similar values
---@return                  number?   -- The most frequently occurring value, or nil if values is empty
---@return                  number?   -- The number of times the most common value appears
stats.mode         = function(values, roundingPrecision)
    if not values or #values == 0 then
        return nil
    end

    -- Count occurrences of each value (with optional rounding)
    local counts = {}
    for _, value in ipairs(values) do
        local roundedValue = value
        if roundingPrecision then
            -- Round to the specified precision
            roundedValue = math.floor(value / roundingPrecision) * roundingPrecision
        end

        counts[roundedValue] = (counts[roundedValue] or 0) + 1
    end

    -- Find the most common value
    local mostCommonValue = nil
    local highestCount    = 0

    for value, count in pairs(counts) do
        if count > highestCount then
            mostCommonValue = value
            highestCount    = count
        end
    end

    return mostCommonValue, highestCount
end

---Calculate frequency distribution as percentages
---@param values       table     -- Table of values where the key is the category and value is the count
---@param minThreshold number?   -- Optional minimum threshold to include in results (0-100)
---@param filter       function? -- Optional filter function(key, percentage) returning true to include
---@return             table     -- Table of {key = percentage} pairs
stats.distribution = function(values, minThreshold, filter)
    local result = {}
    local total  = 0

    -- Calculate total
    for _, count in pairs(values) do
        total = total + count
    end

    if total == 0 then
        return result
    end

    -- Calculate percentages
    for key, count in pairs(values) do
        local percentage = (count / total) * 100

        -- Apply min threshold if provided
        if not minThreshold or percentage >= minThreshold then
            -- Apply filter if provided
            if not filter or filter(key, percentage) then
                result[key] = percentage
            end
        end
    end

    return result
end

---Calculate standard deviation
---@param values number[] -- Array of values
---@param mean   number   -- The mean/average of the values
---@return       number   -- The standard deviation
stats.stddev       = function(values, mean)
    if #values <= 1 then
        return 0
    end

    local sum_sq_diff = 0
    for _, value in ipairs(values) do
        local diff  = value - mean
        sum_sq_diff = sum_sq_diff + (diff * diff)
    end

    return math.sqrt(sum_sq_diff / (#values - 1))
end

---Calculate the median value
---@param sorted_values number[] -- The already sorted array of values
---@return             number   -- The median value
stats.median       = function(sorted_values)
    if #sorted_values == 0 then
        return 0
    end

    local mid = math.floor(#sorted_values / 2) + 1
    if #sorted_values % 2 == 0 then
        return (sorted_values[mid - 1] + sorted_values[mid]) / 2
    else
        return sorted_values[mid]
    end
end

---Calculate comprehensive statistics from an array of values
---@param values number[] -- Array of values to analyze
---@return      table    -- A table containing min, max, percentiles, average, median and standard deviation
stats.calculate    = function(values)
    if #values == 0 then
        return
        {
            min    = 0,
            max    = 0,
            p90    = 0,
            p95    = 0,
            p99    = 0,
            avg    = 0,
            median = 0,
            stddev = 0,
        }
    end

    -- Sort the values for percentile calculations
    local sorted = {}
    for i, v in ipairs(values) do
        sorted[i] = v
    end
    table.sort(sorted)

    local sum = 0
    for _, value in ipairs(values) do
        sum = sum + value
    end

    local mean = sum / #values

    return
    {
        min    = sorted[1],
        max    = sorted[#sorted],
        p90    = stats.percentile(sorted, 90),
        p95    = stats.percentile(sorted, 95),
        p99    = stats.percentile(sorted, 99),
        avg    = mean,
        median = stats.median(sorted),
        stddev = stats.stddev(values, mean),
    }
end

return stats
