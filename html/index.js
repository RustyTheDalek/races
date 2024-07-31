let updateCountdownTimerID = null;
let countdownTime = null;

function updateCountdownTimer() {
  --countdownTime;

  if (countdownTime <= 0) {
    $("#preRaceCountdown").html();
    StopPreRaceCountdown();
    clearInterval(updateCountdownTimerID);
    updateCountdownTimerID = null;
  } else {
    $("#preRaceCountdown").html(countdownTime);
  }
}

function StartPreRaceCountdown(countdown) {
  $("#preRaceCountdown").html(countdown);
  $("#preRaceCountdownContainer").removeClass("top-hidden");
  countdownTime = countdown;
  if (!updateCountdownTimerID) {
    updateCountdownTimerID = setInterval(updateCountdownTimer, 1000);
  }
}

function StopPreRaceCountdown() {
  $("#preRaceCountdownContainer").addClass("top-hidden");

  if (!updateCountdownTimerID) {
    clearInterval(updateCountdownTimerID);
    updateCountdownTimerID = null;
  }
}

$(function () {
  let replyOpen = false;
  let openPanel = "";
  let pvtTrackNames = "";
  let pubTrackNames = "";

  let registerPanel = $("#registerPanel").show();

  $("#mainPanel").hide();
  $("#editPanel").hide();
  $("#registerPanel").hide();
  $("#listPanel").hide();
  $("#replyPanel").hide();

  function UpdateRacer(racer) {
    let racer_chunk = $(`#leaderboard_container`).find(`#${racer.source}`);

    if (racer.ready) {
      racer_chunk.addClass("ready");
      racer_chunk.removeClass("not-ready");
    } else {
      racer_chunk.addClass("not-ready");
      racer_chunk.removeClass("ready");
    }
  }

  function ClearReady() {
    $(`#leaderboard_container`)
      .find(".leaderboard_chunk")
      .removeClass("not-ready");
    $(`#leaderboard_container`).find(".leaderboard_chunk").removeClass("ready");
    SetReadyText(false);
  }

  function handleReady(data) {
    switch (data.action) {
      case "send_racer_ready_data":
        UpdateRacer(data.racer);
        break;
      case "clear_ready":
        ClearReady();
        break;
      case "set_ready_text":
        SetReadyText(data.value);
        break;
      case "set_join_text":
        SetJoinMessage(data.value);
        break;
      case "startPreRaceCountdown":
        StartPreRaceCountdown(data.countdown);
        break;
      case "stopPreRaceCountdown":
        StopPreRaceCountdown();
        break;
    }
  }

  function SetJoinMessage(value) {
    let join_message = $("#join-message");
    if (value !== "") {
      join_message.text(value);
      join_message.addClass("bottom-visible");
    } else {
      join_message.removeClass("bottom-visible");
    }
  }

  function SetReadyText(value) {
    let ready_message = $("#ready-message");
    if (value === true) {
      ready_message.addClass("bottom-visible");
    } else {
      ready_message.removeClass("bottom-visible");
    }
  }

  function handleRaceManagement(data) {
    switch (data.action) {
      case "send_maps":
        AddMaps(data.maps);
        break;
    }
  }

  function AddMaps(maps) {
    for (map in maps) {
      let formattedMapName = map
        .replace(/([A-Z])/g, " $1")
        .replace(/_/g, " ")
        .replace(/[^0-9](?=[0-9])/g, "$& ")
        .trim();

      $("#map").append(
        $("<option>", {
          value: map,
          text: formattedMapName,
        })
      );
    }
  }

  function populateOptgroup(data, optgroup) {

    if(!Array.isArray(data)) {
      console.warn("data isn't an array");
      return;
    }

    data.forEach((item) => {
      optgroup.append(
        $("<option/>", {
          value: item,
          text: item,
        })
      );
    });
  }

  function populateTrackNames(selectToPopulate) {

    let privateListGroup = selectToPopulate.find(`optgroup[label='Private']`);
    let publicListGroup = selectToPopulate.find(`optgroup[label='Public']`);

    privateListGroup.empty();
    publicListGroup.empty();

    populateOptgroup(pvtTrackNames, privateListGroup);
    populateOptgroup(pubTrackNames, publicListGroup);
  }

  window.addEventListener("message", function (event) {
    let data = event.data;
    if (data.type === "ready") {
      handleReady(data);
    } else if (data.type === "race_management") {
      console.log("Reading Race Management event");
      handleRaceManagement(data);
    } else if ("main" == data.panel) {
      $("#main_vehicle").val(data.defaultVehicle);
      $("#mainPanel").show();
      openPanel = "main";
    } else if ("edit" == data.panel) {
      $("#editPanel").show();
      openPanel = "edit";
    } else if ("register" == data.panel) {
      openPanel = OpenRegisterPanel(data, openPanel);
    } else if ("list" == data.panel) {
      $("#listPanel").show();
      openPanel = "list";
    } else if ("reply" == data.panel) {
      $("#mainPanel").hide();
      $("#editPanel").hide();
      $("#registerPanel").hide();
      $("#listPanel").hide();
      document.getElementById("message").innerHTML = data.message;
      $("#replyPanel").show();
      replyOpen = true;
    } else if ("trackNames" == data.update) {
      if ("pvt" == data.access) {
        pvtTrackNames = data.trackNames;
      } else if ("pub" == data.access) {
        pubTrackNames = data.trackNames;
      }

      populateTrackNames($("#main_name"));
      populateTrackNames($("#edit_name"));
      populateTrackNames($("#register_name"));
    }
  });

  /* #region main panel */

  $("#main_clear").click(function () {
    $.post("https://races/clear");
  });

  $("#main_load").click(function () {
    $.post(
      "https://races/load",
      JSON.stringify({
        access: $('#main_name').find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
        trackName: $("#main_name").val(),
      })
    );
  });

  $("#main_blt").click(function () {
    $.post(
      "https://races/blt",
      JSON.stringify({
        access: $('#main_name').find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
        trackName: $("#main_name").val(),
      })
    );
  });

  $("#main_list").click(function () {
    $.post(
      "https://races/list",
      JSON.stringify({
        access: $('#main_name').find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
      })
    );
  });

  $("#leave").click(function () {
    $.post("https://races/leave");
  });

  $("#respawn").click(function () {
    $.post("https://races/respawn");
  });

  $("#results").click(function () {
    $.post("https://races/results");
  });

  $("#spawn").click(function () {
    $.post(
      "https://races/spawn",
      JSON.stringify({
        vehicle: $("#main_vehicle").val(),
      })
    );
  });

  $("#speedo").click(function () {
    $.post(
      "https://races/speedo",
      JSON.stringify({
        unit: "",
      })
    );
  });

  $("#change").click(function () {
    $.post(
      "https://races/speedo",
      JSON.stringify({
        unit: $("#unit").val(),
      })
    );
  });

  $("#main_edit").click(function () {
    $("#mainPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "edit",
      })
    );
  });

  $("#main_register").click(function () {
    $("#mainPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "register",
      })
    );
  });

  $("#main_vlist").click(function () {
    $("#mainPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "list",
      })
    );
  });

  $("#main_close").click(function () {
    $("#mainPanel").hide();
    $.post("https://races/close");
  });

  /* #endregion */

  /* #region edit panel */
  $("#edit").click(function () {
    $.post("https://races/edit");
  });

  $("#edit_clear").click(function () {
    $.post("https://races/clear");
  });

  $("#edit_reverse").click(function () {
    $.post("https://races/reverse");
  });

  $("#map").change(function () {
    $.post(
      "https://races/setnewmap",
      JSON.stringify({
        map: $(this).val(),
      })
    );
  });

  $("#edit_load").click(function () {
    $.post(
      "https://races/load",
      JSON.stringify({
        access: $("#edit_name").find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
        trackName: $("#edit_name").val(),
      })
    );
  });

  $("#edit_overwrite").click(function () {
    $.post(
      "https://races/overwrite",
      JSON.stringify({
        access: $("#edit_name").find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
        trackName: $("#edit_name").val(),
        map: $("#map").val(),
      })
    );
  });

  $("#edit_delete").click(function () {
    $.post(
      "https://races/delete",
      JSON.stringify({
        access: $("#edit_name").find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
        trackName: $("#edit_name").val(),
      })
    );
  });

  $("#edit_blt").click(function () {
    $.post(
      "https://races/blt",
      JSON.stringify({
        access: $("#edit_name").find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
        trackName: $("#edit_name").val(),
      })
    );
  });

  $("#edit_list").click(function () {
    $.post(
      "https://races/list",
      JSON.stringify({
        access: $("#edit_name").find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
      })
    );
  });

  $("#edit_save").click(function () {
    $.post(
      "https://races/save",
      JSON.stringify({
        access: $("#edit_track_access1").val(),
        trackName: $("#edit_unsaved").val(),
      })
    );
  });

  $("#edit_main").click(function () {
    $("#editPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "main",
      })
    );
  });

  $("#edit_register").click(function () {
    $("#editPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "register",
      })
    );
  });

  $("#edit_vlist").click(function () {
    $("#editPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "list",
      })
    );
  });

  $("#edit_close").click(function () {
    $("#editPanel").hide();
    $.post("https://races/close");
  });

  /* #endregion */

  /* #region register panel */

  $("#register_load").click(function () {
    $.post(
      "https://races/load",
      JSON.stringify({
        access:  $("#register_name").find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
        trackName: $("#register_name").val(),
      })
    );
  });

  $("#register_blt").click(function () {
    $.post(
      "https://races/blt",
      JSON.stringify({
        access: $("#register_name").find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
        trackName: $("#register_name").val(),
      })
    );
  });

  $("#register_list").click(function () {
    $.post(
      "https://races/list",
      JSON.stringify({
        access: $("#register_name").find(":selected").parent().attr("label") === "Public" ? 'pub' : 'pvt',
      })
    );
  });

  $("#rtype").change(function () {
    if ($("#rtype").val() == "norm") {
      $("#rest").hide();
      $("#vehicle-list-options").hide();
      $("#vclass").hide();
      $("#sveh").hide();
    } else if ($("#rtype").val() == "rest") {
      $("#rest").show();
      registerPanel.find("#vehicle-list-options").show();
      $("#vclass").hide();
      $("#sveh").hide();
    } else if ($("#rtype").val() == "class") {
      $("#rest").hide();
      registerPanel.find("#vehicle-list-options").show();
      $("#vclass").show();
      $("#sveh").hide();
    } else if ($("#rtype").val() == "rand") {
      DisplayRandomOptions(html);
    }
  });

  $("#register").click(function () {
    let selectedVehicleList = registerPanel
      .find("[name=vehicle-list]")
      .find(":selected");

    $.post(
      "https://races/register",
      JSON.stringify({
        tier: $("#tier").find(":selected").val(),
        specialClass: $("#specialClass").find(":selected").val(),
        laps: $("#registerPanel").find("#laps").val(),
        timeout: $("#timeout").val(),
        rtype: $("#rtype").val(),
        restrict: $("#register_rest_vehicle").val(),
        vclass: $("#register_vclass").val(),
        svehicle: $("#register_start_vehicle").val(),
        randomVehicleList: selectedVehicleList.val(),
        randomVehicleListPublic:
          selectedVehicleList.parent().attr("label") == "Public" ? true : false,
      })
    );
  });

  $("#unregister").click(function () {
    $.post("https://races/unregister");
  });

  $("#auto-join").click(function () {
    $.post("https://races/autojoin");
  });

  $("#grid-racers").click(function () {
    $.post("https://races/gridracers");
  });

  $("#start").click(function () {
    $.post(
      "https://races/start",
      JSON.stringify({
        delay: $("#delay").val(),
      })
    );
  });

  $("#register_main").click(function () {
    $("#registerPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "main",
      })
    );
  });

  $("#register_edit").click(function () {
    $("#registerPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "edit",
      })
    );
  });

  $("#register_vlist").click(function () {
    $("#registerPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "list",
      })
    );
  });

  $("#register_close").click(function () {
    $("#registerPanel").hide();
    $("#grid-lineup").hide();
    $.post("https://races/close");
  });

  /* #endregion */

  /* ]region vehicle list panel */

  $("#vlist_main").click(function () {
    $("#listPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "main",
      })
    );
  });

  $("#vlist_edit").click(function () {
    $("#listPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "edit",
      })
    );
  });

  $("#vlist_register").click(function () {
    $("#listPanel").hide();
    $.post(
      "https://races/show",
      JSON.stringify({
        panel: "register",
      })
    );
  });

  /* #endregion */

  function openCurrentPanel() {
    switch (openPanel) {
      case "main":
          $("#mainPanel").show();
        break;
      case "edit":
          $("#editPanel").show();
        break;
      case "register":
          $("#registerPanel").show();
        break;
      case "list":
          $("#listPanel").show();
        break;
      default:
        $("#mainPanel").hide();
        $("#editPanel").hide();
        $("#registerPanel").hide();
        $("#listPanel").hide();
        $.post("https://races/close");
        break;
      }
    }

  /* reply panel */
  $("#reply_close").click(function () {
    $("#replyPanel").hide();
    replyOpen = false;
    openCurrentPanel();
  });

  document.onkeyup = function (data) {
    if (data.key != "Escape") return;

    if (replyOpen) {
      $("#replyPanel").hide();
      replyOpen = false;
    }

    openCurrentPanel();
  };

  if (window.jQuery) {
    $.post("https://races/uiReady");
  }
});

function DisplayRandomOptions(html) {
  $("#rest").hide();
  $("#vehicle-list-options").show();
  $("#vclass").show();
  $("#sveh").show();
}

function OpenRegisterPanel(data, openPanel) {
  $("#tier").change();
  $("#specialClass").change();
  $("#laps").val(data.defaultLaps);
  $("#timeout").val(data.defaultTimeout);
  $("#delay").val(data.defaultDelay);
  $("#rtype").change();

  let vehicleOptions = MakeVehicleListOptions(data.allVehicles);

  $("#register_rest_vehicle").empty().append(vehicleOptions);
  $("#register_start_vehicle")
    .empty()
    .append('<option selected value=""></option>')
    .append(vehicleOptions.map((option) => option.clone()));
  $("#registerPanel").show();
  openPanel = "register";

  if ($("#grid-lineup-table").children().length > 0) {
    $("#grid-lineup").show();
  }
  return openPanel;
}
