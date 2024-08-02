Notifications = {}

Notifications.chat = function(msg, colour)

    colour = colour ~= nil and colour or { 132, 102, 226 }

    TriggerEvent("chat:addMessage", {
        color = colour,
        multiline = true,
        args = { "[races:client]", msg }
    })

end

Notifications.toast = function(msg, colour)

    colour = colour ~= nil and colour or "~p~"

    SetNotificationTextEntry( "STRING" )
    AddTextComponentString( ("%s~h~%s~h~%s:~s~ %s"):format(colour, GetCurrentResourceName(), colour, msg))
    DrawNotification( true, true )
end

Notifications.warn = function(msg)
    Notifications.toast(msg, "~y~")
end

Notifications.error = function(msg)
    Notifications.toast(msg, "~r~")
end

RegisterNetEvent("races:toast")
AddEventHandler("races:toast", function(msg)
    Notifications.toastNotification(msg)
end)

RegisterNetEvent("races:toastWarn")
AddEventHandler("races:toastWarn", function(msg)
    Notifications.warn(msg)
end)

RegisterNetEvent("races:toastError")
AddEventHandler("races:toastError", function(msg)
    Notifications.error(msg)
end)

