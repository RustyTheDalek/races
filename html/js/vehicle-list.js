let allVehicles = $("#all-vehicles");
let currentVehicleList = $("#current-list");

$(function () {
    allVehicles.selectable();
    currentVehicleList.selectable();

    $('#add-all').on("click", addAll);
    $('#add-selected').on("click", addSelectedVehicles);

    $('#remove-all').on("click", removeAll);
    $('#remove-selected').on("click", removeSelectedVehicles);
});

function addAll() {
    let vehiclesToAdd = allVehicles.children().clone();
    console.log(vehiclesToAdd);
    addVehicles(vehiclesToAdd);
}

function addSelectedVehicles() {
    let vehiclesToAdd = allVehicles.find('.ui-selected').removeClass('ui-selected').clone();
    addVehicles(vehiclesToAdd);
}

function addVehicles(vehiclesToAdd) {
    let vehiclesAlreadyAdded = currentVehicleList.children();

    let vehiclesToAddArray = vehiclesToAdd.toArray();
    let vehiclesAlreadyAddedArray = vehiclesAlreadyAdded.toArray();

    function getVehicleValue(element) {
        return $(element).val();
    }

    let filteredVehiclesToAdd = $(vehiclesToAddArray).filter(function (index, vehicle) {
        let vehicleValue = getVehicleValue(vehicle);
        return !vehiclesAlreadyAddedArray.some(function (addedVehicle) {
            return getVehicleValue(addedVehicle) === vehicleValue;
        });
    });

    console.log(filteredVehiclesToAdd);

    currentVehicleList.append(filteredVehiclesToAdd);
}

function removeAll() {
    currentVehicleList.children().detach();
}

function removeSelectedVehicles() {
    currentVehicleList.find('.ui-selected').detach();
}