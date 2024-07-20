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
  let pvtGrpNames = "";
  let pubGrpNames = "";
  let pvtListNames = "";
  let pubListNames = "";

  let registerPanel = $("#registerPanel").show();

  $("#mainPanel").hide();
  $("#editPanel").hide();
  $("#registerPanel").hide();
  // $("#listPanel").hide();
  // $("#replyPanel").hide();

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
      $("#main_track_access").change();
      $("#edit_track_access0").change();
      $("#register_track_access").change();
    } else if ("grpNames" == data.update) {
      if ("pvt" == data.access) {
        pvtGrpNames = data.grpNames;
      } else if ("pub" == data.access) {
        pubGrpNames = data.grpNames;
      }
      $("#grp_access0").change();
    } else if ("listNames" == data.update) {
      console.log("Updating vehicle list");
      if ("pvt" == data.access) {
        pvtListNames = data.listNames;
      } else if ("pub" == data.access) {
        pubListNames = data.listNames;
      }
    }
  });

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

  /* main panel */

  $("#main_clear").click(function () {
    $.post("https://races/clear");
  });

  $("#main_track_access").change(function () {
    if ("pvt" == $("#main_track_access").val()) {
      document.getElementById("main_name").innerHTML = pvtTrackNames;
    } else {
      document.getElementById("main_name").innerHTML = pubTrackNames;
    }
  });

  $("#main_load").click(function () {
    $.post(
      "https://races/load",
      JSON.stringify({
        access: $("#main_track_access").val(),
        trackName: $("#main_name").val(),
      })
    );
  });

  $("#main_blt").click(function () {
    $.post(
      "https://races/blt",
      JSON.stringify({
        access: $("#main_track_access").val(),
        trackName: $("#main_name").val(),
      })
    );
  });

  $("#main_list").click(function () {
    $.post(
      "https://races/list",
      JSON.stringify({
        access: $("#main_track_access").val(),
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

  $("#lvehicles").click(function () {
    $.post(
      "https://races/lvehicles",
      JSON.stringify({
        vclass: $("#main_vclass").val(),
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

  /* edit panel */
  $("#edit").click(function () {
    $.post("https://races/edit");
  });

  $("#edit_clear").click(function () {
    $.post("https://races/clear");
  });

  $("#edit_reverse").click(function () {
    $.post("https://races/reverse");
  });

  $("#edit_track_access0").change(function () {
    if ("pvt" == $("#edit_track_access0").val()) {
      document.getElementById("edit_name").innerHTML = pvtTrackNames;
    } else {
      document.getElementById("edit_name").innerHTML = pubTrackNames;
    }
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
        access: $("#edit_track_access0").val(),
        trackName: $("#edit_name").val(),
      })
    );
  });

  $("#edit_overwrite").click(function () {
    $.post(
      "https://races/overwrite",
      JSON.stringify({
        access: $("#edit_track_access0").val(),
        trackName: $("#edit_name").val(),
        map: $("#map").val(),
      })
    );
  });

  $("#edit_delete").click(function () {
    $.post(
      "https://races/delete",
      JSON.stringify({
        access: $("#edit_track_access0").val(),
        trackName: $("#edit_name").val(),
      })
    );
  });

  $("#edit_blt").click(function () {
    $.post(
      "https://races/blt",
      JSON.stringify({
        access: $("#edit_track_access0").val(),
        trackName: $("#edit_name").val(),
      })
    );
  });

  $("#edit_list").click(function () {
    $.post(
      "https://races/list",
      JSON.stringify({
        access: $("#edit_track_access0").val(),
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

  /* register panel */
  $("#register_track_access").change(function () {
    if ("pvt" == $("#register_track_access").val()) {
      document.getElementById("register_name").innerHTML = pvtTrackNames;
    } else {
      document.getElementById("register_name").innerHTML = pubTrackNames;
    }
  });

  $("#register_load").click(function () {
    $.post(
      "https://races/load",
      JSON.stringify({
        access: $("#register_track_access").val(),
        trackName: $("#register_name").val(),
      })
    );
  });

  $("#register_blt").click(function () {
    $.post(
      "https://races/blt",
      JSON.stringify({
        access: $("#register_track_access").val(),
        trackName: $("#register_name").val(),
      })
    );
  });

  $("#register_list").click(function () {
    $.post(
      "https://races/list",
      JSON.stringify({
        access: $("#register_track_access").val(),
      })
    );
  });

  $("#rtype").change(function () {
    let html =
      "<option value = 0>0:Compacts</option>" +
      "<option value = 1>1:Sedans</option>" +
      "<option value = 2>2:SUVs</option>" +
      "<option value = 3>3:Coupes</option>" +
      "<option value = 4>4:Muscle</option>" +
      "<option value = 5>5:Sports Classics</option>" +
      "<option value = 6>6:Sports</option>" +
      "<option value = 7>7:Super</option>" +
      "<option value = 8>8:Motorcycles</option>" +
      "<option value = 9>9:Off-road</option>" +
      "<option value = 10>10:Industrial</option>" +
      "<option value = 11>11:Utility</option>" +
      "<option value = 12>12:Vans</option>" +
      "<option value = 13>13:Cycles</option>" +
      "<option value = 14>14:Boats</option>" +
      "<option value = 15>15:Helicopters</option>" +
      "<option value = 16>16:Planes</option>" +
      "<option value = 17>17:Service</option>" +
      "<option value = 18>18:Emergency</option>" +
      "<option value = 19>19:Military</option>" +
      "<option value = 20>20:Commercial</option>" +
      "<option value = 21>21:Trains</option>";
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
      document.getElementById("register_vclass").innerHTML =
        "<option value = -1>-1:Custom</option>" + html;
			registerPanel.find("#vehicle-list-options").show();
			$("#vclass").show();
      $("#sveh").hide();
    } else if ($("#rtype").val() == "rand") {
      DisplayRandomOptions(html);
    }
  });

  $("#register").click(function () {

    let selectedVehicleList = registerPanel.find("[name=vehicle-list]").find(":selected");

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
        randomVehicleListPublic : selectedVehicleList.parent().attr('label') == "Public" ? true : false
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

  $("#grp_access0").change(function () {
    if ("pvt" == $("#grp_access0").val()) {
      document.getElementById("grp_name").innerHTML = pvtGrpNames;
    } else {
      document.getElementById("grp_name").innerHTML = pubGrpNames;
    }
  });

  $("#load_grp").click(function () {
    $.post(
      "https://races/load_grp",
      JSON.stringify({
        access: $("#grp_access0").val(),
        name: $("#grp_name").val(),
      })
    );
  });

  $("#overwrite_grp").click(function () {
    $.post(
      "https://races/overwrite_grp",
      JSON.stringify({
        access: $("#grp_access0").val(),
        name: $("#grp_name").val(),
      })
    );
  });

  $("#delete_grp").click(function () {
    $.post(
      "https://races/delete_grp",
      JSON.stringify({
        access: $("#grp_access0").val(),
        name: $("#grp_name").val(),
      })
    );
  });

  $("#list_grps").click(function () {
    $.post(
      "https://races/list_grps",
      JSON.stringify({
        access: $("#grp_access0").val(),
      })
    );
  });

  $("#save_grp").click(function () {
    $.post(
      "https://races/save_grp",
      JSON.stringify({
        access: $("#grp_access1").val(),
        name: $("#grp_unsaved").val(),
      })
    );
  });

  /* vehicle list panel */

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

  $("#list_close").click(function () {
    $("#listPanel").hide();
    $.post("https://races/close");
  });

  /* reply panel */
  $("#reply_close").click(function () {
    $("#replyPanel").hide();
    replyOpen = false;
    if ("main" == openPanel) {
      $("#mainPanel").show();
    } else if ("edit" == openPanel) {
      $("#editPanel").show();
    } else if ("register" == openPanel) {
      $("#registerPanel").show();
    } else if ("list" == openPanel) {
      $("#listPanel").show();
    }
  });

  document.onkeyup = function (data) {
    if (data.key == "Escape") {
      if (true == replyOpen) {
        $("#replyPanel").hide();
        replyOpen = false;
        if ("main" == openPanel) {
          $("#mainPanel").show();
        } else if ("edit" == openPanel) {
          $("#editPanel").show();
        } else if ("register" == openPanel) {
          $("#registerPanel").show();
        } else if ("list" == openPanel) {
          $("#listPanel").show();
        }
      } else {
        $("#mainPanel").hide();
        $("#editPanel").hide();
        $("#registerPanel").hide();
        $("#listPanel").hide();
        $.post("https://races/close");
      }
    }
  };

  if(window.jQuery) {
    $.post("https://races/uiReady");
  }
});

function DisplayRandomOptions(html) {
    $("#rest").hide();
    document.getElementById("register_vclass").innerHTML =
        "<option value = -2>Any</option>" + html;
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
  document.getElementById("register_rest_vehicle").innerHTML = data.allVehicles;
  document.getElementById("register_start_vehicle").innerHTML =
    '<option value = ""></option>' + data.allVehicles;
  $("#registerPanel").show();
  openPanel = "register";

  if($('#grid-lineup-table').children().length > 0) {
    $('#grid-lineup').show();
  }
  return openPanel;
}
