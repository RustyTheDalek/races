let listPanel = $("#listPanel");
let allVehicles = $("#all-vehicles");
let currentVehicleList = $("#current-list");
let savedVehicleLists = $('#list_name');
let publicSwitch = listPanel.find('input[name="public"');
let listDelete = listPanel.find('#delete_list');

let listModal = $('#listModal');
let modalInput = listModal.find(`[name=modal-input]`);
let modalConfirm = listModal.find('button[value="confirm"]');
let modalCancel = listModal.find('button[value="cancel"]');

$(function () {
    allVehicles.selectable();
    currentVehicleList.selectable();

    $('#add-all').on("click", addAllToCurrentList);
    $('#add-selected').on("click", addSelectedVehiclesToCurrentList);

    $('#remove-all').on("click", removeAll);
    $('#remove-selected').on("click", removeSelectedVehicles);

    savedVehicleLists.on('change', onSavedVehicleListsChange);
    listDelete.on('click', setupModalForDeletelist);

    publicSwitch.on('change', onPublicChange);
    modalInput.on('input', validateModalInput);
    modalConfirm.on('click', onModalConfirm);
    modalCancel.on('click', onModalCancel);

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

    let privateListOptionGroup = savedVehicleLists.find('[label="Private"]');

    if (privateList !== undefined)
        privateListOptionGroup.append(MakeOptions(privateList));

    let publicListOptionGroup = savedVehicleLists.find('[label="Public"]');
    if (publicList !== undefined)
        publicListOptionGroup.append(MakeOptions(publicList));
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

    vehicleList.forEach(listName => {
        let vehicleElement = $("<li/>", {
            text: name
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

function setupModalForDeletelist() {

    let currentList = savedVehicleLists.find(":selected")
    
    if (currentList.text() == 'None' || currentList.text() == 'New') return;

    modalInput.hide();
    listModal.find('h1').text('Are you sure you want to delete this list?');
    modalConfirm.data('action', 'delete-list');
    listModal.show();
}

function setupModalForNewVehicleList() {
    listModal.show();
    listModal.find('h1').text('New List Name');
    modalInput.val('').show();
    modalConfirm.data('action', 'new-list');
}

// #region Input events

function deleteList() {

    let currentList = savedVehicleLists.find(":selected")
    
    if (currentList.text() == 'None' || currentList.text() == 'New') return;

    listModal.hide();

    currentList.remove();
    
    if(currentVehicleList.children().length == 0) return;

    console.log("list has vehicles");
}

function onPublicChange() {

    let currentList = savedVehicleLists.find(":selected")

    if (currentList.text() == 'None' || currentList.text() == 'New') return;

    if(publicSwitch.is(':checked')) {
        currentList.detach().appendTo(savedVehicleLists.find('[label="Public"]'));
    } else {
        currentList.detach().appendTo(savedVehicleLists.find('[label="Private"]'));
    }

    if(currentVehicleList.children().length == 0) return;

    console.log("list has vehicles");
}

function onModalConfirm() {

    let action = modalConfirm.data('action');

    console.log(action);

    switch (action) {
        case 'new-list':
            createNewVehicleList();
            break;
        case 'delete-list':
            deleteList();
        default:
            console.warn("No action set");
            break;
    }
}

function createNewVehicleList() {
    let name = modalInput.val();
    let public = publicSwitch.is(":checked");

    let option = $("<option/>", {
        selected: "selected",
        value: name,
        text: name,
    })

    let groupToAppend = public ? savedVehicleLists.find('[label="Public"]') : savedVehicleLists.find('[label="Private"]');

    groupToAppend.append(option);
    listModal.hide();
}

function onModalCancel() {
    listModal.hide();
    listModal.find('h1').text('');
    modalInput.val('');
    modalConfirm.data('action', null);
}

function validateModalInput() {
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
    switch (this.value) {
        case "New":
            setupModalForNewVehicleList();
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