-- startup.lua
while true do
    shell.run("reactor.lua")
    print("Reactor controller exited, restarting in 5s")
    sleep(5)
end
