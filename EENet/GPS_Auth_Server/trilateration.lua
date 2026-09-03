-- 3D Trilateration Module
-- Computes 3D position from multiple beacon positions and distances

---------------------------------------------------------------------
-- Helper Functions
---------------------------------------------------------------------

-- Calculate Euclidean distance between two 3D points
local function distance3D(p1, p2)
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = p1.z - p2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Solve 3x3 linear system using Cramer's rule
local function solveLinear3x3(A, b)
    -- Compute determinant of A
    local det = A[1][1] * (A[2][2]*A[3][3] - A[2][3]*A[3][2])
                - A[1][2] * (A[2][1]*A[3][3] - A[2][3]*A[3][1])
                + A[1][3] * (A[2][1]*A[3][2] - A[2][2]*A[3][1])

    if math.abs(det) < 0.001 then
        -- System is singular or nearly singular
        return nil
    end

    -- Solve using Cramer's rule
    local x = (b[1] * (A[2][2]*A[3][3] - A[2][3]*A[3][2])
               - A[1][2] * (b[2]*A[3][3] - A[2][3]*b[3])
               + A[1][3] * (b[2]*A[3][2] - A[2][2]*b[3])) / det

    local y = (A[1][1] * (b[2]*A[3][3] - A[2][3]*b[3])
               - b[1] * (A[2][1]*A[3][3] - A[2][3]*A[3][1])
               + A[1][3] * (A[2][1]*b[3] - b[2]*A[3][1])) / det

    local z = (A[1][1] * (A[2][2]*b[3] - b[2]*A[3][2])
               - A[1][2] * (A[2][1]*b[3] - b[2]*A[3][1])
               + b[1] * (A[2][1]*A[3][2] - A[2][2]*A[3][1])) / det

    return {x = x, y = y, z = z}
end

---------------------------------------------------------------------
-- Trilateration for Exactly 3 Beacons
---------------------------------------------------------------------
local function trilaterate3Beacons(measurements)
    -- Extract beacon positions and distances
    local p1 = measurements[1].beaconPos
    local p2 = measurements[2].beaconPos
    local p3 = measurements[3].beaconPos
    local r1 = measurements[1].distance
    local r2 = measurements[2].distance
    local r3 = measurements[3].distance

    -- Use first beacon as origin (translate coordinate system)
    local ex = {
        x = p2.x - p1.x,
        y = p2.y - p1.y,
        z = p2.z - p1.z
    }

    -- Normalize ex (unit vector from p1 to p2)
    local i = math.sqrt(ex.x*ex.x + ex.y*ex.y + ex.z*ex.z)
    if i < 0.001 then
        return nil  -- Beacons too close
    end
    ex.x, ex.y, ex.z = ex.x/i, ex.y/i, ex.z/i

    -- Vector from p1 to p3
    local p1p3 = {
        x = p3.x - p1.x,
        y = p3.y - p1.y,
        z = p3.z - p1.z
    }

    -- Compute j (distance from p1 to p3 along ex)
    local j = ex.x * p1p3.x + ex.y * p1p3.y + ex.z * p1p3.z

    -- Compute ey (unit vector perpendicular to ex, in plane of p1,p2,p3)
    local ey = {
        x = p1p3.x - j * ex.x,
        y = p1p3.y - j * ex.y,
        z = p1p3.z - j * ex.z
    }

    local eyLen = math.sqrt(ey.x*ey.x + ey.y*ey.y + ey.z*ey.z)
    if eyLen < 0.001 then
        return nil  -- Beacons are collinear
    end
    ey.x, ey.y, ey.z = ey.x/eyLen, ey.y/eyLen, ey.z/eyLen

    -- Compute ez (unit vector perpendicular to both ex and ey)
    local ez = {
        x = ex.y * ey.z - ex.z * ey.y,
        y = ex.z * ey.x - ex.x * ey.z,
        z = ex.x * ey.y - ex.y * ey.x
    }

    -- Distance from p3 to projected point on ex axis
    local k = ex.x * p1p3.x + ex.y * p1p3.y + ex.z * p1p3.z

    -- Solve for x, y in the transformed coordinate system
    local x = (r1*r1 - r2*r2 + i*i) / (2 * i)
    local y = (r1*r1 - r3*r3 + j*j + eyLen*eyLen) / (2 * eyLen) - (j * x) / eyLen

    -- Solve for z (two solutions, take positive one)
    local zSquared = r1*r1 - x*x - y*y
    if zSquared < 0 then
        -- Measurement error, distances don't intersect
        -- Use z = 0 as approximation
        zSquared = 0
    end
    local z = math.sqrt(zSquared)

    -- Transform back to original coordinate system
    local result = {
        x = p1.x + x * ex.x + y * ey.x + z * ez.x,
        y = p1.y + x * ex.y + y * ey.y + z * ez.y,
        z = p1.z + x * ex.z + y * ey.z + z * ez.z
    }

    return result
end

---------------------------------------------------------------------
-- Trilateration for 4+ Beacons (Least Squares)
---------------------------------------------------------------------
local function trilaterateMultiBeacons(measurements)
    local n = #measurements

    -- Use first beacon as reference
    local ref = measurements[1]

    -- Build linear system: A * [x, y, z]^T = b
    -- For each pair of beacons i and ref:
    -- 2(xi - x_ref)*x + 2(yi - y_ref)*y + 2(zi - z_ref)*z =
    --     (xi² + yi² + zi²) - (x_ref² + y_ref² + z_ref²) + (d_ref² - di²)

    local A = {}
    local b = {}

    for i = 2, n do
        local pi = measurements[i].beaconPos
        local pref = ref.beaconPos
        local di = measurements[i].distance
        local dref = ref.distance

        local row = {
            2 * (pi.x - pref.x),
            2 * (pi.y - pref.y),
            2 * (pi.z - pref.z)
        }
        table.insert(A, row)

        local bi = (pi.x*pi.x + pi.y*pi.y + pi.z*pi.z)
                   - (pref.x*pref.x + pref.y*pref.y + pref.z*pref.z)
                   + (dref*dref - di*di)
        table.insert(b, bi)
    end

    -- For overdetermined system (n > 3), use normal equations: A^T*A * x = A^T * b
    if n == 4 then
        -- Exactly 3 equations, solve directly
        return solveLinear3x3(A, b)
    else
        -- Overdetermined: compute A^T * A and A^T * b
        local AtA = {{0,0,0}, {0,0,0}, {0,0,0}}
        local Atb = {0, 0, 0}

        for i = 1, #A do
            for j = 1, 3 do
                Atb[j] = Atb[j] + A[i][j] * b[i]
                for k = 1, 3 do
                    AtA[j][k] = AtA[j][k] + A[i][j] * A[i][k]
                end
            end
        end

        return solveLinear3x3(AtA, Atb)
    end
end

---------------------------------------------------------------------
-- Main Trilateration Function
---------------------------------------------------------------------
local function trilaterate(measurements)
    -- Validate input (require at least 4 for stable 3D)
    if not measurements or #measurements < 4 then
        return nil, "insufficient_beacons"
    end

    -- Filter out measurements with nil distance (different dimension)
    local valid = {}
    for _, m in ipairs(measurements) do
        if m.distance and m.beaconPos then
            table.insert(valid, m)
        end
    end

    if #valid < 4 then
        return nil, "insufficient_beacons"
    end

    -- Use least-squares for 4+ beacons (more stable than 3-beacon solution)
    local result = trilaterateMultiBeacons(valid)

    if not result then
        return nil, "geometry_error"
    end

    -- Validate result (check if distances match reasonably well)
    local maxError = 0
    for _, m in ipairs(valid) do
        local computed = distance3D(result, m.beaconPos)
        local error = math.abs(computed - m.distance)
        maxError = math.max(maxError, error)
    end

    -- If error is too large (>10 blocks), something went wrong
    if maxError > 10 then
        return result, "high_error"  -- Return anyway but flag error
    end

    return result, "success"
end

---------------------------------------------------------------------
-- Module Export
---------------------------------------------------------------------
return {
    trilaterate = trilaterate
}
