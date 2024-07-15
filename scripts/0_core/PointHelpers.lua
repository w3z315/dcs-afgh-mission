function findAdjacentPoints(points, targetPoint, maxDistance)
    local adjacentPoints = {}
    for _, point in ipairs(points) do
        if point.Name ~= targetPoint.Name then
            local distance = calculateDistanceBetweenPoints(targetPoint.Point, point.Point)
            if distance <= maxDistance then
                table.insert(adjacentPoints, point)
            end
        end
    end
    return adjacentPoints
end

function calculateDistanceBetweenPoints(pointA, pointB)
    return math.sqrt((pointB.x - pointA.x)^2 + (pointB.y - pointA.y)^2)
end