local event = doFile("OSUtil/events.lua")

local specificButtonPressedEvent = "specificBunPressed"

event.registerEvent(ButtonPressedEvent)



function doSomething(args)
    print(args)
end

function somethingElse(args)
    print(args) -- Totally something else
end





event.registerFunction(specificButtonPressedEvent, doSomething)





event.trigger(specificButtonPressedEvent, "parameters")


