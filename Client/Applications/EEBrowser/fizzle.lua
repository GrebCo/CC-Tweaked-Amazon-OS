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


minimark=====================================


<button:"Text on the button", "color FG", "color background", "uniqueIndentifier", "Send Email">
<script>
local minimarkFile = document.get()

function something(args) "Send Email"
    text = grabtextfromelement("uniqueIndentifier")
    sendtextoverrednet(text, destination)
    dosomeLogging("send some text")
end

function onload(args) "on load"
   --do something like a main loop
end

</script>