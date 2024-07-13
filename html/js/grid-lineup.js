let gridContainer = $('#grid-lineup');
let gridTable = $('#grid-lineup-table');
let gridShuffle = $("#grid-lineup #shuffle");

$(function () {

    window.addEventListener("message", readGridEvents);

    gridTable.sortable({
        update: updateGridPositions
    });

    gridShuffle.click(function () {
        let gridPlayers = gridTable.children();
        gridTable.append(gridPlayers.get().reverse());
        updateGridPositions();
    });
});

function readGridEvents(event) {
    let data = event.data;

    if (data.type !== "grid") return;

    switch (data.action) {
        case "add_to_grid":
            addRacersToGrid(data.gridLineup);
            break;
        case "add_racer_to_grid":
            addRacerToGrid(data.racer, true);
            break;
        case "remove_racer_from_grid":
            removeRacerFromGrid(data.source);
            break;
        case "clear_grid":
            gridTable.empty();
            break;
    }
}

function addRacersToGrid(gridLineup) {

    gridTable.empty();

    gridLineup.forEach((racer) => {
        addRacerToGrid(racer)
    });

    updateGridPositions();
}

function addRacerToGrid(racer, moveRacerToGrid = false) {

    let lineUpExists = gridTable.find(`[value="${racer.source}"]`).length > 0;

    if (lineUpExists) return;

    let gridElement = $("<li/>", {
        class: 'box',
        value: racer.source,
        "data-name": racer.name,
        text: racer.name
    });

    if (racer.position !== undefined) {
        console.log("Adding racer with position");
        let previousResult = $("<p/>", {
            text: `#${racer.position} last race`
        });

        gridElement.append(previousResult);
    }

    gridTable.append(gridElement);

    gridTable.sortable({
        update: updateGridPositions
    })

    if ($('#registerPanel').is(":visible")) {
        gridContainer.show();
    }

    if (moveRacerToGrid) {
        updateGridPositions();
    }
}

function removeRacerFromGrid(source) {
    gridTable.find(`[value="${source}"]`).remove();

    if (gridTable.children().length == 0) gridContainer.hide();
    updateGridPositions();
}

function updateGridPositions(event, ui) {
    let updatedGridPositions = $.map(gridTable.children(), function (item, i) {
        return {
            source: $(item).val(),
            name: $(item).data('name'),
            position: i + 1
        }
    });

    console.log(updatedGridPositions)

    $.post("https://races/updateGridPositions",
        JSON.stringify({
            gridLineup: updatedGridPositions
        })
    );
}