let leaderboard_container = $("#leaderboard_container");
let leaderboard = $("#leaderboard");

let topOffset = 6.5;
let spacing = 4.5;

$(function () {
  window.addEventListener("message", readLeaderBoardEvents);
});

function readLeaderBoardEvents(event) {
  let data = event.data;

  if (data.type !== "leaderboard") return;

  switch (data.action) {
    case "add_racers":
      AddRacerToleaderboard(data.racers, data.source);
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
    case "updatecurrentlaptime":
      UpdateCurrentLapTime(data.source, data.minutes, data.seconds);
      break;
    case "updatebestlaptime":
      UpdateBestLapTime(data.source, data.minutes, data.seconds);
      break;
    case "update_vehicle_name":
      UpdateVehicleName(data.source, data.vehicleName);
      break;
    case "update_dnf_time":
      UpdateDNFTime(data.minutes, data.seconds);
      break;
  }
}

function UpdateDNFTime(minutes, seconds) {
  let dnf_containter = $('#dnf_timer_container');
  dnf_containter.addClass('top-visible');

  let dnf_time = dnf_containter.find(`#dnf_timer`);

  let seconds_formatted = seconds.toFixed(2).toString().padStart(5, '0');
  dnf_time.html(`${zeroPad(minutes, 10)}:${seconds_formatted}`);
}

function UpdateVehicleName(source, vehicleName) {
  leaderboard.find(`#${source}`).find('.racer_detail').find('.vehicle').text(vehicleName);
}

function UpdateCurrentLapTime(source, minutes, seconds) {
  UpdateLapTimes("current", source, minutes, seconds);
}

function UpdateBestLapTime(source, minutes, seconds) {
  UpdateLapTimes("best", source, minutes, seconds);
}

function UpdateLapTimes(type, source, minutes, seconds) {
  let seconds_formatted = seconds.toFixed(2).toString().padStart(5, '0');
  let lap_time = leaderboard.find(`#${source} .${type}`);
  lap_time.show();
  lap_time.html(`${zeroPad(minutes, 10)}:${seconds_formatted}`);
}

function UpdateCurrentCheckpoint(current_checkpoint) {
  $('#current_checkpoint').html(current_checkpoint);
}

function UpdateCurrentLap(current_lap) {
  $('#current_laps').html(current_lap);
}

function SetRaceData(current_lap, total_laps, total_checkpoints) {
  UpdateCurrentLap(current_lap);
  if (total_laps > 1) {
    leaderboard_container.find('#laps').addClass('right-visible');
    $('#total_laps').html(total_laps);
  }
  $('#total_checkpoints').html(total_checkpoints);
}

function ClearLeaderboard() {
  leaderboard_container.find('.leaderboard_chunk').removeClass('right-visible');
  $('#current_laps').html(0);
  $('#total_laps').html(0);
  leaderboard.empty();
  $('#dnf_timer_container').removeClass('top-visible');
  $('#dnf_timer_container').find('#dnf_timer').html('00:00.00');
}

function UpdatePositions(racePositions) {
  racePositions.forEach((id, position) => {
    $(`#${id}`).val(position + 1);
  });

  SortLeaderboard();
}

function SetRaceLeaderboard(enabled) {
  if (enabled) {
    leaderboard_container.find('#leaderboard').find('.leaderboard_chunk').addClass('right-visible');
    leaderboard_container.find('#checkpoints').addClass('right-visible');
  } else {
    leaderboard_container.find('.leaderboard_chunk').removeClass('right-visible');
  }
}

function AddRacerToleaderboard(racers, source) {

  racers.forEach((racer) => {
    let racer_exists = leaderboard.find(`#${racer.source}`).length > 0;

    if (racer_exists) return;

    let racers_in_leaderboard = leaderboard.children().length;

    //Decide on top offset based on position
    let top = racers_in_leaderboard > 0 ? topOffset + racers_in_leaderboard * spacing : topOffset - 0.5;
    //Only add first-place class if it's first item to be added;
    let first_place = racers_in_leaderboard == 0 ? "first-place" : "";
    let current_racer = source === racer.source  ? "current_racer" : "";

    let racer_element = $("<li/>", {
      id: racer.source,
      value: racers_in_leaderboard + 1,
      class: `leaderboard_chunk not-ready ${first_place} ${current_racer}`,
      style: `top:${top}rem`,
    });

    let racer_detail = $("<div/>", {
      class: 'racer_detail'
    });

    racer_element.append(racer_detail);
    
    let racer_name = $("<div/>", {
      class: 'racer',
      text: racer.playerName
    });

    racer_detail.append(racer_name);

    let vehicle = $("<div/>", {
      class: 'vehicle',
      text: racer.vehicleName
    });

    racer_detail.append(vehicle);

    let racer_position = $("<span/>", { text: `${racers_in_leaderboard + 1}` });

    racer_element.prepend(racer_position);

    let lap_times = $("<div/>", {
      class: 'lap_times'
    });

    let best_lap = $("<div/>", {
      class: 'best',
      text: '00:00.00'
    });

    let current_lap = $("<div/>", {
      style: 'display:none;',
      class: 'current',
      text: '00:00.00'
    });

    lap_times.append(best_lap);
    lap_times.append(current_lap);

    racer_element.append(lap_times);
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
    offset = index > 0 ? topOffset + index * spacing : topOffset - 0.5;

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

function zeroPad(nr,base){
  var  len = (String(base).length - String(nr).length)+1;
  return len > 0? new Array(len).join('0')+nr : nr;
}
