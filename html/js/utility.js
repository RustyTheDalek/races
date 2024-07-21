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

function MakeVehicleListOptions(list) {
	let options = [];

	list.forEach((vehicle) => {
		let option = $("<option/>", {
			value : vehicle.spawnCode,
			text: `${vehicle.name}: ${vehicle.spawnCode}`,
		});
		options.push(option);
	});

	return options;
}