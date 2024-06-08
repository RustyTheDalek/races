$(function () {
    window.addEventListener("message", readEditorEvent);
});

function readEditorEvent(event) {
    let data = event.data;

    if (data.type !== "editor") return;

    switch (data.action) {
        case "update_closest_waypoint":
            updateClosestWaypoint(data.waypointIndex);
            break;
        case "update_selected_waypoint":
            updateSelectedWaypoint(data.waypointIndex);
            break;
        default:
            console.warn(`${data.action} isn't accounted for`);
            break;
    }
}

function updateClosestWaypoint(waypointIndex) {
    $('#closest-waypoint').text(waypointIndex);
}

function updateSelectedWaypoint(waypointIndex) {
    $('#selected-waypoint').text(waypointIndex);
}