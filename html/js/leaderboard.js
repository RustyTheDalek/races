let leaderboard_container = $("#leaderboard_container");
let leaderboard = $("#leaderboard");


let topOffset = 5;

$(function () {
  window.addEventListener("message", readLeaderBoardEvents);
});

function readLeaderBoardEvents(event) {
  let data = event.data;

  if (data.type !== "leaderboard") return;

  switch (data.action) {
    case "add_racers":
      AddRacerToleaderboard(data.racers);
      break;
    case "remove_racer":
      RemovePlayerFromleaderboard(data.source);
      break;
    case "set_leaderboard":
      SetRaceLeaderboard(data.value);
      break;
    case "update_positions":
      UpdatePositions(data.racePositions);
      break;
    case "clear_leaderboard":
      ClearLeaderboard();
      break;
    case "sendRaceData":
      SetRaceData(data.current_lap, data.total_laps, data.total_checkpoints);
      break;
    case "updatecurrentlap":
      UpdateCurrentLap(data.current_lap);
      break;
    case "updatecurrentcheckpoint":
      UpdateCurrentCheckpoint(data.current_checkpoint);
      break;
  }
}

function UpdateCurrentCheckpoint(current_checkpoint) {
  $('#current_checkpoint').html(current_checkpoint);
}

function UpdateCurrentLap(current_lap) {
  $('#current_laps').html(current_lap);
}

function SetRaceData(current_lap, total_laps) {
  UpdateCurrentLap(current_lap);
  if(total_laps > 1) {
    $('#laps').show();
    $('#total_laps').html(total_laps);
  }
  $('#total_checkpoints').html(total_checkpoints);
}

function ClearLeaderboard() {
  $('#current_laps').html(0);
  $('#total_laps').html(0);
  leaderboard_container.hide();
  leaderboard.empty();
}

function UpdatePositions(racePositions) {
  racePositions.forEach((id, position) => {
    $(`#${id}`).val(position + 1);
  });

  SortLeaderboard();
}

function SetRaceLeaderboard(enabled) {
  if (enabled) {
    leaderboard_container.show();
  } else {
    leaderboard_container.hide();
  }
}

function AddRacerToleaderboard(racers) {

  racers.forEach((racer) => {
    let racer_exists = leaderboard.find(`#${racer.source}`).length > 0;

    if (racer_exists) return;

    let racers_in_leaderboard = leaderboard.children().length;

    //Decide on top offset based on position
    let top = racers_in_leaderboard > 0 ? topOffset + racers_in_leaderboard * 3.2 : topOffset - 1;
    //Only add first-place class if it's first item to be added;
    let first_place = racers_in_leaderboard == 0 ? "first-place" : "";

    let racer_element = $("<li/>", {
      id: racer.source,
      value: racers_in_leaderboard + 1,
      class: `leaderboard_chunk ${first_place}`,
      style: `top:${top}rem`,
      text: racer.playerName,
    });

    let racer_position = $("<span/>", { text: `${racers_in_leaderboard + 1}` });

    racer_element.prepend(racer_position);
    leaderboard.append(racer_element);
  });
}

function RemovePlayerFromleaderboard(id) {
  leaderboard.find(`#${id}`).remove();
  SortLeaderboard();
}

function byPollPosition(a, b) {
  let a_position = $(a).val();
  let b_position = $(b).val();

  if (a_position > b_position) {
    return 1;
  } else if (a_position < b_position) {
    return -1;
  }

  return 0;
}

function SortLeaderboard() {
  let racers = leaderboard.children("li");

  racers.sort(byPollPosition);
  racers.each(function (index) {
    offset = index > 0 ? topOffset + index * 3.2 : topOffset - 1;

    if (index == 0) {
      $(this).addClass("first-place");
    } else {
      $(this).removeClass("first-place");
    }

    $(this)
      .find("span")
      .html(index + 1);
    $(this).css("top", `${offset}rem`);
  });
}
