let listPanel = $("#listPanel");
let allVehicles = $("#all-vehicles");
let currentVehicleList = $("#current-list");
let savedVehicleLists = $('#list_name');
let listModal = $('#listModal');

$(function () {
    allVehicles.selectable();
    currentVehicleList.selectable();

    $('#add-all').on("click", addAllToCurrentList);
    $('#add-selected').on("click", addSelectedVehiclesToCurrentList);

    $('#remove-all').on("click", removeAll);
    $('#remove-selected').on("click", removeSelectedVehicles);

    savedVehicleLists.on('change', onSavedVehicleListsChange);

    listModal.find(`[name=modal-input]`).on('input', validateModalInput);

    window.addEventListener("message", readVehicleListEvents);

});

function readVehicleListEvents(event) {
    let data = event.data;

    if (data.type !== "vehicle-list") return;

    switch (data.action) {
        case "display_list":
            populateAllVehicles(data.allVehicles);
            listPanel.show();
            break;
        case "display_saved_list":
            populateSavedList(data.vehicleList);
            break;
        case "recieve_lists":
            updateVehicleLists(data.public, data.private);
            break;

    }
}

function updateVehicleLists(publicList, privateList) {
    pvtListNames = privateList;
    pubListNames = publicList;

    let privateListOptionGroup = $("<optgroup/>", { label: "Private" });

    if (privateList !== undefined)
        privateListOptionGroup.append(MakeOptions(privateList));

    let publicListOptionGroup = $("<optgroup/>", { label: "Public" });
    if (publicList !== undefined)
        publicListOptionGroup.append(MakeOptions(publicList));

    savedVehicleLists.append([privateListOptionGroup, publicListOptionGroup]);
}

function MakeOptions(list) {
    let options = [];

    list.forEach((name) => {
        options.push(
            $("<option/>", {
                value: name,
                text: name,
            })
        );
    });

    return options;
}

function populateSavedList(vehicleList) {

    currentVehicleList.empty();

    vehicleList.forEach(vehicle => {
        let vehicleElement = $("<li/>", {
            text: vehicle
        });
        currentVehicleList.append(vehicleElement)
    });
}

function populateAllVehicles(vehicleList) {
    vehicleList.forEach(vehicle => {
        let vehicleElement = $("<li/>", {
            text: vehicle
        });

        allVehicles.append(vehicleElement)
    });
}

function addVehicles(vehiclesToAdd) {

    let vehiclesAlreadyAdded = currentVehicleList.children();
    let vehiclesToAddArray = vehiclesToAdd.toArray();
    let vehiclesAlreadyAddedArray = vehiclesAlreadyAdded.toArray();

    let filteredVehiclesToAdd = $(vehiclesToAddArray).filter(function (index, vehicle) {
        return !vehiclesAlreadyAddedArray.some(function (addedVehicle) {
            return addedVehicle.innerHTML === vehicle.innerHTML;
        });
    });

    currentVehicleList.append(filteredVehiclesToAdd);

    currentVehicleList.children().sort(function (a, b) {
        return $(a).text().toUpperCase().localeCompare($(b).text().toUpperCase());
    }).appendTo(currentVehicleList);
}

function createNewVehicleList() {
    listModal.show();
    listModal.find('h1').text('New List Name');
    listModal.find('confirm').data('action', 'new-list');
}


// #region Input events

function validateModalInput(){
    console.log($(this).val());
    $(this).next().prop('disabled', !$(this).val());
}

function addAllToCurrentList() {
    let vehiclesToAdd = allVehicles.children().clone();
    addVehicles(vehiclesToAdd);
}

function addSelectedVehiclesToCurrentList() {
    let vehiclesToAdd = allVehicles.find('.ui-selected').removeClass('ui-selected').clone();

    addVehicles(vehiclesToAdd);
}

function removeAll() {
    currentVehicleList.children().detach();
}

function removeSelectedVehicles() {
    currentVehicleList.find('.ui-selected').detach();
}

function onSavedVehicleListsChange() {
    console.log(this.value);
    switch (this.value) {
        case "New":
            createNewVehicleList();
            break;
        default:
            let selectedListAccess = $(this).find(":selected").parent().attr('label');
            $.post(
                "https://races/load_list",
                JSON.stringify({
                    access: selectedListAccess,
                    name: this.value,
                })
            );
            break;
    }
}

// #endregion