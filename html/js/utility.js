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