var selectedWaypointContainer;

$(function () {
    window.addEventListener("message", readEditorEvent);

    selectedWaypointContainer = $('#selected-waypoint-container');

});

function readEditorEvent(event) {
    let data = event.data;

    if (data.type !== "editor") return;

    switch (data.action) {
        case "toggle_editor_view":
            toggleEditorView();
            break;
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

function toggleEditorView() {
    $('#editor-info').toggle();
}

function updateClosestWaypoint(waypointIndex) {
    $('#closest-waypoint').text(waypointIndex);
}

function updateSelectedWaypoint(waypointIndex, pointsTo) {
    if(waypointIndex == 'none') {
        selectedWaypointContainer.hide();
        selectedWaypointContainer.find('.waypoint').text('');
        selectedWaypointContainer.find('.points-to').text('');
    } else {     
        selectedWaypointContainer.show();
        selectedWaypointContainer.find('.waypoint').text(waypointIndex);
        selectedWaypointContainer.find('.points-to').text(pointsTo ?? 'none');
    }
}