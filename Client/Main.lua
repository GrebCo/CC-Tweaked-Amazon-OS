local net = require("ClientNetworkHandler")
local config = require("network_config")

net.init(config)
net.openRednet()
net.requestNewDNS()
net.resolveHostname("Amazon")  -- Replace with the desired hostname
net.resolveHostname("Google")  -- Test with a non-existent hostname
net.query(18, "get", "DNS")  -- Replace with the desired hostname
net.closeRednet()
