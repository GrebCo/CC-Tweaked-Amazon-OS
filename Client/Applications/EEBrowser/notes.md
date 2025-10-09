# Fizzle
### script functions
- [ ] Send/Query (sanitized clientnetworkhandler.lua)
- [ ] Access to document (minimark file in cache)
- [ ] Access to cookies (cookies library)
- [ ] Get/change the states of **minimark** only *elements* (UI elements from minimark) (document Library)
- [ ] Get some OS events (keystrokes mouse pos) (FizzleOS libraries)

```
cookies[somevar] = something

fizzleOS.lua
pullEvent(something)
    if something == sensitiveEvent
    return error
    local event, button, x, y = os.pullEvent("mouse_click")
end


<script>
fizzleOS.pullevent("mouse_click")
</script>
```



