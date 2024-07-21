let listPanel = $("#listPanel");
let allVehicles = $("#all-vehicles");
let currentVehicleList = $("#current-list");
let savedVehicleLists = $("#list_name");
let registerVehicleLists = $('#vehicle-list-options');
let publicSwitch = listPanel.find('input[name="public"]');
let newList = listPanel.find("#new_list");
let listDelete = listPanel.find("#delete_list");

let listModal = $("#listModal");
let modalInputs = listModal.find(`.input-options`);
let modalTextInput = listModal.find(`[name='text']`);
let modalSwitch = listModal.find(`[name='public']`);
let modalConfirm = listModal.find('button[value="confirm"]');
let modalCancel = listModal.find('button[value="cancel"]');

let addVehicleClassButton = listPanel.find('#add_class');
let removeVehicleClassButton = listPanel.find('#delete_class');

$(function () {
	allVehicles.selectable();
	currentVehicleList.selectable();

	$("#add-all").on("click", addAllToCurrentList);
	$("#add-selected").on("click", addSelectedVehiclesToCurrentList);

	$("#remove-all").on("click", removeAll);
	$("#remove-selected").on("click", removeSelectedVehicles);

	addVehicleClassButton.on("click", addVehicleClass);
	removeVehicleClassButton.on("click", removeVehicleClass);

	savedVehicleLists.on("change", onSavedVehicleListsChange);
	newList.on("click", setupModalForNewVehicleList);
	listDelete.on("click", setupModalForDeletelist);

	publicSwitch.on("change", onPublicChange);
	modalTextInput.on("input", validateModalInput);
	modalConfirm.on("click", onModalConfirm);
	modalCancel.on("click", onModalCancel);

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
			populateSavedList(data.vehicleList, data.isPublic);
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

	let selectedList = savedVehicleLists.find(":selected");
	let selectedListName = selectedList.text();

	let selectedAccess = selectedList.closest('optgroup');

	if (privateList !== undefined) {
		privateListOptionGroup.empty();
		privateListOptionGroup.append(MakeOptions(privateList));

		registerVehicleLists.find('[label="Private"]').empty().append(MakeOptions(privateList));
		
	}

	let publicListOptionGroup = savedVehicleLists.find('[label="Public"]');
	if (publicList !== undefined) {
		publicListOptionGroup.empty();
		publicListOptionGroup.append(MakeOptions(publicList));

		registerVehicleLists.find('[label="Public"]').empty().append(MakeOptions(publicList));

	}

	if (selectedListName !== '') {
		selectedAccess.find(`option[value='${selectedListName}']`).prop('selected', 'selected');
	}
}

function populateList(vehicleList) {
	
	let elements = [];
	
	vehicleList.forEach((vehicle) => {
		let vehicleElement = $("<li/>", {
			"data-value" : vehicle.spawnCode, 
			text: vehicle.name,
		});

		let vehicleSpawnCode = $("<p/>", {
			class : "sub-text",
			text: vehicle.spawnCode
		});

		vehicleElement.append(vehicleSpawnCode);

		elements.push(vehicleElement);
	});

	return elements;
}

function populateSavedList(vehicleList, isPublic) {

	setVehicleListControls(true);

	currentVehicleList.empty();

	publicSwitch.prop('checked', isPublic);

	currentVehicleList.append(populateList(vehicleList));
}

function populateAllVehicles(vehicleList) {
	allVehicles.append(populateList(vehicleList));
}

function addVehicles(vehiclesToAdd) {
	let vehiclesAlreadyAdded = currentVehicleList.children();
	let vehiclesToAddArray = vehiclesToAdd.toArray();
	let vehiclesAlreadyAddedArray = vehiclesAlreadyAdded.toArray();

	let filteredVehiclesToAdd = $(vehiclesToAddArray).filter(function (
		index,
		vehicle
	) {
		return !vehiclesAlreadyAddedArray.some(function (addedVehicle) {
			return addedVehicle.innerHTML === vehicle.innerHTML;
		});
	});

	currentVehicleList.append(filteredVehiclesToAdd);

	currentVehicleList
		.children()
		.sort(function (a, b) {
			return $(a).text().toUpperCase().localeCompare($(b).text().toUpperCase());
		})
		.appendTo(currentVehicleList);

	saveCurrentList();
}

function saveCurrentList() {
	// if (currentVehicleList.children() == 0) return;

	$.post(
		"https://races/save_list",
		JSON.stringify({
			access: publicSwitch.prop("checked") ? "pub" : "pvt",
			name: savedVehicleLists.find(":selected").text(),
			vehicles: currentVehicleList.children().map(function () {
				return $(this).text()
			}).get()
		})
	);
}

function setupModalForDeletelist() {
	let currentList = savedVehicleLists.find(":selected");

	if (currentList.text() == "None") return;

	modalInputs.hide();
	listModal.find("h1").text("Are you sure you want to delete this list?");
	modalConfirm.prop("disabled", false);
	modalConfirm.data("action", "delete-list");
	listModal.show();
}

function setupModalForNewVehicleList() {
	listModal.show();
	listModal.find("h1").text("New List Name");
	modalConfirm.data("action", "new-list");
	modalConfirm.prop("disabled", "true");
	modalSwitch.prop('checked', false).show();
	modalTextInput.val("").show();
	modalInputs.show();
}

// #region Input events

function addVehicleClass() {
	$.post(
		"https://races/add_class",
		JSON.stringify({
			class: $("#list_vclass").val(),
			access: publicSwitch.prop("checked") ? "pub" : "pvt",
			name: savedVehicleLists.find(":selected").text(),
		})
	);
}

function removeVehicleClass() {
	$.post(
		"https://races/delete_class",
		JSON.stringify({
			class: $("#list_vclass").val(),
			access: publicSwitch.prop("checked") ? "pub" : "pvt",
			name: savedVehicleLists.find(":selected").text(),
		})
	);
}

function deleteList() {
	let currentList = savedVehicleLists.find(":selected");

	if (currentList.text() == "None") return;

	listModal.hide();

	currentList.remove();

	if (currentVehicleList.children().length == 0) return;

	console.log("list has vehicles");

	$("#delete_list").click(function () {
		$.post(
			"https://races/delete_list",
			JSON.stringify({
				access: $("#listPanel .public-access").prop("checked") ? "pub" : "pvt",
				name: savedVehicleLists.find(":selected").text(),
			})
		);
	});
}

function onPublicChange() {
	let currentList = savedVehicleLists.find(":selected");

	if (currentList.text() == "None") return;

	if (publicSwitch.is(":checked")) {
		currentList.detach().appendTo(savedVehicleLists.find('[label="Public"]'));
	} else {
		currentList.detach().appendTo(savedVehicleLists.find('[label="Private"]'));
	}

	if (currentVehicleList.children().length == 0) return;

	console.log("list has vehicles");

	saveCurrentList();
}

function onModalConfirm() {
	let action = modalConfirm.data("action");

	console.log(action);

	switch (action) {
		case "new-list":
			createNewVehicleList();
			break;
		case "delete-list":
			deleteList();
		default:
			console.warn("No action set");
			break;
	}
}

function createNewVehicleList() {
	let name = modalTextInput.val();
	let public = modalSwitch.is(":checked");

	let option = $("<option/>", {
		selected: "selected",
		value: name,
		text: name,
	});

	let groupToAppend = public
		? savedVehicleLists.find('[label="Public"]')
		: savedVehicleLists.find('[label="Private"]');

	groupToAppend.append(option);
	listModal.hide();
	currentVehicleList.empty();
	publicSwitch.prop('checked', public);
}

function onModalCancel() {
	listModal.hide();
	listModal.find("h1").text("");
	modalTextInput.val("");
	modalConfirm.data("action", null);
}

function validateModalInput() {
	modalConfirm.prop("disabled", !$(this).val());
}

function addAllToCurrentList() {
	let currentList = savedVehicleLists.find(":selected");

	if (currentList.text() == "None") return;

	let vehiclesToAdd = allVehicles.children().clone();
	addVehicles(vehiclesToAdd);
}

function addSelectedVehiclesToCurrentList() {
	let currentList = savedVehicleLists.find(":selected");

	if (currentList.text() == "None") return;

	let vehiclesToAdd = allVehicles
		.find(".ui-selected")
		.removeClass("ui-selected")
		.clone();

	addVehicles(vehiclesToAdd);
}

function removeAll() {
	currentVehicleList.children().detach();

	saveCurrentList();
}

function removeSelectedVehicles() {
	currentVehicleList.find(".ui-selected").detach();

	saveCurrentList();
}

function setVehicleListControls(active) {
	$("#add-all").prop("disabled", !active);
	$("#add-selected").prop("disabled", !active);
	$("#remove-all").prop("disabled", !active);
	$("#remove-selected").prop("disabled", !active);
	$("#add_class").prop("disabled", !active);
	$("#delete_class").prop("disabled", !active);
}

function onSavedVehicleListsChange() {
	switch (this.value) {
		case "None":
			setVehicleListControls(false);
			break;
		default:
			let selectedListAccess = $(this).find(":selected").parent().attr("label");
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
