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
            updateSelectedWaypoint(data.waypointIndex, data.pointsTo);
            break;
        default:
            console.warn(`${data.action} isn't accounted for`);
            break;
    }
}

function updateClosestWaypoint(waypointIndex) {
    $('#closest-waypoint').text(waypointIndex);
}

function updateSelectedWaypoint(waypointIndex, pointsTo) {
    $('#selected-waypoint').text(waypointIndex);
    $('#points-to').text(pointsTo ?? 'none');
}