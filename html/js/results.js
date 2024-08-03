let resultsContainer = $('#results_container');
let resultsTable = resultsContainer.find('table');
let trackNameText = resultsContainer.find('.race_name');
let lapsText = resultsContainer.find('.laps');
let resultsTableData = resultsTable.find('tbody');

let leaderboardDisplayLength = 5;

$(function () {
    window.addEventListener("message", readResultEvents);
});

function readResultEvents(event) {
    let data = event.data;

    if(data.type !== "results") return;

    switch(data.action) {
        case "show_race_results":
            showRaceResults(data.results, data.numberOfLaps, data.trackName);
            break;
    }
}

function showRaceResults(results, laps, trackName) {

    resultsTableData.empty();

    populateResults(results);

    lapsText.text(laps > 1 ? `${laps} laps` : '' );
    trackNameText.text(trackName)


    resultsContainer.addClass('visible');

    setTimeout(() => {
        resultsContainer.removeClass('visible');
    }, (leaderboardDisplayLength) * 1000);
}

function populateResults(results) {
    results.forEach((result) => {
        addResult(result);
    });
}

function addResult(result) {

    let resultRow = $("<tr/>");

    resultRow.append(createTD(result.position));
    resultRow.append(createTD(result.playerName));
    resultRow.append(createTD(result.time));
    resultRow.append(createTD(result.fastestLap));
    resultRow.append(createTD(result.vehicleName));
    resultRow.append(createTD(result.averageFPS.toFixed(0)));

    resultsTable.find('tbody').append(resultRow);
}

function createTD(text) {
    return $("<td/>", { text: text });
}