-- GPS Location Finder
-- Trilaterates position from 4 beacons

local CHANNEL = 65534
local REPLY_CHANNEL = 65533
local TIMEOUT = 2

-- Solve 3x3 linear system
local function solve3x3(A, b)
    local det = A[1][1]*(A[2][2]*A[3][3]-A[2][3]*A[3][2])
              - A[1][2]*(A[2][1]*A[3][3]-A[2][3]*A[3][1])
              + A[1][3]*(A[2][1]*A[3][2]-A[2][2]*A[3][1])
    if math.abs(det) < 0.001 then return nil end

    local x = (b[1]*(A[2][2]*A[3][3]-A[2][3]*A[3][2])
              - A[1][2]*(b[2]*A[3][3]-A[2][3]*b[3])
              + A[1][3]*(b[2]*A[3][2]-A[2][2]*b[3])) / det
    local y = (A[1][1]*(b[2]*A[3][3]-A[2][3]*b[3])
              - b[1]*(A[2][1]*A[3][3]-A[2][3]*A[3][1])
              + A[1][3]*(A[2][1]*b[3]-b[2]*A[3][1])) / det
    local z = (A[1][1]*(A[2][2]*b[3]-b[2]*A[3][2])
              - A[1][2]*(A[2][1]*b[3]-b[2]*A[3][1])
              + b[1]*(A[2][1]*A[3][2]-A[2][2]*A[3][1])) / det
    return {x=x, y=y, z=z}
end

-- Trilaterate from 4+ beacons
local function trilaterate(measurements)
    if #measurements < 4 then return nil end
    local ref = measurements[1]
    local A, b = {}, {}
    for i = 2, #measurements do
        local pi, di = measurements[i].pos, measurements[i].dist
        local pr, dr = ref.pos, ref.dist
        table.insert(A, {2*(pi.x-pr.x), 2*(pi.y-pr.y), 2*(pi.z-pr.z)})
        table.insert(b, (pi.x^2+pi.y^2+pi.z^2)-(pr.x^2+pr.y^2+pr.z^2)+(dr^2-di^2))
    end
    return solve3x3(A, b)
end

-- Main
local modem = peripheral.find("modem")
if not modem then error("No modem") end
modem.open(REPLY_CHANNEL)

print("Sending GPS request...")
modem.transmit(CHANNEL, REPLY_CHANNEL, "GPS_REQUEST")

local measurements = {}
local timer = os.startTimer(TIMEOUT)

while true do
    local event, p1, p2, p3, p4, p5 = os.pullEvent()
    if event == "modem_message" and p2 == REPLY_CHANNEL then
        local pos, dist = p4, p5
        if pos and pos.x and dist then
            table.insert(measurements, {pos=pos, dist=dist})
            print("Beacon: ("..pos.x..", "..pos.y..", "..pos.z..") dist: "..string.format("%.1f", dist))
        end
    elseif event == "timer" and p1 == timer then
        break
    end
end

print("")
print("Received " .. #measurements .. " beacon responses")

if #measurements >= 4 then
    local pos = trilaterate(measurements)
    if pos then
        print("")
        print("=== YOUR LOCATION ===")
        print(string.format("X: %.1f", pos.x))
        print(string.format("Y: %.1f", pos.y))
        print(string.format("Z: %.1f", pos.z))
    else
        print("Trilateration failed")
    end
else
    print("Need 4+ beacons, only got " .. #measurements)
end
